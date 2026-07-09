import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/models/academic_calendar.dart';
import 'package:bugaoshan/services/api/academic_calendar_service.dart';

void main() {
  group('Academic Calendar Model Tests', () {
    const String jsonStr = '''
    {
      "semesters": [
        {
          "name": "2026-2027学年秋季学期",
          "startDate": "2026-09-07",
          "totalWeeks": 20,
          "events": [
            { "date": "2026-09-07", "label": "开学注册/正式上课", "tag": "start" },
            { "date": "2026-10-01", "endDate": "2026-10-07", "label": "国庆节假期", "tag": "holiday" },
            { "date": "2027-01-11", "endDate": "2027-01-22", "label": "期末考试周", "tag": "exam" }
          ]
        }
      ]
    }
    ''';

    test('Parses JSON correctly', () {
      final data = AcademicCalendarData.fromJsonString(jsonStr);
      expect(data.semesters.length, 1);
      
      final semester = data.semesters.first;
      expect(semester.name, '2026-2027学年秋季学期');
      expect(semester.startDate, DateTime(2026, 9, 7));
      expect(semester.totalWeeks, 20);
      expect(semester.events.length, 3);
      
      final event1 = semester.events[0];
      expect(event1.label, '开学注册/正式上课');
      expect(event1.tag, 'start');
      expect(event1.date, DateTime(2026, 9, 7));
      expect(event1.endDate, isNull);

      final event2 = semester.events[1];
      expect(event2.endDate, DateTime(2026, 10, 7));
    });

    test('Event active status check', () {
      final event = AcademicCalendarEvent(
        date: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 7),
        label: '国庆节假期',
        tag: 'holiday',
      );

      // Before event
      expect(event.isActive(DateTime(2026, 9, 30)), false);
      expect(event.isFinished(DateTime(2026, 9, 30)), false);
      expect(event.getDaysDifference(DateTime(2026, 9, 30)), 1);

      // Start of event
      expect(event.isActive(DateTime(2026, 10, 1)), true);
      expect(event.isFinished(DateTime(2026, 10, 1)), false);

      // During event
      expect(event.isActive(DateTime(2026, 10, 4)), true);
      expect(event.isFinished(DateTime(2026, 10, 4)), false);

      // End of event
      expect(event.isActive(DateTime(2026, 10, 7)), true);
      expect(event.isFinished(DateTime(2026, 10, 7)), false);

      // After event
      expect(event.isActive(DateTime(2026, 10, 8)), false);
      expect(event.isFinished(DateTime(2026, 10, 8)), true);
      expect(event.getDaysDifference(DateTime(2026, 10, 8)), -7);
    });

    test('Semester week calculation', () {
      final semester = AcademicCalendarSemester(
        name: 'Test Semester',
        startDate: DateTime(2026, 9, 7), // Monday
        totalWeeks: 20,
        events: [],
      );

      // Week 1 Mon
      expect(semester.getCurrentWeek(DateTime(2026, 9, 7)), 1);
      // Week 1 Sun
      expect(semester.getCurrentWeek(DateTime(2026, 9, 13)), 1);
      // Week 2 Mon
      expect(semester.getCurrentWeek(DateTime(2026, 9, 14)), 2);
      // Week 20 Sun
      expect(semester.getCurrentWeek(DateTime(2026, 9, 7).add(const Duration(days: 20 * 7 - 1))), 20);
      
      // Before semester
      expect(semester.getCurrentWeek(DateTime(2026, 9, 6)), isNull);
      // After semester
      expect(semester.getCurrentWeek(DateTime(2026, 9, 7).add(const Duration(days: 20 * 7))), isNull);
    });
  });

  group('AcademicCalendarService Tests', () {
    test('Service generates export payload correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = AcademicCalendarService(prefs);

      final semester = AcademicCalendarSemester(
        name: '2026-2027学年秋季学期',
        startDate: DateTime(2026, 9, 7),
        totalWeeks: 20,
        events: [
          AcademicCalendarEvent(
            date: DateTime(2026, 10, 1),
            endDate: DateTime(2026, 10, 7),
            label: '国庆节假期',
            tag: 'holiday',
          ),
        ],
      );

      final payload = service.genExportPayload(semester);
      expect(payload.fileName, 'SCU_Calendar_2026-2027学年秋季学期.ics');
      expect(payload.events.length, 1);
      expect(payload.events.first['title'], '国庆节假期');
      expect(payload.icsContent, contains('BEGIN:VCALENDAR'));
      expect(payload.icsContent, contains('SUMMARY:国庆节假期'));
      expect(payload.icsContent, contains('UID:acad-2026-2027学年秋季学期-国庆节假期-'));
    });
  });
}
