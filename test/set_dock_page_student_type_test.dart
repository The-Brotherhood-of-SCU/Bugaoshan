import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/campus_item_config.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/pages/settings/set_dock_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppConfigProvider> pumpDockPage(
    WidgetTester tester, {
    StudentType studentType = StudentType.undergraduate,
    List<String> dockIds = defaultVisibleDockIds,
  }) async {
    SharedPreferences.setMockInitialValues({
      'visibleDockIds': dockIds,
      'studentType': studentType.index,
    });
    final prefs = await SharedPreferences.getInstance();
    final appConfig = AppConfigProvider(prefs);
    await appConfig.init();
    await getIt.reset();
    getIt.registerSingleton<AppConfigProvider>(appConfig);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SetDockPage(),
      ),
    );
    await tester.pumpAndSettle();
    return appConfig;
  }

  testWidgets('研究生模式：不展示本科项，可添加研究生项', (tester) async {
    final appConfig = await pumpDockPage(
      tester,
      studentType: StudentType.graduate,
      // dock 里预置了一个本科项（成绩统计）。
      dockIds: [...defaultVisibleDockIds, dockIdGrades],
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(SetDockPage)))!;

    // 本科项不出现在可见/隐藏列表中。
    expect(find.text(l10n.gradesStats), findsNothing);
    // 研究生项在隐藏列表末尾，先滚动到可见。
    await tester.scrollUntilVisible(
      find.text(l10n.graduateScheduleImport),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final graduateTile = find.widgetWithText(
      ListTile,
      l10n.graduateScheduleImport,
    );
    expect(graduateTile, findsOneWidget);
    final graduateSwitch = find.descendant(
      of: graduateTile,
      matching: find.byType(Switch),
    );
    expect(
      tester.widget<Switch>(graduateSwitch).value,
      isFalse,
      reason: '研究生项默认不在 dock 中',
    );

    await tester.tap(graduateSwitch);
    await tester.pumpAndSettle();

    final ids = appConfig.visibleDockIds.value;
    expect(ids, contains(dockIdGraduateScheduleImport));
    // 关键回归：本科项的配置不被丢弃，切回本科生模式即恢复。
    expect(ids, contains(dockIdGrades));
  });

  testWidgets('本科生模式：研究生项不出现在列表中', (tester) async {
    final appConfig = await pumpDockPage(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(SetDockPage)))!;

    expect(appConfig.studentType.value, StudentType.undergraduate);
    expect(
      find.text(l10n.graduateScheduleImport),
      findsNothing,
      reason: '本科生模式下研究生课表导入不应出现在 dock 自定义列表',
    );
  });
}
