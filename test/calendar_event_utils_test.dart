import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/utils/calendar_event_utils.dart';

void main() {
  group('Calendar event utilities', () {
    test('normalizes names from authoritative academic-system text', () {
      expect(
        CalendarEventIdentity.normalizeName('  (107447030-31)  高等数学A（已结束） '),
        '(107447030-31) 高等数学A',
      );
      expect(CalendarEventIdentity.normalizeName('高等数学A  ( 已结束 )'), '高等数学A');
    });

    test('generates stable exam UID from normalized name', () {
      final uid = CalendarEventIdentity.examUid(
        name: '(107447030-31) 高等数学A（已结束）',
      );
      final sameUid = CalendarEventIdentity.examUid(
        name: '(107447030-31) 高等数学A',
      );
      final rescheduledUid = CalendarEventIdentity.examUid(
        name: '(107447030-31) 高等数学A',
      );
      final anotherKindUid = CalendarEventIdentity.courseUid(
        courseId: '107447030-31',
        week: 18,
      );

      expect(uid, sameUid);
      expect(uid, rescheduledUid);
      expect(uid, startsWith('exam-'));
      expect(uid, endsWith('@bugaoshan'));
      expect(anotherKindUid, isNot(uid));
    });

    test('keeps legacy course UID semantics', () {
      expect(
        CalendarEventIdentity.courseUid(courseId: 'course-123', week: 7),
        'course-123_7@bugaoshan',
      );
    });

    test('maps campus location to display title and coordinates', () {
      final location = CalendarLocationMapper.resolve('江安 综合楼B座 B503');

      expect(location.title, '四川大学江安校区 · 江安 综合楼B座 B503');
      expect(location.structuredLocation?.toPlatformJson(), {
        'title': '四川大学江安校区 · 江安 综合楼B座 B503',
        'latitude': 30.5601863,
        'longitude': 103.9973029,
        'radius': 250.0,
      });
    });

    test('keeps unknown locations without coordinates', () {
      final location = CalendarLocationMapper.resolve('线上考试');

      expect(location.title, '线上考试');
      expect(location.structuredLocation, isNull);
    });

    test('does not expose internal UID as a visible platform URL', () {
      final payload = CalendarEventPayload(
        start: DateTime(2026, 7, 4, 16, 30),
        end: DateTime(2026, 7, 4, 18, 30),
        title: '分析化学考试',
        location: '四川大学江安校区 · 江安 一教B座 B103',
        description: '第 17 周\n座位号: 12',
        uid: 'exam-abc@bugaoshan',
      ).toPlatformJson();

      expect(payload['uid'], 'exam-abc@bugaoshan');
      expect(payload, isNot(contains('sourceUri')));
    });
  });
}
