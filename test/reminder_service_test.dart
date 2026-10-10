import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/reminder_plan.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/services/reminder/reminder_plan_builder.dart';
import 'package:bugaoshan/services/reminder/reminder_service.dart';
import 'package:bugaoshan/services/reminder/reminder_transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [ReminderService] 排期生命周期与协调逻辑单元测试。
///
/// 覆盖数据源监听变更、防抖合并、哈希短路、全量重置与异常重试等核心状态流转。
class RecordingTransport implements ReminderTransport {
  final List<ReminderPlan> synced = [];
  int cancelAllCount = 0;
  Object? failWith;
  bool unavailable = false;
  bool denied = false;

  @override
  Future<void> syncPlan(ReminderPlan plan) async {
    if (unavailable) throw const ReminderTransportUnavailable();
    if (denied) throw const ReminderPermissionDenied();
    if (failWith != null) throw failWith!;
    synced.add(plan);
  }

  @override
  Future<void> cancelAll() async {
    if (unavailable) throw const ReminderTransportUnavailable();
    if (denied) throw const ReminderPermissionDenied();
    if (failWith != null) throw failWith!;
    cancelAllCount++;
  }

  @override
  Future<bool> requestAuthorization({bool provisional = false}) async {
    if (unavailable) throw const ReminderTransportUnavailable();
    return !denied;
  }

  @override
  Future<String> getPermissionStatus() async => unavailable
      ? MethodChannelReminderTransport.permissionUnknown
      : (denied ? 'denied' : 'authorized');

  @override
  Future<int> getPendingCount() async =>
      unavailable ? 0 : (synced.isEmpty ? 0 : synced.last.reminders.length);

  @override
  Future<bool> openNotificationSettings() async => !unavailable;

  /// 默认不限制投递配额，特定截断测试用例按需配置。
  @override
  int? pendingLimit;
}

/// 内存测试桩数据源，模拟 [DatabaseService] 核心接口以避免测试对原生平台存储插件的依赖。
class _FakeDatabase extends DatabaseService {
  _FakeDatabase({ScheduleConfig? config}) : _config = config;

  ScheduleConfig? _config;
  List<Course> _courses = [];

  @override
  List<Course> getCourses({String? scheduleId}) => List.of(_courses);

  @override
  List<ScheduleConfig> getAllSchedules() =>
      _config == null ? const [] : [_config!];

  @override
  ScheduleConfig? getScheduleConfig() => _config;

  @override
  String getCurrentScheduleId() => _config?.id ?? '';

  @override
  Future<void> saveScheduleConfig(ScheduleConfig config) async {
    _config = config;
  }

  @override
  Future<void> addCourse(Course course) async {
    _courses = [..._courses, course];
  }

  @override
  Future<void> updateCourse(Course course) async {
    _courses = [
      for (final c in _courses)
        if (c.id == course.id) course else c,
    ];
  }

