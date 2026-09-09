import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/campus/class_schedule_inquiry/class_schedule_inquiry_detail_page.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/class_schedule_inquiry_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 当前周固定为第 2 周（学期起点设为一周前）。
final DateTime _kSemesterStart = _weeksAgo(1);

class _FakeZhjwApiService implements ZhjwApiService {
  @override
  Future<List<ClassScheduleInquiryItem>> fetchClassSchedule({
    required String planCode,
    required String classCode,
  }) async {
    return [
      ClassScheduleInquiryItem(
        dayOfWeek: DateTime.sunday,
        startPeriod: 1,
        duration: 2,
        courseCode: 'TEST001',
        courseSeq: '01',
        courseName: '周末课程',
        teacherName: '测试教师',
        weeksDescription: '1-16周',
        campus: '江安',
        building: '一教',
        classroom: 'A101',
      ),
      // 同节次不同周的轮换课：第 2 周只显示「轮换甲」，第 3 周只显示「轮换乙」。
      ClassScheduleInquiryItem(
        dayOfWeek: DateTime.monday,
        startPeriod: 1,
        duration: 2,
        courseCode: 'TEST002',
        courseSeq: '01',
        courseName: '轮换甲',
        teacherName: '测试教师',
        weeksDescription: '1-2周',
        campus: '江安',
        building: '一教',
        classroom: 'A102',
      ),
      ClassScheduleInquiryItem(
        dayOfWeek: DateTime.monday,
        startPeriod: 1,
        duration: 2,
        courseCode: 'TEST003',
        courseSeq: '01',
        courseName: '轮换乙',
        teacherName: '测试教师',
        weeksDescription: '3-4周',
        campus: '江安',
        building: '一教',
        classroom: 'A102',
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({'showWeekend': false});
    final prefs = await SharedPreferences.getInstance();
    getIt.registerSingleton<AppConfigProvider>(AppConfigProvider(prefs));
    final api = _FakeZhjwApiService();
    getIt.registerSingleton<ZhjwApiService>(api);
    getIt.registerSingleton<ClassScheduleInquiryProvider>(
      ClassScheduleInquiryProvider(api),
    );
    getIt.registerSingleton<CourseProvider>(
      CourseProvider(_FakeDatabaseService()),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpDetailPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClassScheduleInquiryDetailPage(
          classInfo: ClassInfo(
            planCode: 'PLAN',
            classCode: 'CLASS',
            planName: '测试培养方案',
            className: '测试班级',
            departmentName: '测试学院',
            subjectName: '测试专业',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('班级详情局部显示周末但不修改全局偏好', (tester) async {
    await pumpDetailPage(tester);

    final appConfig = getIt<AppConfigProvider>();
    expect(appConfig.showWeekend.value, isFalse);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ClassScheduleInquiryDetailPage)),
    )!;
    expect(find.text(l10n.sunday), findsOneWidget);
  });

  testWidgets('同一节次不同周的轮换课只显示所选周的课程', (tester) async {
    await pumpDetailPage(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ClassScheduleInquiryDetailPage)),
    )!;

    // 初始定位到当前周（第 2 周）：轮换甲可见，轮换乙（未来周）被同槽课程
    // 占位，不并排显示。
    expect(find.text(l10n.currentWeek(2)), findsOneWidget);
    expect(find.text('轮换甲'), findsOneWidget);
    expect(find.text('轮换乙'), findsNothing);

    // 切到第 3 周：轮换乙接管该节次，轮换甲消失。
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.text(l10n.currentWeek(3)), findsOneWidget);
    expect(find.text('轮换乙'), findsOneWidget);
    expect(find.text('轮换甲'), findsNothing);

    // 点「本周」徽章回到当前周（第 2 周）。
    await tester.tap(find.text(l10n.actualCurrentWeek(2)));
    await tester.pumpAndSettle();
    expect(find.text(l10n.currentWeek(2)), findsOneWidget);
    expect(find.text('轮换甲'), findsOneWidget);
    expect(find.text('轮换乙'), findsNothing);
  });
}

DateTime _weeksAgo(int weeks) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: weeks * 7));
}

class _FakeDatabaseService extends DatabaseService {
  @override
  List<Course> getCourses({String? scheduleId}) => const [];

  @override
  List<ScheduleConfig> getAllSchedules() => [_scheduleConfig];

  @override
  ScheduleConfig getScheduleConfig() => _scheduleConfig;

  @override
  String getCurrentScheduleId() => _scheduleConfig.id;

  @override
  Future<void> saveScheduleConfig(ScheduleConfig config) async {}

  static final ScheduleConfig _scheduleConfig = ScheduleConfig(
    id: 'fake',
    semesterName: '测试学期',
    semesterStartDate: _kSemesterStart,
    totalWeeks: 20,
  );
}
