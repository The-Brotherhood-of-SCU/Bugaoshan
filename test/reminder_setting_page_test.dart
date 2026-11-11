import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/reminder_plan.dart';
import 'package:bugaoshan/pages/settings/reminder_setting_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/services/reminder/reminder_service.dart';
import 'package:bugaoshan/services/reminder/reminder_transport.dart';
import 'package:bugaoshan/widgets/adaptive/adaptive_glass_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTransport implements ReminderTransport {
  final List<ReminderPlan> synced = [];
  bool denied = false;
  Completer<ReminderPermissionStatus>? permissionStatusResponse;

  @override
  Future<int?> getPendingLimit() async => null;

  @override
  Future<void> syncPlan(ReminderPlan plan) async {
    if (denied) throw const ReminderPermissionDenied();
    synced.add(plan);
  }

  @override
  Future<void> cancelAll() async {}

  @override
  Future<bool> requestAuthorization({bool provisional = false}) async {
    denied = false;
    return true;
  }

  @override
  Future<ReminderPermissionStatus> getPermissionStatus() async {
    if (permissionStatusResponse != null) return permissionStatusResponse!.future;
    return denied
        ? ReminderPermissionStatus.denied
        : ReminderPermissionStatus.authorized;
  }

  @override
  Future<int> getPendingCount() async =>
      synced.isEmpty ? 0 : synced.last.reminders.length;

  @override
  Future<bool> openNotificationSettings() async => true;
}

class _FakeDatabase extends DatabaseService {
  _FakeDatabase({required ScheduleConfig config}) : _config = config;

  final ScheduleConfig _config;
  List<Course> _courses = [];

  @override
  List<Course> getCourses({String? scheduleId}) => List.of(_courses);

  @override
  List<ScheduleConfig> getAllSchedules() => [_config];

  @override
  ScheduleConfig? getScheduleConfig() => _config;

  @override
  String getCurrentScheduleId() => _config.id;

  @override
  Future<void> addCourse(Course course) async {
    _courses = [..._courses, course];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppConfigProvider appConfig;
  late CourseProvider courseProvider;
  late _FakeTransport transport;
  late ReminderService service;

  DateTime thisSunday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday % 7));
  }

  DateTime tomorrow() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  Future<void> setUpDeps({bool denied = false}) async {
    await getIt.reset();
    LiquidGlassCapabilities.resetForTesting();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    appConfig = AppConfigProvider(prefs);
    await appConfig.init();
    appConfig.reminderEnabled.value = true;

    final db = _FakeDatabase(
      config: ScheduleConfig(
        id: 's1',
        semesterStartDate: thisSunday(),
        totalWeeks: 20,
        timeSlots: const [
          TimeSlot(
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 9, minute: 45),
          ),
        ],
      ),
    );
    courseProvider = CourseProvider(db);
    await courseProvider.addCourse(
      Course(
        name: '高等数学',
        teacher: '张老师',
        location: '综C407',
        dayOfWeek: tomorrow().weekday,
        startWeek: 1,
        endWeek: 20,
        startSection: 1,
        endSection: 1,
        colorValue: 0xFF2196F3,
      ),
    );

    transport = _FakeTransport()..denied = denied;
    service = ReminderService(
      courseProvider: courseProvider,
      appConfig: appConfig,
      transport: transport,
      debounceDuration: Duration.zero,
    );

    getIt.registerSingleton<AppConfigProvider>(appConfig);
    getIt.registerSingleton<ReminderService>(service);
  }

  tearDown(() async {
    service.dispose();
    await getIt.reset();
  });

  Widget buildTestApp() {
    return const MaterialApp(
      locale: Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReminderSettingPage(),
    );
  }

  testWidgets('渲染已授权排期预览、提前时间多选保护与免打扰时段展开', (tester) async {
    await setUpDeps(denied: false);
    await service.reschedule(force: true);
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // 已授权时不显示「通知未开启」横幅
    expect(find.text('通知未开启'), findsNothing);

    // 默认选中「提前 15 分钟」；再次点击唯一的已选项不应清空列表
    await tester.tap(find.text('提前 15 分钟'));
    await tester.pumpAndSettle();
    expect(appConfig.reminderLeadMinutes.value, [15]);

    // 勾选「提前 5 分钟」后升序保存
    await tester.tap(find.text('提前 5 分钟'));
    await tester.pumpAndSettle();
    expect(appConfig.reminderLeadMinutes.value, [5, 15]);

    // 开启「免打扰时段」后展开起止时间行与时间段副标题
    expect(find.text('23:00 – 07:00'), findsNothing);
    await tester.tap(find.text('免打扰时段'));
    await tester.pumpAndSettle();
    expect(find.text('23:00 – 07:00'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);
    expect(find.text('结束'), findsOneWidget);

    // 向下滚动至排期状态区，验证课程名与教室/教师副标题渲染
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('高等数学'), findsWidgets);
    expect(find.textContaining('综C407'), findsWidgets);
  });

  testWidgets('权限查询完成前不显示引导，确认未授权后置顶展示', (tester) async {
    await setUpDeps(denied: true);
    final permissionStatus = Completer<ReminderPermissionStatus>();
    transport.permissionStatusResponse = permissionStatus;
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('通知未开启'), findsNothing);
    expect(find.text('去系统设置'), findsNothing);

    permissionStatus.complete(ReminderPermissionStatus.denied);
    await tester.pumpAndSettle();

    expect(find.text('通知未开启'), findsOneWidget);
    expect(find.text('去系统设置'), findsOneWidget);
  });
}
