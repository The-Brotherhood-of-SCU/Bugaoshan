import 'package:bugaoshan/services/api/academic_calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
