import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_activity_filter.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_activity_phase.dart';
import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';

CyclActivity _activity({
  double classHour = 2,
  String? enrollStart,
  String? enrollEnd,
  String? start,
  String? end,
  bool subscribed = false,
  bool doing = false,
}) {
  return CyclActivity(
    activityLibraryId: 'lib-1',
    orgNo: 'org-1',
    name: '系列名',
    activityName: '活动名',
    level: 'A01',
    star: '',
    quality: const [],
    classHour: classHour,
    poster: '',
    quota: 0,
    activityTarget: '',
    isSignIn: '0',
    isSignOut: '0',
    status: 'A03',
    orgName: '主办方',
    doing: doing,
    subscribed: subscribed,
    enrollStartTime: enrollStart,
    enrollEndTime: enrollEnd,
    startTime: start,
    endTime: end,
  );
}

void main() {
  final now = DateTime.utc(2026, 9, 20, 1, 0); // 北京 09:00

  test('空筛选命中所有条目', () {
    final filter = CcylActivityFilter.empty;
    expect(filter.isActive, isFalse);
    expect(filter.hasLocalFilter, isFalse);
    expect(filter.matches(_activity(classHour: 0.5), now: now), isTrue);
  });

  group('学时（本地维度）', () {
    test('低于最低学时不命中，等于及高于命中', () {
      final filter = const CcylActivityFilter(minClassHour: 3);
      expect(filter.matches(_activity(classHour: 2), now: now), isFalse);
      expect(filter.matches(_activity(classHour: 3), now: now), isTrue);
      expect(filter.matches(_activity(classHour: 4), now: now), isTrue);
    });

    test('minClassHour = 0 表示不限', () {
      const filter = CcylActivityFilter();
      expect(filter.matches(_activity(classHour: 0), now: now), isTrue);
    });
  });

  group('状态（本地维度）', () {
    final enrolling = _activity(
      doing: true,
      enrollStart: '2026-09-20 08:00:00',
      enrollEnd: '2026-09-20 10:00:00',
    );

    test('命中状态集合内的条目', () {
      final filter = const CcylActivityFilter(
        phases: {CcylActivityPhase.enrolling},
      );
      expect(filter.matches(enrolling, now: now), isTrue);
      expect(filter.hasLocalFilter, isTrue);
    });

    test('状态集合外的条目不命中', () {
      final filter = const CcylActivityFilter(
        phases: {CcylActivityPhase.ongoing},
      );
      expect(filter.matches(enrolling, now: now), isFalse);
    });

    test('条目同时展示多个状态时任一命中即可', () {
      // 报名与活动时段重叠：同时展示报名中 + 进行中。
      final both = _activity(
        doing: true,
        enrollStart: '2026-09-20 08:00:00',
        enrollEnd: '2026-09-20 10:00:00',
        start: '2026-09-20 09:00:00',
        end: '2026-09-20 11:00:00',
      );
      const filter = CcylActivityFilter(phases: {CcylActivityPhase.ongoing});
      expect(filter.matches(both, now: now), isTrue);
    });

    test('服务端口径（可预约/已预约）可被筛选', () {
      const subscribedFilter = CcylActivityFilter(
        phases: {CcylActivityPhase.subscribed},
      );
      expect(
        subscribedFilter.matches(_activity(subscribed: true), now: now),
        isTrue,
      );
      expect(
        subscribedFilter.matches(_activity(subscribed: false), now: now),
        isFalse,
      );

      const availableFilter = CcylActivityFilter(
        phases: {CcylActivityPhase.available},
      );
      expect(availableFilter.matches(_activity(), now: now), isTrue);
    });
  });

  group('等值与拷贝', () {
    test('相同条件的筛选相等（状态集合与顺序无关）', () {
      const a = CcylActivityFilter(
        phases: {CcylActivityPhase.enrolling, CcylActivityPhase.ongoing},
        minClassHour: 2,
      );
      const b = CcylActivityFilter(
        phases: {CcylActivityPhase.ongoing, CcylActivityPhase.enrolling},
        minClassHour: 2,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('copyWith 仅覆盖传入字段', () {
      const base = CcylActivityFilter(level: 'A01', org: 'org-9');
      final copied = base.copyWith(minClassHour: 2);
      expect(copied.level, 'A01');
      expect(copied.org, 'org-9');
      expect(copied.minClassHour, 2);
      expect(copied.phases, isEmpty);
    });
  });
}
