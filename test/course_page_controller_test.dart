import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/course_page_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试 harness：持有 controller + 注入的 ValueNotifier，便于测试外部输入。
class _Harness {
  _Harness({
    required ScheduleConfig config,
    List<ScheduleConfig> all = const [],
  }) : scheduleConfig = ValueNotifier(config),
       allSchedules = ValueNotifier([config, ...all]) {
    controller = CoursePageController(
      scheduleConfig: scheduleConfig,
      allSchedules: allSchedules,
      animationDuration: ValueNotifier(Duration.zero),
    );
  }

  late final CoursePageController controller;
  final ValueNotifier<ScheduleConfig> scheduleConfig;
  final ValueNotifier<List<ScheduleConfig>> allSchedules;
}

/// 创建一个「N 周前开学」的课表。注意：`ScheduleConfig.getCurrentWeek()` 会返回
/// `(days/7).floor() + 1`，所以 `weeksAgo: N` 对应 actualWeek = N + 1
/// （同 course_provider_test.dart 的 _weeksAgo 惯例，不注入时钟）。
ScheduleConfig _schedule({
  required String id,
  required String name,
  required int weeksAgo,
  int totalWeeks = 20,
}) {
  return ScheduleConfig(
    id: id,
    semesterName: name,
    semesterStartDate: _weeksAgo(weeksAgo),
    totalWeeks: totalWeeks,
  );
}

/// 创建一个「N 周后才开学」的课表。actualWeek = 1（getCurrentWeek 在开学前返回 1）。
ScheduleConfig _scheduleAhead({
  required String id,
  required String name,
  required int weeksAhead,
  int totalWeeks = 20,
}) {
  return ScheduleConfig(
    id: id,
    semesterName: name,
    semesterStartDate: _weeksAhead(weeksAhead),
    totalWeeks: totalWeeks,
  );
}

DateTime _weeksAgo(int weeks) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: weeks * 7));
}

DateTime _weeksAhead(int weeks) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.add(Duration(days: weeks * 7));
}

