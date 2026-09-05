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

      expect(location.title, '四川大学江安校区逸夫教学楼 · B503 (综B)');
      expect(location.structuredLocation?.toPlatformJson(), {
        'title': '四川大学江安校区逸夫教学楼 · B503 (综B)',
      });
    });

    test('infers campus from building keywords without campus prefix', () {
      final jiangAnLoc = CalendarLocationMapper.resolve('综C407');
      expect(jiangAnLoc.title, '四川大学江安校区逸夫教学楼 · C407 (综C)');
      expect(jiangAnLoc.structuredLocation?.title, '四川大学江安校区逸夫教学楼 · C407 (综C)');

      final yiJiaoLoc = CalendarLocationMapper.resolve('一教A101');
      expect(yiJiaoLoc.title, '四川大学江安校区第一教学楼A座 · A101');
      expect(yiJiaoLoc.structuredLocation?.title, '四川大学江安校区第一教学楼A座 · A101');

      // 回归：全称形式（第一教学楼A座）不得因子串冲突命中无座版。
      final yiJiaoFull = CalendarLocationMapper.resolve('第一教学楼A座');
      expect(yiJiaoFull.title, '四川大学江安校区第一教学楼A座');
      expect(yiJiaoFull.structuredLocation?.title, '四川大学江安校区第一教学楼A座');

      final yiJiaoOnlyBuilding = CalendarLocationMapper.resolve('一教A座');
      expect(yiJiaoOnlyBuilding.title, '四川大学江安校区第一教学楼A座');
      expect(yiJiaoOnlyBuilding.structuredLocation?.title, '四川大学江安校区第一教学楼A座');

      // 回归：无座号时仍应命中无座版。
      final yiJiaoPlain = CalendarLocationMapper.resolve('第一教学楼');
      expect(yiJiaoPlain.title, '四川大学江安校区第一教学楼');
      expect(yiJiaoPlain.structuredLocation?.title, '四川大学江安校区第一教学楼');

      final wangJiangLoc = CalendarLocationMapper.resolve('基础教学楼B101');
      expect(wangJiangLoc.title, '四川大学望江校区基础教学楼B座 · B101');
      expect(wangJiangLoc.structuredLocation?.title, '四川大学望江校区基础教学楼B座 · B101');

      final huaXiLoc = CalendarLocationMapper.resolve('第八教学楼302');
      expect(huaXiLoc.title, '四川大学华西校区第八教学楼 · 302');
      expect(huaXiLoc.structuredLocation?.title, '四川大学华西校区第八教学楼 · 302');
    });

    test('uses campusName when provided', () {
      final location = CalendarLocationMapper.resolve(
        'A101',
        campusName: '江安校区',
      );
      expect(location.title, '四川大学江安校区 · A101');
      expect(location.structuredLocation?.title, '四川大学江安校区 · A101');
    });

    test('resolves empty location with campusName to campus full name', () {
      final location = CalendarLocationMapper.resolve('', campusName: '望江校区');
      expect(location.title, '四川大学望江校区');
      expect(location.structuredLocation?.title, '四川大学望江校区');
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
