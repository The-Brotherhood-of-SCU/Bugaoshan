import 'dart:convert';
import 'dart:io';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/api/zhhq_api_service.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/zhhq_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/utils/zhhq_crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<AuthLogger>(AuthLogger());
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('_decode 4010-4017 token 错误映射', () {
    test('4013 抛 UnauthenticatedException 并触发 invalidate', () async {
      final auth = _FakeZhhqAuth.withBody(
        _authBody({'status': 'error', 'errorCode': '4013', 'message': '凭证已过期'}),
      );
      final api = ZhhqApiService(auth);

      await expectLater(
        api.fetchAddresses(),
        throwsA(isA<UnauthenticatedException>()),
      );
      // fast path 失效后 invalidate + 完整认证重试也失败
      expect(auth.invalidateCount, greaterThanOrEqualTo(1));
    });

    test('4017（边界值）同样映射为 UnauthenticatedException', () async {
      final auth = _FakeZhhqAuth.withBody(
        _authBody({
          'status': 'error',
          'errorCode': '4017',
          'message': '签名校验失败',
        }),
      );
      final api = ZhhqApiService(auth);

      await expectLater(
        api.fetchAddresses(),
        throwsA(isA<UnauthenticatedException>()),
      );
    });

    test('4010-4017 前缀之外不做 token 自愈（如 5001 为普通业务错误）', () async {
      final auth = _FakeZhhqAuth.withBody(
        _authBody({'status': 'error', 'errorCode': '5001', 'message': '系统繁忙'}),
      );
      final api = ZhhqApiService(auth);

      await expectLater(api.fetchAddresses(), throwsA(isA<ServiceException>()));
    });
  });

  group('业务错误判定统一（status / errorCode 任一非成功即抛）', () {
    test('status 非 success 且无 errorCode → ServiceException', () async {
      final auth = _FakeZhhqAuth.withBody(
        _authBody({'status': 'error', 'message': '缺少参数'}),
      );
      final api = ZhhqApiService(auth);

      await expectLater(
        api.fetchAddresses(),
        throwsA(
          isA<ServiceException>().having(
            (e) => e.message,
            'message',
            contains('缺少参数'),
          ),
        ),
      );
    });

    test('status=success 但 errorCode 非 0 → ServiceException', () async {
      final auth = _FakeZhhqAuth.withBody(
        _authBody({'status': 'success', 'errorCode': '500', 'message': '数据异常'}),
      );
      final api = ZhhqApiService(auth);

      await expectLater(
        api.fetchAddresses(),
        throwsA(
          isA<ServiceException>().having(
            (e) => e.message,
            'message',
            contains('数据异常'),
          ),
        ),
      );
    });
  });

  group('fast path 失效 → 完整认证自愈', () {
    test('第一次 4013，重试成功后正常返回地址', () async {
      var calls = 0;
      final inner = MockClient((request) async {
        calls++;
        if (calls == 1) {
          // 快速路径：token 失效
          return _authResponse({
            'status': 'error',
            'errorCode': '4013',
            'message': 'token invalid',
          });
        }
        // 完整认证后成功
        return _authResponse({
          'status': 'success',
          'errorCode': '0',
          'data': [
            {
              'id': 'addr-1',
              'areaName': '望江学生区/东苑五栋',
              'address': '主楼315',
              'phone': '18500000000',
              'areaId': '10005',
            },
          ],
        });
      });
      final auth = _FakeZhhqAuth(inner);
      final api = ZhhqApiService(auth);

      final addresses = await api.fetchAddresses();
      expect(addresses, hasLength(1));
      expect(addresses.single.phone, '18500000000');
      expect(calls, 2);
      // fast path 失效走完整认证，不会先 invalidate（留给完整路径）
      expect(auth.invalidateCount, 0);
    });
  });

  group('fetchDynamicTickets 请求参数对齐前端', () {
    test('search 数组用 searchValue、systemCode 进 search、带 order', () async {
      Map<String, String>? captured;
      late MockClient inner;
      inner = MockClient((request) async {
        // 第一个请求是 CookieClient 域探测（无 body），其余为业务请求
        if (request.body.isNotEmpty) {
          captured = request.bodyFields;
        }
        return _authResponse({
          'status': 'success',
          'errorCode': '0',
          'data': [
            {
              'activeId': 't-1',
              'status': '待完工',
              'activeTime': '2026-09-03 07:49:23',
              'content': '{"维修项目":"水/上下水管类","故障描述":"漏水"}',
            },
          ],
        });
      });
      final auth = _FakeZhhqAuth(inner);
      final api = ZhhqApiService(auth);

      final tickets = await api.fetchDynamicTickets(userId: 'user-1');
      expect(tickets, hasLength(1));
      expect(tickets.single.projectName, '水/上下水管类');

      // 对齐前端：searchValue 而非 value
      final search = jsonDecode(captured!['search']!) as List;
      expect(search, hasLength(2));
      final first = search[0] as Map;
      expect(first['searchField'], 'createUser');
      expect(first['searchValue'], 'user-1');
      expect(first.containsKey('value'), isFalse);
      // systemCode 进 search 数组
      final second = search[1] as Map;
      expect(second['searchField'], 'systemCode');
      expect(second['searchValue'], 'newRepair');
      // 无 pageIndex/pageSize，带 order
      expect(captured!.containsKey('pageIndex'), isFalse);
      expect(captured!.containsKey('pageSize'), isFalse);
      expect(captured!['order'], 'createTime desc');
    });
  });

  group('fetchRepairDetail / withdrawRepair / evaluateRepair', () {
    test('fetchRepairDetail 调用 repairInfo/get 并解析数字状态', () async {
      late String? lastBody;
      late MockClient inner;
      inner = MockClient((request) async {
        if (request.body.isNotEmpty) lastBody = request.body;
        return _authResponse({
          'status': 'success',
          'errorCode': '0',
          'data': {
            'id': 'abc',
            'serialNumber': '202609030009',
            'projectName': '水/上下水管类',
            'content': '漏水',
            'areaName': '望江学生区/东苑五栋',
            'address': '主楼315',
            'acceptDeptName': '维修与通讯服务中心望江校区',
            'payName': '无偿',
            'status': '3',
            'ifCommont': '0',
            'finishedInfo': {'repairId': 'fin-1'},
            'logVOS': [
              {
                'statusName': '派工',
                'content': '被指派维修',
                'createTime': '2026-09-03 07:49:23',
              },
            ],
          },
        });
      });
      final auth = _FakeZhhqAuth(inner);
      final api = ZhhqApiService(auth);

      final detail = await api.fetchRepairDetail(id: 'abc');
      expect(lastBody, contains('id=abc'));
      expect(detail.id, 'abc');
      expect(detail.serialNumber, '202609030009');
      expect(detail.projectName, '水/上下水管类');
      expect(detail.content, '漏水');
      expect(detail.acceptDeptName, '维修与通讯服务中心望江校区');
      expect(detail.payName, '无偿');
      expect(detail.logs, hasLength(1));
      expect(detail.logs.single.statusName, '派工');
      expect(detail.finishedInfo?.repairId, 'fin-1');
    });

    test('withdrawRepair 调用 myRepair/withdrawMyRepair', () async {
      late String? lastBody;
      late MockClient inner;
      inner = MockClient((request) async {
        if (request.body.isNotEmpty) lastBody = request.body;
        return _authResponse({
          'status': 'success',
          'errorCode': '0',
          'data': null,
        });
      });
      final auth = _FakeZhhqAuth(inner);
      final api = ZhhqApiService(auth);

      await api.withdrawRepair(id: 'abc');
      expect(lastBody, contains('id=abc'));
    });

    test('evaluateRepair 用 JSON 体调用 visitEvaluateUser/save', () async {
      late Map<String, String>? capturedHeaders;
      late String? lastBody;
      late MockClient inner;
      inner = MockClient((request) async {
        if (request.body.isNotEmpty) {
          capturedHeaders = request.headers;
          lastBody = request.body;
        }
        return _authResponse({
          'status': 'success',
          'errorCode': '0',
          'data': null,
        });
      });
      final auth = _FakeZhhqAuth(inner);
      final api = ZhhqApiService(auth);

      await api.evaluateRepair(
        repairId: 'fin-1',
        common: [
          {
            'id': '7adc451a-1e9e-4016-bd3d-63f15efdb816',
            'name': '维修质量',
            'weight': '50',
            'star': 5,
          },
        ],
        content: '很好',
        labels: const ['及时'],
      );

      expect(lastBody, isNotNull);
      final decoded = jsonDecode(lastBody!) as Map;
      expect(decoded['repairId'], 'fin-1');
      expect(decoded['source'], '0');
      expect(decoded['label'], '及时');
      // 提交的 common 含完整评价项对象（id/name/weight/star）
      final common = decoded['common'] as List;
      expect(common, hasLength(1));
      final item = common.single as Map;
      expect(item['id'], '7adc451a-1e9e-4016-bd3d-63f15efdb816');
      expect(item['name'], '维修质量');
      expect(item['weight'], '50');
      expect(item['star'], 5);
      // JSON content-type
      expect(capturedHeaders!['Content-Type'], contains('application/json'));
    });

    test('fetchEvaluateProjects 调用 commontProject/getProject 返回评价项', () async {
      final paths = <String>[];
      late MockClient inner;
      inner = MockClient((request) async {
        // getProject 请求体为空（前端 A.a.stringify() 无参数），按路径收集
        paths.add(request.url.path);
        return _authResponse({
          'status': 'success',
          'errorCode': '0',
          'data': [
            {
              'id': '7adc451a-1e9e-4016-bd3d-63f15efdb816',
              'name': '维修质量',
              'weight': 50,
            },
            {
              'id': 'b705e0ce-659a-4b72-a447-2dd5fc333315',
              'name': '维修态度',
              'weight': 25,
            },
            {
              'id': 'eaa47855-0a4d-49e4-97a3-1c3927e19332',
              'name': '维修速度',
              'weight': 25,
            },
          ],
        });
      });
      final auth = _FakeZhhqAuth(inner);
      final api = ZhhqApiService(auth);

      final projects = await api.fetchEvaluateProjects();
      // 第一个请求可能是 CookieClient 域探测（非业务路径），业务路径必须出现
      expect(
        paths.where((p) => p.endsWith('/repair/commontProject/getProject')),
        isNotEmpty,
      );
      expect(projects, hasLength(3));
      expect(projects.first.name, '维修质量');
      expect(projects.first.id, '7adc451a-1e9e-4016-bd3d-63f15efdb816');
      expect(projects.first.weight, '50');
    });
  });

  group('uploadImage', () {
    test(
      '明文 JSON 中 errorCode 非 0 且 status=success → ServiceException',
      () async {
        final inner = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'errorCode': '9001',
              'message': '文件类型不支持',
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
            request: request,
          );
        });
        final auth = _FakeZhhqAuth(inner);
        final api = ZhhqApiService(auth);

        final file = await _tempImage();
        await expectLater(
          api.uploadImage(file: file),
          throwsA(
            isA<ServiceException>().having(
              (e) => e.message,
              'message',
              contains('文件类型不支持'),
            ),
          ),
        );
      },
    );

    test(
      'HTTP 302/401/403 → UnauthenticatedException → invalidate 并重试',
      () async {
        var calls = 0;
        final inner = MockClient((request) async {
          calls++;
          if (calls == 1) {
            return http.Response('', 302, request: request);
          }
          final bytes = utf8.encode(
            jsonEncode({
              'status': 'success',
              'errorCode': '0',
              'data': {'path': '/upload/2026/abc.jpg'},
            }),
          );
          return http.Response.bytes(
            bytes,
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
            request: request,
          );
        });
        final auth = _FakeZhhqAuth(inner);
        final api = ZhhqApiService(auth);

        final file = await _tempImage();
        final path = await api.uploadImage(file: file);
        expect(path, '/upload/2026/abc.jpg');
        expect(calls, 2);
        expect(auth.invalidateCount, 1);
      },
    );
  });
}

