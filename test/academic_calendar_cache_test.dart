import 'package:bugaoshan/services/api/academic_calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 追踪 close() 调用，用于验证注入的 client 生命周期由注入方管理。
class _TrackingClient extends http.BaseClient {
  final http.Client _inner;
  bool closed = false;

  _TrackingClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  const cacheKey = 'cached_academic_calendar_json';
  const validCalendar = '''
  {
    "semesters": [
      {
        "name": "2026-2027学年秋季学期",
        "startDate": "2026-09-07",
        "totalWeeks": 20,
        "events": []
      }
    ]
  }
  ''';

  test('无效远程校历不会覆盖最后一份有效缓存', () async {
    SharedPreferences.setMockInitialValues({cacheKey: validCalendar});
    final prefs = await SharedPreferences.getInstance();
    final client = MockClient(
      (_) async => http.Response('{"semesters":"invalid"}', 200),
    );
    final service = AcademicCalendarService(prefs, client: client);

    final calendar = await service.fetchCalendarData();

    expect(calendar.semesters, hasLength(1));
    expect(calendar.semesters.single.name, '2026-2027学年秋季学期');
    expect(prefs.getString(cacheKey), validCalendar);
  });

  test('空校历响应不写入缓存', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final client = MockClient(
      (_) async => http.Response('{"semesters":[]}', 200),
    );
    final service = AcademicCalendarService(prefs, client: client);

    final calendar = await service.fetchCalendarData();

    expect(calendar.semesters, isEmpty);
    // 空校历不得污染缓存：否则本地优先策略会一直展示空数据且不回退内置 asset。
    expect(prefs.getString(cacheKey), isNull);
  });

  test('refreshCalendarData 成功时写入缓存并返回数据', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final client = MockClient(
      (_) async => http.Response(
        validCalendar,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final service = AcademicCalendarService(prefs, client: client);

    final calendar = await service.refreshCalendarData();

    expect(calendar, isNotNull);
    expect(calendar!.semesters, hasLength(1));
    expect(prefs.getString(cacheKey), validCalendar);
  });

  test('refreshCalendarData 网络失败返回 null 且缓存不变', () async {
    SharedPreferences.setMockInitialValues({cacheKey: validCalendar});
    final prefs = await SharedPreferences.getInstance();
    final client = MockClient((_) async => throw Exception('network down'));
    final service = AcademicCalendarService(prefs, client: client);

    final calendar = await service.refreshCalendarData();

    expect(calendar, isNull);
    expect(prefs.getString(cacheKey), validCalendar);
  });

  test('注入的 client 不会被 service 关闭', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final inner = MockClient(
      (_) async => http.Response(
        validCalendar,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final tracking = _TrackingClient(inner);
    final service = AcademicCalendarService(prefs, client: tracking);

    final calendar = await service.refreshCalendarData();

    expect(calendar, isNotNull);
    // 注入的 client 生命周期归注入方（test）管理，service 不得 close。
    expect(tracking.closed, isFalse);
  });
}
