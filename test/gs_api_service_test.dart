import 'dart:convert';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/api/gs_api_service.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/gs_auth.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences prefs;
late AuthLogger logger;

void main() {
  setUp(() async {
    await getIt.reset();
    logger = AuthLogger();
    // CookieClient 的日志 getter 走 getIt<AuthLogger>，必须先注册。
    getIt.registerSingleton<AuthLogger>(logger);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('单页信封（抓包样本形态）一次取完', () async {
    final api = _buildApi(pages: {
      '1': _envelope([
        {'KCMC': '学术英语（中级）', 'XF': 2.0, 'SFJG': 1, 'SFYX': 1},
      ], totalSize: 1, pageNumber: 1, pageSize: 12, totalPage: 1),
    });

    final rows = await api.fetchGrades();

    expect(rows, hasLength(1));
    expect(rows.single.courseName, '学术英语（中级）');
    expect(_requests, 1);
  });

  test('totalPage 指引下翻页取全（服务端 cap pageSize 也适用）', () async {
    // 服务端把 pageSize cap 到 2：请求 200 实际每页 2 行，totalPage=2。
    final api = _buildApi(pages: {
      '1': _envelope([_row('课程A'), _row('课程B')],
          totalSize: 3, pageNumber: 1, pageSize: 2, totalPage: 2),
      '2': _envelope([_row('课程C')],
          totalSize: 3, pageNumber: 2, pageSize: 2, totalPage: 2),
    });

    final rows = await api.fetchGrades();

    expect(_requests, 2);
    expect(_pageNumbers, ['1', '2']);
    expect(rows.map((r) => r.courseName), ['课程A', '课程B', '课程C']);
  });

  test('extParams.totalPage 缺失时按 totalSize 兜底翻页', () async {
    final api = _buildApi(pages: {
      '1': _envelope([_row('课程A'), _row('课程B')], totalSize: 3, pageSize: 2),
      '2': _envelope([_row('课程C')], totalSize: 3, pageSize: 2),
    });

    final rows = await api.fetchGrades();

    expect(_requests, 2);
    expect(rows, hasLength(3));
  });

  test('返回空页立即停，不跟谎报的 totalPage 死磕', () async {
    final api = _buildApi(pages: {
      '1': _envelope(const [], totalSize: 0, totalPage: 10),
    });

    final rows = await api.fetchGrades();

    expect(_requests, 1);
    expect(rows, isEmpty);
  });

  test('空 body 抛 UnauthenticatedException（走自愈重试，不再当无数据）',
      () async {
    final api = _buildApi(pages: const {}, emptyBody: true);

    await expectLater(
      api.fetchGrades(),
      throwsA(isA<UnauthenticatedException>()),
    );
    // 自愈重试一次后仍空，穿透：探测 1 + 业务 2（原始 + 重试）。
    expect(_requests, 2);
  });
}

int _requests = 0;
final _pageNumbers = <String>[];

GsApiService _buildApi({
  required Map<String, String> pages,
  bool emptyBody = false,
}) {
  _requests = 0;
  _pageNumbers.clear();
  final client = CookieClient(
    inner: MockClient((request) async {
      _requests++;
      // _TestGsAuth.getClient 直接给 client、无 SSO 链路，mock 里没有
      // zhjw 测试那种「首个探测请求」，直接按请求体路由。
      if (emptyBody) return http.Response('', 200, request: request);
      final pageNumber = request.bodyFields['pageNumber'] ?? '1';
      _pageNumbers.add(pageNumber);
      final body = pages[pageNumber];
      if (body == null) {
        return http.Response(
          'no page $pageNumber',
          404,
          request: request,
        );
      }
      return http.Response.bytes(
        utf8.encode(body),
        200,
        headers: const {'content-type': 'text/json; charset=utf-8'},
        request: request,
      );
    }),
  );
  final gsAuth = _TestGsAuth(
    ScuAuth(prefs, logger: logger),
    client: client,
    logger: logger,
  );
  return GsApiService(gsAuth);
}

String _envelope(
  List<Map<String, dynamic>> rows, {
  int? totalSize,
  int? pageNumber,
  int? pageSize,
  int? totalPage,
}) => jsonEncode({
  'code': '0',
  'datas': {
    'xscjcx': {
      'rows': rows,
      'totalSize': totalSize,
      'pageNumber': pageNumber,
      'pageSize': pageSize,
      'extParams': {'code': 1, 'totalPage': totalPage},
    },
  },
});

Map<String, dynamic> _row(String name) => {
  'KCMC': name,
  'XF': 2.0,
  'SFJG': 1,
  'SFYX': 1,
};

class _TestGsAuth extends GsAuth {
  final CookieClient client;

  _TestGsAuth(super.scuAuth, {required this.client, super.logger});

  @override
  Future<CookieClient> getClient() async => client;
}