  @override
  Future<void> deleteCourse(String courseId) async {
    _courses = _courses.where((c) => c.id != courseId).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDatabase db;
  late CourseProvider courseProvider;
  late AppConfigProvider appConfig;
  late RecordingTransport transport;
  late ReminderService service;

  /// 本周日（校历口径下教学周的首日）。
  ///
  /// 课程用例都以它为学期起点，使「当前时刻落在第 1 教学周内」不随运行日期变化。
  /// 若把起点固定成某个历史日期，测试在学期结束后运行时会因超出总周数而排不出提醒。
  DateTime thisSunday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday % 7));
  }

  /// 明天零点。
  ///
  /// 基准课程排在明天的星期，使其触发时刻必定晚于当前时刻、且必定落在从今天起算的
  /// 7 天窗口内。若固定成某个星期（如周二），在该星期当天运行时会因触发时刻已过、
  /// 下一次又要等到窗口之外而被过滤，排期结果随运行日期变化。
  DateTime tomorrow() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  /// 构造一门课程，默认排在明天，活跃区间覆盖本教学周。
  Course course({
    String name = '高等数学',
    int? dayOfWeek,
    int startWeek = 1,
    int endWeek = 20,
    List<int>? customWeeks,
  }) => Course(
    name: name,
    teacher: '张老师',
    location: '综C407',
    dayOfWeek: dayOfWeek ?? tomorrow().weekday,
    // 学期起点为本教学周首日（周日），故本周即第 1 教学周。
    startWeek: startWeek,
    endWeek: endWeek,
    startSection: 1,
    endSection: 1,
    colorValue: 0xFF2196F3,
    customWeeks: customWeeks,
  );

  ScheduleConfig schedule() => ScheduleConfig(
    id: 's1',
    semesterStartDate: thisSunday(),
    totalWeeks: 20,
    timeSlots: const [
      TimeSlot(
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 9, minute: 45),
      ),
    ],
  );

  /// 初始化测试环境：配置基准课表（周二单课程）与提醒测试服务。
  Future<void> setUpService({bool enabled = true}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    appConfig = AppConfigProvider(prefs);
    await appConfig.init();
    appConfig.reminderEnabled.value = enabled;

    db = _FakeDatabase(config: schedule());
    courseProvider = CourseProvider(db);
    await courseProvider.addCourse(course());

    transport = RecordingTransport();
    service = ReminderService(
      courseProvider: courseProvider,
      appConfig: appConfig,
      transport: transport,
      // 测试环境将防抖延迟设为 0，避免引入真实时钟等待。
      debounceDuration: Duration.zero,
    );
  }

  tearDown(() {
    service.dispose();
  });

  group('排期触发', () {
    test('启用后首次排期会把计划投递出去', () async {
      await setUpService();
      await service.reschedule(force: true);

      expect(transport.synced, isNotEmpty);
      final plan = transport.synced.last;
      expect(plan.channel, ReminderPlanBuilder.defaultChannel);
      expect(plan.reminders, isNotEmpty);
    });

    test('未启用时不投递计划，只清空', () async {
      await setUpService(enabled: false);
      await service.reschedule(force: true);

      expect(transport.synced, isEmpty);
      expect(transport.cancelAllCount, 1);
    });

    test('计划内容未变化时短路，不重复投递', () async {
      await setUpService();
      await service.reschedule(force: true);
      final firstCount = transport.synced.length;
      await service.reschedule(force: true);
      await service.reschedule(force: true);

      // planId 未变触发短路，仅首轮执行物理同步
      expect(transport.synced.length, firstCount);
    });

    test('课表变化会触发重排并改变计划', () async {
      await setUpService();
      await service.reschedule(force: true);
      final before = transport.synced.last.planId;

      // 新增一门同样排在明天的课：触发时刻晚于当前时刻，且落在 7 天窗口内，
      // 因此该用例不受运行日期与时刻影响。
      courseProvider.courses.value = [
        ...courseProvider.courses.value,
        course(name: '线性代数'),
      ];
      await service.reschedule(force: true);

      expect(transport.synced.last.planId, isNot(before));
      expect(transport.synced.last.reminders, hasLength(2));
    });

    test('隐私开关变化会触发重排（锁屏正文随之变化）', () async {
      await setUpService();
      await service.reschedule(force: true);
      expect(transport.synced.last.reminders.first.body, contains('张老师'));

      appConfig.showTeacherName.value = false;
      await service.reschedule(force: true);

      expect(
        transport.synced.last.reminders.first.body,
        isNot(contains('张老师')),
      );
      expect(transport.synced.last.reminders.first.body, contains('综C407'));
    });

    test('关掉总开关会清空已排期提醒，而不只是停止新增', () async {
      await setUpService();
      await service.reschedule(force: true);
      expect(transport.synced, isNotEmpty);

      appConfig.reminderEnabled.value = false;
      await service.reschedule(force: true);

      expect(transport.cancelAllCount, 1);
    });

    test('新增课程后经监听自动重排（不依赖显式调用）', () async {
      await setUpService();
      await service.start();
      final before = transport.synced.length;

      // 新增的课同样排在明天：触发时刻晚于当前时刻且落在窗口内。
      await courseProvider.addCourse(course(name: '大学物理'));
      // 多轮刷新微任务与事件队列，确保异步调用链全部执行完毕。
      await pumpEventQueue();
      await Future<void>.delayed(Duration.zero);
      await pumpEventQueue();

      expect(transport.synced.length, greaterThan(before));
    });
  });

  group('失败与不可用', () {
    test('投递失败时记录 lastError 且下一次仍会重试同一份计划', () async {
      await setUpService();
      transport.failWith = Exception('boom');
      await service.reschedule(force: true);

      expect(service.lastError.value, isNotNull);
      expect(transport.synced, isEmpty);

      // 同步失败时不记录 _lastPushedPlanId，恢复后确保重新尝试同步当前计划
      transport.failWith = null;
      await service.reschedule(force: true);
      expect(transport.synced, hasLength(1));
      expect(service.lastError.value, isNull);
    });

    test('原生未接线时不视为错误，仅保留可观测的计划', () async {
      await setUpService();
      transport.unavailable = true;
      await service.reschedule(force: true);

      // 通道未就绪属于降级状态，不记录 lastError
      expect(service.lastError.value, isNull);
      expect(service.lastPlan.value, isNotNull);
      expect(service.needsPermission.value, isFalse);
    });

    test('未授权时标记 needsPermission 而非 lastError', () async {
      await setUpService();
      transport.denied = true;
      await service.reschedule(force: true);

      expect(service.needsPermission.value, isTrue);
      expect(service.lastError.value, isNull);

      // 权限授予后重新排期并清除权限缺失标记
      transport.denied = false;
      await service.onPermissionGranted();
      expect(service.needsPermission.value, isFalse);
      expect(transport.synced, hasLength(1));
    });

    test('dispose 之后不再排期', () async {
      await setUpService();
      service.dispose();
      await service.reschedule(force: true);

      expect(transport.synced, isEmpty);
      expect(transport.cancelAllCount, 0);
    });

    test('fireProbe 不撤销既有课表提醒', () async {
      await setUpService();
      await service.reschedule(force: true);
      final before = transport.synced.last;

      await service.fireProbe(title: '探针', body: '15 秒后');

      // 原生采用全量替换策略：探针计划必须合并常规提醒，防止存量排期被全量撤销。
      final probePlan = transport.synced.last;
      expect(
        probePlan.reminders.where((r) => r.id.startsWith('probe:')),
        hasLength(1),
      );
      // 比对时过滤已过期项，验证未来待触发项在探针下发时得到完整保留。
      final stillUpcoming = before.reminders.where(
        (r) => r.fireAt.isAfter(DateTime.now()),
      );
      expect(
        probePlan.reminders
            .where((r) => !r.id.startsWith('probe:'))
            .map((r) => r.id),
        containsAll(stillUpcoming.map((r) => r.id)),
      );
    });

    test('fireProbe 之后重排不会被短路键挡住', () async {
      await setUpService();
      await service.reschedule(force: true);
      await service.fireProbe(title: '探针', body: '15 秒后');
      final afterProbe = transport.synced.length;

      // 发送探针后需重置短路哈希，确保后续重排能恢复标准计划。
      await service.reschedule(force: true);

      expect(transport.synced, hasLength(afterProbe + 1));
      expect(
        transport.synced.last.reminders.where((r) => r.id.startsWith('probe:')),
        isEmpty,
      );
    });

    test('平台上限在 Dart 侧裁剪，而不是交给系统丢', () async {
      await setUpService();
      // 分散配置周二至周日多门课程，消除测试对当前执行日期的隐式依赖。
      for (var weekday = 2; weekday <= 7; weekday++) {
        await courseProvider.addCourse(
          course(name: '课$weekday', dayOfWeek: weekday),
        );
      }
      transport.pendingLimit = 3;

      await service.reschedule(force: true);

      final plan = transport.synced.last;
      expect(plan.reminders, hasLength(3));
      // 截断项数量记录于 droppedCount，保证排期状态统计的一致性。
      expect(plan.droppedCount, greaterThan(0));
    });
  });

  group('构建计划', () {
    test('buildPlan 使用注入的 now，且反映当前设置', () async {
      await setUpService();
      appConfig.reminderLeadMinutes.value = const [30];

      // 注入今天零点：基准课程排在明天，触发时刻为明天 09:00 提前 30 分钟，
      // 既晚于注入时刻又落在 7 天窗口内，断言与运行日期无关。
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final plan = service.buildPlan(now: today);
      final expected = tomorrow();

      expect(plan.reminders, hasLength(1));
      expect(
        plan.reminders.single.fireAt,
        DateTime(expected.year, expected.month, expected.day, 8, 30),
      );
    });
  });
}