void main() {
  // ============ 初始化 ============
  // weeksAgo:N → actualWeek = N+1, _pageIndex = N（在 totalWeeks 范围内时）

  group('initialization', () {
    test('mid-semester: index = currentWeek - 1', () {
      // weeksAgo:5 → actualWeek = 6, _pageIndex = 5
      final h = _Harness(
        config: _schedule(id: 'A', name: 'mid', weeksAgo: 5, totalWeeks: 20),
      );
      expect(h.controller.actualWeek, 6);
      expect(h.controller.totalWeeks, 20);
      expect(h.controller.pageIndex, 5);
      expect(h.controller.visibleWeek, 6);
      expect(h.controller.isViewingVacation, isFalse);
      expect(h.controller.isTodayOnVacation, isFalse);
      expect(h.controller.pageCount, 20);
      h.controller.dispose();
    });

    test('semester ended + next sem not started: vacation page', () {
      // weeksAgo:25 → actualWeek = 26, semesterEndDate = today - 36 days
      final current = _schedule(
        id: 'C',
        name: 'ended',
        weeksAgo: 25,
        totalWeeks: 20,
      );
      final nextSem = _scheduleAhead(
        id: 'N',
        name: 'next',
        weeksAhead: 1,
        totalWeeks: 20,
      );
      final h = _Harness(config: current, all: [nextSem]);
      // current ended 5 weeks ago; nextSem starts in 1 week → 放假页
      expect(h.controller.showVacationPage.value, isTrue);
      expect(h.controller.pageIndex, 20); // vacation page index = totalWeeks
      expect(h.controller.isViewingVacation, isTrue);
      expect(h.controller.isTodayOnVacation, isTrue);
      expect(h.controller.pageCount, 21);
      h.controller.dispose();
    });

    test('semester ended, no next sem: last week, no badge', () {
      final current = _schedule(
        id: 'C',
        name: 'ended',
        weeksAgo: 25,
        totalWeeks: 20,
      );
      final h = _Harness(config: current);
      expect(h.controller.showVacationPage.value, isFalse);
      expect(h.controller.pageIndex, 19); // last week (clamp 26 to 20)
      expect(h.controller.visibleWeek, 20);
      expect(h.controller.isViewingVacation, isFalse);
      expect(h.controller.isTodayOnVacation, isFalse);
      expect(h.controller.pageCount, 20);
      h.controller.dispose();
    });

    test('next sem already started: same last week, no vacation page', () {
      final current = _schedule(
        id: 'C',
        name: 'ended',
        weeksAgo: 25,
        totalWeeks: 20,
      );
      // next sem started 1 week ago (after current's end) → today is not before its start
      final nextSem = _schedule(
        id: 'N',
        name: 'next',
        weeksAgo: 1,
        totalWeeks: 20,
      );
      final h = _Harness(config: current, all: [nextSem]);
      expect(h.controller.showVacationPage.value, isFalse);
      expect(h.controller.pageIndex, 19); // clamped to last week
      expect(h.controller.isTodayOnVacation, isFalse);
      h.controller.dispose();
    });

    test('semester not started yet: index 0', () {
      final config = _scheduleAhead(
        id: 'A',
        name: 'future',
        weeksAhead: 1,
        totalWeeks: 20,
      );
      final h = _Harness(config: config);
      expect(
        h.controller.actualWeek,
        1,
      ); // getCurrentWeek returns 1 before start
      expect(h.controller.pageIndex, 0);
      expect(h.controller.visibleWeek, 1);
      h.controller.dispose();
    });

    test('empty allSchedules + placeholder config: no throw, index 0', () {
      final placeholder = ScheduleConfig(
        id: 'default',
        semesterName: '默认课表',
        semesterStartDate: _weeksAgo(0),
        totalWeeks: 20,
      );
      final scheduleConfig = ValueNotifier(placeholder);
      final allSchedules = ValueNotifier<List<ScheduleConfig>>([]);
      final controller = CoursePageController(
        scheduleConfig: scheduleConfig,
        allSchedules: allSchedules,
        animationDuration: ValueNotifier(Duration.zero),
      );
      expect(controller.pageIndex, 0);
      expect(controller.pageCount, 20);
      controller.dispose();
    });

    test('totalWeeks: 0 dirty data: no throw, pageCount 1', () {
      // weeksAgo:5 → actualWeek = 6, totalWeeks guarded to 1
      final config = _schedule(
        id: 'A',
        name: 'dirty',
        weeksAgo: 5,
        totalWeeks: 0,
      );
      final h = _Harness(config: config);
      expect(h.controller.totalWeeks, 1); // guarded
      expect(h.controller.pageCount, 1);
      expect(h.controller.pageIndex, 0); // clamp(6, 1, 1) - 1 = 0
      h.controller.dispose();
    });
  });

  // ============ 导航 ============

  group('navigation', () {
    test('goToWeek clamps to bounds', () {
      final h = _Harness(
        config: _schedule(id: 'A', name: 'mid', weeksAgo: 5, totalWeeks: 20),
      );
      // start at index 5

      h.controller.goToWeek(25);
      expect(h.controller.pageIndex, 19); // clamp to last week

      h.controller.goToWeek(0);
      expect(h.controller.pageIndex, 0); // clamp to week 1

      h.controller.goToWeek(-5);
      expect(h.controller.pageIndex, 0);

      h.controller.goToWeek(10);
      expect(h.controller.pageIndex, 9);
      h.controller.dispose();
    });

    test('goToWeek > totalWeeks with vacation page → vacation page', () {
      final current = _schedule(
        id: 'C',
        name: 'ended',
        weeksAgo: 25,
        totalWeeks: 20,
      );
      final nextSem = _scheduleAhead(
        id: 'N',
        name: 'next',
        weeksAhead: 1,
        totalWeeks: 20,
      );
      final h = _Harness(config: current, all: [nextSem]);
      // starts at vacation page (index 20)

      h.controller.goToWeek(5);
      expect(h.controller.pageIndex, 4);

      h.controller.goToWeek(25); // > totalWeeks(20) + vacation available
      expect(h.controller.pageIndex, 20); // vacation page
      expect(h.controller.isViewingVacation, isTrue);
      h.controller.dispose();
    });

    test(
      'last week goToNextPage: with vacation → vacation; without → no-op',
      () {
        // With vacation page
        final current = _schedule(
          id: 'C',
          name: 'ended',
          weeksAgo: 25,
          totalWeeks: 20,
        );
        final nextSem = _scheduleAhead(
          id: 'N',
          name: 'next',
          weeksAhead: 1,
          totalWeeks: 20,
        );
        final h1 = _Harness(config: current, all: [nextSem]);
        h1.controller.goToWeek(20); // last week, index 19
        expect(h1.controller.pageIndex, 19);
        h1.controller.goToNextPage();
        expect(h1.controller.pageIndex, 20); // vacation page
        expect(h1.controller.isViewingVacation, isTrue);
        h1.controller.dispose();

        // Without vacation page
        final h2 = _Harness(
          config: _schedule(id: 'A', name: 'mid', weeksAgo: 5, totalWeeks: 20),
        );
        h2.controller.goToWeek(20); // last week, index 19
        expect(h2.controller.pageIndex, 19);
        var notifyCount = 0;
        h2.controller.addListener(() => notifyCount++);
        h2.controller.goToNextPage(); // no-op (no vacation, clamp to 19)
        expect(h2.controller.pageIndex, 19);
        expect(notifyCount, 0); // zero notify on no-op
        h2.controller.dispose();
      },
    );

    test(
      'vacation page goToPreviousPage → last week, isViewingVacation flips false',
      () {
        final current = _schedule(
          id: 'C',
          name: 'ended',
          weeksAgo: 25,
          totalWeeks: 20,
        );
        final nextSem = _scheduleAhead(
          id: 'N',
          name: 'next',
          weeksAhead: 1,
          totalWeeks: 20,
        );
        final h = _Harness(config: current, all: [nextSem]);
        // starts at vacation page (index 20)
        expect(h.controller.isViewingVacation, isTrue);

        h.controller.goToPreviousPage();
        expect(h.controller.pageIndex, 19);
        expect(h.controller.isViewingVacation, isFalse);
        h.controller.dispose();
      },
    );

    test('index 0 goToPreviousPage: no change and zero notify', () {
      final config = _scheduleAhead(
        id: 'A',
        name: 'future',
        weeksAhead: 1,
        totalWeeks: 20,
      );
      final h = _Harness(config: config);
      expect(h.controller.pageIndex, 0);

      var notifyCount = 0;
      h.controller.addListener(() => notifyCount++);
      h.controller.goToPreviousPage();
      expect(h.controller.pageIndex, 0);
      expect(notifyCount, 0);
      h.controller.dispose();
    });

    test('notify count: one per move, zero for no-op', () {
      final config = _scheduleAhead(
        id: 'A',
        name: 'future',
        weeksAhead: 1,
        totalWeeks: 20,
      );
      final h = _Harness(config: config);
      // start at index 0
      var notifyCount = 0;
      h.controller.addListener(() => notifyCount++);

      h.controller.goToNextPage();
      expect(h.controller.pageIndex, 1);
      expect(notifyCount, 1);

      h.controller.goToNextPage();
      expect(h.controller.pageIndex, 2);
      expect(notifyCount, 2);

      // no-op at index 0: go back to 0 first
      h.controller.goToPreviousPage();
      expect(h.controller.pageIndex, 1);
      expect(notifyCount, 3);
      h.controller.goToPreviousPage();
      expect(h.controller.pageIndex, 0);
      expect(notifyCount, 4);
      h.controller.goToPreviousPage(); // no-op
      expect(h.controller.pageIndex, 0);
      expect(notifyCount, 4); // unchanged
      h.controller.dispose();
    });

    test(
      'detach move: initialPage == pageIndex, PageController instance changed',
      () {
        // Regression for "未挂载跳页丢失" bug.
        // weeksAgo:5 → _pageIndex = 5 (headless: PageView never attaches → !hasClients)
        final h = _Harness(
          config: _schedule(id: 'A', name: 'mid', weeksAgo: 5, totalWeeks: 20),
        );
        final oldController = h.controller.pageController;
        expect(oldController.initialPage, 5);

        h.controller.goToNextPage(); // _pageIndex 5 → 6, !hasClients → swap

        expect(h.controller.pageIndex, 6);
        expect(h.controller.pageController.initialPage, 6);
        expect(identical(h.controller.pageController, oldController), isFalse);
        h.controller.dispose();
      },
    );
  });

  // ============ 外部输入 ============

  group('external input', () {
    test('switch config → land on new current week, exit vacation state', () {
      // weeksAgo:5 → actualWeek=6, _pageIndex=5
      final initial = _schedule(
        id: 'A',
        name: 'mid',
        weeksAgo: 5,
        totalWeeks: 20,
      );
      final h = _Harness(config: initial);
      expect(h.controller.pageIndex, 5);

      // Switch to a config 10 weeks ago → actualWeek=11, _pageIndex=10
      final newConfig = _schedule(
        id: 'B',
        name: 'new',
        weeksAgo: 10,
        totalWeeks: 20,
      );
      h.scheduleConfig.value = newConfig;

      expect(h.controller.pageIndex, 10); // week 11
      expect(h.controller.isViewingVacation, isFalse);
      h.controller.dispose();
    });

    test('switch to shorter schedule → clamp to new last week', () {
      // current: weeksAgo:5, totalWeeks:20 → _pageIndex=5
      final current = _schedule(
        id: 'A',
        name: 'mid',
        weeksAgo: 5,
        totalWeeks: 20,
      );
      // shorter: weeksAgo:15, totalWeeks:10 → actualWeek=16, semesterEndDate = today - 36 days
      final shorter = _schedule(
        id: 'S',
        name: 'short',
        weeksAgo: 15,
        totalWeeks: 10,
      );
      final h = _Harness(config: current, all: [shorter]);
      expect(h.controller.pageIndex, 5);

      h.scheduleConfig.value = shorter;
      // actualWeek=16, totalWeeks=10, no vacation (current is "next" but already started)
      // _indexForToday = 16.clamp(1,10) - 1 = 9
      expect(h.controller.totalWeeks, 10);
      expect(h.controller.pageIndex, 9); // clamped to new last week
      h.controller.dispose();
    });

    test(
      'switch to just-ended + next sem not started → land on vacation page',
      () {
        // weeksAgo:5 → _pageIndex=5
        final initial = _schedule(
          id: 'A',
          name: 'mid',
          weeksAgo: 5,
          totalWeeks: 20,
        );
        final nextSem = _scheduleAhead(
          id: 'N',
          name: 'next',
          weeksAhead: 1,
          totalWeeks: 20,
        );
        final ended = _schedule(
          id: 'E',
          name: 'ended',
          weeksAgo: 25,
          totalWeeks: 20,
        );
        final h = _Harness(config: initial);
        expect(h.controller.pageIndex, 5);

        // Switch allSchedules + scheduleConfig together
        h.allSchedules.value = [ended, nextSem];
        h.scheduleConfig.value = ended;

        expect(h.controller.showVacationPage.value, isTrue);
        expect(h.controller.pageIndex, 20); // vacation page
        expect(h.controller.isViewingVacation, isTrue);
        h.controller.dispose();
      },
    );

    test(
      'push next sem schedule during vacation: showVacationPage flips true, pageCount+1, pageIndex unchanged',
      () {
        // weeksAgo:25 → actualWeek=26, no next sem → _pageIndex=19 (clamped last week)
        final current = _schedule(
          id: 'C',
          name: 'ended',
          weeksAgo: 25,
          totalWeeks: 20,
        );
        final h = _Harness(config: current);
        expect(h.controller.showVacationPage.value, isFalse);
        expect(h.controller.pageIndex, 19);
        expect(h.controller.pageCount, 20);

        final nextSem = _scheduleAhead(
          id: 'N',
          name: 'next',
          weeksAhead: 1,
          totalWeeks: 20,
        );
        h.allSchedules.value = [current, nextSem];

        expect(h.controller.showVacationPage.value, isTrue);
        expect(h.controller.pageCount, 21); // +1
        expect(h.controller.pageIndex, 19); // unchanged (no auto-jump)
        h.controller.dispose();
      },
    );

    test('remove next sem while viewing vacation: move back to last week', () {
      final current = _schedule(
        id: 'C',
        name: 'ended',
        weeksAgo: 25,
        totalWeeks: 20,
      );
      final nextSem = _scheduleAhead(
        id: 'N',
        name: 'next',
        weeksAhead: 1,
        totalWeeks: 20,
      );
      final h = _Harness(config: current, all: [nextSem]);
      // start at vacation page (index 20)
      expect(h.controller.showVacationPage.value, isTrue);
      expect(h.controller.pageIndex, 20);
      expect(h.controller.isViewingVacation, isTrue);

      h.allSchedules.value = [current]; // remove next sem

      expect(h.controller.showVacationPage.value, isFalse);
      expect(h.controller.pageIndex, 19); // moved back to last week
      expect(h.controller.isViewingVacation, isFalse);
      h.controller.dispose();
    });

    test('onPageSettled: same value zero notify, out-of-bounds clamp', () {
      // weeksAgo:5 → _pageIndex=5
      final h = _Harness(
        config: _schedule(id: 'A', name: 'mid', weeksAgo: 5, totalWeeks: 20),
      );
      var notifyCount = 0;
      h.controller.addListener(() => notifyCount++);

      h.controller.onPageSettled(5); // same value
      expect(h.controller.pageIndex, 5);
      expect(notifyCount, 0);

      h.controller.onPageSettled(7); // different
      expect(h.controller.pageIndex, 7);
      expect(notifyCount, 1);

      h.controller.onPageSettled(7); // same again
      expect(notifyCount, 1);

      h.controller.onPageSettled(100); // out of bounds → clamp to last page
      expect(h.controller.pageIndex, 19);
      expect(notifyCount, 2);
      h.controller.dispose();
    });

    test('refreshToday never changes pageIndex', () {
      // weeksAgo:5 → _pageIndex=5
      final h = _Harness(
        config: _schedule(id: 'A', name: 'mid', weeksAgo: 5, totalWeeks: 20),
      );
      h.controller.goToPreviousPage(); // 5 → 4
      expect(h.controller.pageIndex, 4);

      h.controller.refreshToday();
      expect(h.controller.pageIndex, 4); // unchanged
      h.controller.dispose();
    });

    test('after dispose, external notifier change does not throw', () {
      final config = _schedule(
        id: 'A',
        name: 'mid',
        weeksAgo: 5,
        totalWeeks: 20,
      );
      final scheduleConfig = ValueNotifier(config);
      final allSchedules = ValueNotifier([config]);
      final controller = CoursePageController(
        scheduleConfig: scheduleConfig,
        allSchedules: allSchedules,
        animationDuration: ValueNotifier(Duration.zero),
      );
      controller.dispose();

      // Mutating external notifiers after dispose should not throw.
      expect(() {
        scheduleConfig.value = _schedule(
          id: 'B',
          name: 'other',
          weeksAgo: 10,
          totalWeeks: 20,
        );
        allSchedules.value = [scheduleConfig.value];
      }, returnsNormally);
    });
  });
}
