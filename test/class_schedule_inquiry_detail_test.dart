import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/class_schedule_inquiry/class_schedule_inquiry_detail_page.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/class_schedule_inquiry_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      // 同节次不同周的轮换课：第 1-2 周显示「轮换甲」，第 3-4 周显示「轮换乙」。
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

  testWidgets('从第 1 周开始，滑动翻页与箭头切换时轮换课跟随所选周', (tester) async {
    await pumpDetailPage(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ClassScheduleInquiryDetailPage)),
    )!;

    // 固定从第 1 周开始：轮换甲可见，轮换乙（未来周）不并排显示。
    expect(find.text(l10n.currentWeek(1)), findsOneWidget);
    expect(find.text('轮换甲'), findsOneWidget);
    expect(find.text('轮换乙'), findsNothing);

    // 左滑翻到第 2 周：轮换甲（1-2 周）仍在，轮换乙未开始。
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
    expect(find.text(l10n.currentWeek(2)), findsOneWidget);
    expect(find.text('轮换甲'), findsOneWidget);
    expect(find.text('轮换乙'), findsNothing);

    // 箭头切到第 3 周：轮换乙接管该节次，轮换甲消失。
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.text(l10n.currentWeek(3)), findsOneWidget);
    expect(find.text('轮换乙'), findsOneWidget);
    expect(find.text('轮换甲'), findsNothing);
  });
}
