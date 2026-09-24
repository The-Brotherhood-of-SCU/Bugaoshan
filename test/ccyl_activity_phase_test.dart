import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_activity_phase.dart';
import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';

CyclActivity _activity({
  String? enrollStart,
  String? enrollEnd,
  String? start,
  String? end,
  bool subscribed = false,
  bool doing = true,
  double classHour = 2,
}) {
  return CyclActivity(
    activityLibraryId: 'lib-1',
    orgNo: 'org-1',
    name: '系列名',
    activityName: '活动名',
    level: '',
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
  group('parseCcylServerTime', () {
    test('北京时间墙钟字符串按 UTC+8 解释', () {
      final parsed = parseCcylServerTime('2026-09-20 14:00:00');
      expect(parsed, DateTime.utc(2026, 9, 20, 6, 0, 0));
    });

    test('斜杠分隔与缺秒格式兼容', () {
      expect(
        parseCcylServerTime('2026/09/20 14:00'),
        DateTime.utc(2026, 9, 20, 6, 0, 0),
      );
    });

    test('纯日期按当日 00:00 北京时间解释', () {
      expect(
        parseCcylServerTime('2026-09-20'),
        DateTime.utc(2026, 9, 19, 16, 0, 0),
      );
    });

    test('毫秒时间戳', () {
      final expected = DateTime.fromMillisecondsSinceEpoch(
        1700000000000,
      ).toUtc();
      expect(parseCcylServerTime('1700000000000'), expected);
    });

    test('秒时间戳', () {
      final expected = DateTime.fromMillisecondsSinceEpoch(
        1700000000 * 1000,
      ).toUtc();
      expect(parseCcylServerTime('1700000000'), expected);
    });

    test('带时区标记的 ISO 串不重复叠加偏移', () {
      expect(
        parseCcylServerTime('2026-09-20T14:00:00+08:00'),
        DateTime.utc(2026, 9, 20, 6, 0, 0),
      );
      expect(
        parseCcylServerTime('2026-09-20T06:00:00Z'),
        DateTime.utc(2026, 9, 20, 6, 0, 0),
      );
    });

    test('空值与脏数据返回 null', () {
      expect(parseCcylServerTime(null), isNull);
      expect(parseCcylServerTime(''), isNull);
      expect(parseCcylServerTime('   '), isNull);
      expect(parseCcylServerTime('abc'), isNull);
      expect(parseCcylServerTime('2026-13-40 99:99'), isNull);
      expect(parseCcylServerTime('2026-02-30'), isNull);
      expect(parseCcylServerTime('2026-02-29 10:00'), isNull);
      expect(
        parseCcylServerTime('2024-02-29 10:00'),
        DateTime.utc(2024, 2, 29, 2, 0, 0),
      );
    });
  });

  group('resolveCcylActivityPhasesFromTimes', () {
    // 北京时间 2026-09-20 08:00~10:00 报名、12:00~14:00 活动。
    final enrollStart = '2026-09-20 08:00:00';
    final enrollEnd = '2026-09-20 10:00:00';
    final actStart = '2026-09-20 12:00:00';
    final actEnd = '2026-09-20 14:00:00';

    test('已预约：服务端口径优先，不进入时间匹配', () {
      final phases = resolveCcylActivityPhasesFromTimes(
        doing: true,
        subscribed: true,
        enrollStartTime: enrollStart,
        enrollEndTime: enrollEnd,
        startTime: actStart,
        endTime: actEnd,
        now: DateTime.utc(2026, 9, 20, 1, 0), // 北京 09:00，报名中
      );
      expect(phases, [CcylActivityPhase.subscribed]);
    });

    test('时间窗能判定时优先于服务端 doing（子活动列表与详情口径一致）', () {
      // 列表 payload 里 doing=false，但报名时段确实在命中 → 报名中。
      final enrolling = resolveCcylActivityPhasesFromTimes(
        doing: false,
        enrollStartTime: enrollStart,
        enrollEndTime: enrollEnd,
        startTime: actStart,
        endTime: actEnd,
        now: DateTime.utc(2026, 9, 20, 1, 0), // 北京 09:00，报名中
      );
      expect(enrolling, [CcylActivityPhase.enrolling]);

      // 活动时段命中 → 进行中。
      final ongoing = resolveCcylActivityPhasesFromTimes(
        doing: false,
        startTime: actStart,
        endTime: actEnd,
        now: DateTime.utc(2026, 9, 20, 5, 0), // 北京 13:00
      );
      expect(ongoing, [CcylActivityPhase.ongoing]);
    });

    test('时间信息缺失时回退服务端口径：doing=false → 可预约', () {
      final phases = resolveCcylActivityPhasesFromTimes(
        doing: false,
        now: DateTime.utc(2026, 9, 20, 4, 0),
      );
      expect(phases, [CcylActivityPhase.available]);
    });

    test('子活动未开始报名：报名开始时间在未来 → 未开始', () {
      final phases = resolveCcylActivityPhasesFromTimes(
        doing: false,
        enrollStartTime: enrollStart,
        enrollEndTime: enrollEnd,
        startTime: actStart,
        endTime: actEnd,
        now: DateTime.utc(2026, 9, 19, 20, 0), // 北京 09-20 04:00
      );
      expect(phases, [CcylActivityPhase.notStarted]);
    });

    test('服务端「进行中」且仅报名时段命中 → 报名中', () {
      final phases = resolveCcylActivityPhasesFromTimes(
        doing: true,
        enrollStartTime: enrollStart,
        enrollEndTime: enrollEnd,
        startTime: actStart,
        endTime: actEnd,
        now: DateTime.utc(2026, 9, 20, 1, 0), // 北京 09:00
      );
      expect(phases, [CcylActivityPhase.enrolling]);
    });

    test('服务端「进行中」且仅活动时段命中 → 进行中', () {
      final phases = resolveCcylActivityPhasesFromTimes(
        doing: true,
        enrollStartTime: enrollStart,
        enrollEndTime: enrollEnd,
        startTime: actStart,
        endTime: actEnd,
        now: DateTime.utc(2026, 9, 20, 5, 0), // 北京 13:00
      );
      expect(phases, [CcylActivityPhase.ongoing]);
    });

    test('服务端「进行中」且两个时段同时命中 → 报名中 + 进行中并存', () {
      final phases = resolveCcylActivityPhasesFromTimes(
        doing: true,
        enrollStartTime: enrollStart,
        enrollEndTime: enrollEnd,
        startTime: '2026-09-20 09:00:00',
        endTime: '2026-09-20 11:00:00',
        now: DateTime.utc(2026, 9, 20, 1, 0), // 北京 09:00
      );
      expect(phases, [CcylActivityPhase.enrolling, CcylActivityPhase.ongoing]);
    });

    test('时间窗边界为闭区间', () {
      final startBoundary = resolveCcylActivityPhasesFromTimes(
        doing: true,
        startTime: actStart,
        endTime: actEnd,
        now: DateTime.utc(2026, 9, 20, 4, 0), // 北京 12:00 整
      );
      expect(startBoundary, [CcylActivityPhase.ongoing]);

      final endBoundary = resolveCcylActivityPhasesFromTimes(
        doing: true,
        startTime: actStart,
        endTime: actEnd,
        now: DateTime.utc(2026, 9, 20, 6, 0), // 北京 14:00 整
      );
      expect(endBoundary, [CcylActivityPhase.ongoing]);
    });

    test('尚未开始 → 未开始（修复服务端把未开始标成进行中的问题）', () {
      final phases = resolveCcylActivityPhasesFromTimes(
        doing: true,
        enrollStartTime: enrollStart,
        enrollEndTime: enrollEnd,
        startTime: actStart,
        endTime: actEnd,
        now: DateTime.utc(2026, 9, 19, 20, 0), // 北京 09-20 04:00
      );
      expect(phases, [CcylActivityPhase.notStarted]);
    });

    test('时间窗均已结束 → 已结束', () {
      final phases = resolveCcylActivityPhasesFromTimes(
        doing: true,
        enrollStartTime: enrollStart,
        enrollEndTime: enrollEnd,
        startTime: actStart,
        endTime: actEnd,
        now: DateTime.utc(2026, 9, 20, 8, 0), // 北京 16:00
      );
      expect(phases, [CcylActivityPhase.ended]);
    });

    test('报名已截止、活动开始时间在未来 → 未开始', () {
      final phases = resolveCcylActivityPhasesFromTimes(
        doing: true,
        enrollEndTime: enrollEnd, // 北京 10:00 截止
        startTime: actStart, // 北京 12:00 开始
        now: DateTime.utc(2026, 9, 20, 2, 30), // 北京 10:30，报名已截止
      );
      expect(phases, [CcylActivityPhase.notStarted]);
    });

    test('时间信息完全缺失 → 优先显示报名中（系列条目常不携带场次时间）', () {
      expect(
        resolveCcylActivityPhasesFromTimes(
          doing: true,
          now: DateTime.utc(2026, 9, 20, 4, 0),
        ),
        [CcylActivityPhase.enrolling],
      );
    });

    test('报名开始时间可解析且在未来 → 未开始', () {
      final phases = resolveCcylActivityPhasesFromTimes(
        doing: true,
        enrollStartTime: enrollStart,
        now: DateTime.utc(2026, 9, 19, 20, 0), // 北京 09-20 04:00，早于报名开始
      );
      expect(phases, [CcylActivityPhase.notStarted]);
    });

    test('多时段子活动：仅结束时间可解析且未到 → 优先显示报名中而非未开始', () {
      final phases = resolveCcylActivityPhasesFromTimes(
        doing: true,
        enrollEndTime: enrollEnd,
        now: DateTime.utc(2026, 9, 20, 0, 0), // 北京 08:00，报名期内
      );
      expect(phases, [CcylActivityPhase.enrolling]);
    });

    test('多时段子活动：仅报名截止时间已过、无其他信息 → 优先显示报名中', () {
      // 另一场次可能正在报名，系列条目自身时间不完整时不判「未开始」。
      final phases = resolveCcylActivityPhasesFromTimes(
        doing: true,
        enrollEndTime: enrollEnd,
        now: DateTime.utc(2026, 9, 20, 3, 0), // 北京 11:00，报名已截止
      );
      expect(phases, [CcylActivityPhase.enrolling]);
    });

    test('多时段子活动：仅开始时间可解析且已到 → 优先显示进行中', () {
      final phases = resolveCcylActivityPhasesFromTimes(
        doing: true,
        startTime: actStart,
        now: DateTime.utc(2026, 9, 20, 5, 0), // 北京 13:00
      );
      expect(phases, [CcylActivityPhase.ongoing]);
    });
  });

  group('resolveCcylActivityPhases（模型入口）', () {
    test('尚未开始的活动不再显示服务端的进行中', () {
      final activity = _activity(
        enrollStart: '2026-09-20 08:00:00',
        enrollEnd: '2026-09-20 10:00:00',
        start: '2026-09-20 12:00:00',
        end: '2026-09-20 14:00:00',
      );
      expect(
        resolveCcylActivityPhases(
          activity,
          now: DateTime.utc(2026, 9, 19, 20, 0),
        ),
        [CcylActivityPhase.notStarted],
      );
      expect(
        resolveCcylActivityPhases(
          activity,
          now: DateTime.utc(2026, 9, 20, 5, 0),
        ),
        [CcylActivityPhase.ongoing],
      );
    });

    test('已预约优先于时间匹配', () {
      expect(
        resolveCcylActivityPhases(
          _activity(subscribed: true),
          now: DateTime.utc(2026, 9, 20, 4, 0),
        ),
        [CcylActivityPhase.subscribed],
      );
    });
  });

  group('isCcylSeriesPhaseAmbiguous', () {
    test('doing=true 且无时间信息 → 状态为乐观兜底，需要场次数据校准', () {
      expect(
        isCcylSeriesPhaseAmbiguous(
          _activity(),
          now: DateTime.utc(2026, 9, 20, 4, 0),
        ),
        isTrue,
      );
    });

    test('时间窗命中或能明确判定时无需校准', () {
      final now = DateTime.utc(2026, 9, 20, 1, 0); // 北京 09:00
      expect(
        isCcylSeriesPhaseAmbiguous(
          _activity(
            enrollStart: '2026-09-20 08:00:00',
            enrollEnd: '2026-09-20 10:00:00',
          ),
          now: now,
        ),
        isFalse,
      );
      expect(
        isCcylSeriesPhaseAmbiguous(
          _activity(enrollEnd: '2026-09-20 10:00:00'),
          now: DateTime.utc(2026, 9, 20, 8, 0), // 报名已截止且无其他信息
        ),
        isTrue, // 走 doing 兜底（报名中），仍需场次数据确认
      );
      expect(
        isCcylSeriesPhaseAmbiguous(
          _activity(start: '2026-09-20 12:00:00'),
          now: DateTime.utc(2026, 9, 19, 20, 0), // 活动尚未开始
        ),
        isFalse,
      );
      expect(
        isCcylSeriesPhaseAmbiguous(
          _activity(end: '2026-09-20 14:00:00'),
          now: DateTime.utc(2026, 9, 20, 8, 0), // 活动已结束
        ),
        isFalse,
      );
    });

    test('doing=false 或已预约不校准', () {
      expect(
        isCcylSeriesPhaseAmbiguous(
          _activity(doing: false),
          now: DateTime.utc(2026, 9, 20, 4, 0),
        ),
        isFalse,
      );
      expect(
        isCcylSeriesPhaseAmbiguous(
          _activity(subscribed: true),
          now: DateTime.utc(2026, 9, 20, 4, 0),
        ),
        isFalse,
      );
    });
  });

  group('mergeCcylSeriesPhases', () {
    final now = DateTime.utc(2026, 9, 20, 1, 0); // 北京 09:00

    test('全部场次已结束 → 系列已结束', () {
      final phases = mergeCcylSeriesPhases([
        _activity(end: '2026-09-20 06:00:00'),
        _activity(end: '2026-09-20 04:00:00'),
      ], now: now);
      expect(phases, [CcylActivityPhase.ended]);
    });

    test('有场次在报名中 → 系列报名中（覆盖未开始的场次）', () {
      final phases = mergeCcylSeriesPhases([
        _activity(
          enrollStart: '2026-09-20 08:00:00',
          enrollEnd: '2026-09-20 10:00:00',
        ),
        _activity(start: '2026-09-20 12:00:00'), // 未开始
      ], now: now);
      expect(phases, [CcylActivityPhase.enrolling]);
    });

    test('报名中与进行中并存', () {
      final phases = mergeCcylSeriesPhases([
        _activity(
          enrollStart: '2026-09-20 08:00:00',
          enrollEnd: '2026-09-20 10:00:00',
        ),
        _activity(start: '2026-09-20 08:30:00', end: '2026-09-20 09:30:00'),
      ], now: now);
      expect(phases, [CcylActivityPhase.enrolling, CcylActivityPhase.ongoing]);
    });

    test('场次状态无有效信息（可预约/兜底）→ 返回空，保留调用方兜底', () {
      expect(
        mergeCcylSeriesPhases([_activity(doing: false)], now: now),
        isEmpty,
      );
      expect(mergeCcylSeriesPhases(const [], now: now), isEmpty);
    });
  });
}
