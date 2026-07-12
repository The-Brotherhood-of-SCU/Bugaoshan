import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/class_schedule_inquiry/class_schedule_inquiry_detail_page.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
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
    getIt.registerSingleton<ZhjwApiService>(_FakeZhjwApiService());
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('班级详情局部显示周末但不修改全局偏好', (tester) async {
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

    final appConfig = getIt<AppConfigProvider>();
    expect(appConfig.showWeekend.value, isFalse);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ClassScheduleInquiryDetailPage)),
    )!;
    expect(find.text(l10n.sunday), findsOneWidget);
  });
}