/// 构造一个带 tokenKey 的 CookieClient + MockClient 的假认证。
class _FakeZhhqAuth extends ChangeNotifier implements ZhhqAuth {
  _FakeZhhqAuth(MockClient inner, {this.tokenKey = 'tk-test'})
    : fastClient = CookieClient(inner: inner),
      fullClient = CookieClient(inner: inner);

  /// 便捷：构造一个总是返回给定加密响应体的认证。
  factory _FakeZhhqAuth.withBody(
    String encryptedBody, {
    String tokenKey = 'tk-test',
  }) {
    final inner = MockClient((request) async {
      return http.Response.bytes(
        utf8.encode(encryptedBody),
        200,
        headers: const {'content-type': 'text/html; charset=utf-8'},
        request: request,
      );
    });
    return _FakeZhhqAuth(inner, tokenKey: tokenKey);
  }

  final CookieClient fastClient;
  final CookieClient fullClient;
  @override
  final String? tokenKey;

  int invalidateCount = 0;

  @override
  CookieClient? getClientFast() => fastClient;

  @override
  Future<CookieClient> getClient() async => fullClient;

  @override
  void invalidate() {
    invalidateCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 加密响应体：完整走服务端 AES 加密 → App 端 _decode 解密链路。
String _authBody(Map<String, dynamic> json) =>
    ZhhqCrypto.encrypt(jsonEncode(json));

/// 加密响应（附 200 状态）。
http.Response _authResponse(Map<String, dynamic> json) {
  final body = _authBody(json);
  return http.Response.bytes(
    utf8.encode(body),
    200,
    headers: const {'content-type': 'text/html; charset=utf-8'},
    request: null,
  );
}

/// 创建临时图片文件（仅测试 multipart 上传，内容任意）。
Future<File> _tempImage() async {
  final dir = await Directory.systemTemp.createTemp('zhhq_test');
  final file = File('${dir.path}/test.jpg');
  await file.writeAsBytes(List.filled(64, 0xAB));
  return file;
}
