import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/pages/campus_page/campus_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppConfigProvider> pumpCampusPage(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final appConfig = AppConfigProvider(prefs);
    await appConfig.init();
    await getIt.reset();
    getIt.registerSingleton<AppConfigProvider>(appConfig);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CampusPage(),
      ),
    );
    await tester.pumpAndSettle();
    return appConfig;
  }

  testWidgets('点击搜索角标展开搜索框，输入关键词后过滤功能', (tester) async {
    await pumpCampusPage(tester);

    expect(find.byIcon(Icons.search), findsOneWidget);
    // 收起时角标与第一个分区标题同行，标题只出现一次（不重复渲染）
    expect(find.text('Academic'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'grade');
    await tester.pumpAndSettle();
    expect(find.text('Search Results'), findsOneWidget);
    expect(find.text('Grade Statistics'), findsWidgets);
    // 不匹配的分区不再展示
    expect(find.text('Utilities'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz-no-match');
    await tester.pumpAndSettle();
    expect(find.text('No matching features'), findsOneWidget);
  });

  testWidgets('关闭搜索后恢复完整列表', (tester) async {
    await pumpCampusPage(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'grade');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('Academic'), findsOneWidget);
    expect(find.text('Utilities'), findsOneWidget);
  });

  testWidgets('切换学生类型后校园页功能分区即时调整', (tester) async {
    final appConfig = await pumpCampusPage(tester);

    // 本科生默认模式：本科教务功能可见，研究生条目隐藏。
    expect(find.text('Grade Statistics'), findsOneWidget);
    expect(find.text('Exam Schedule'), findsOneWidget);
    expect(find.text('Graduate Grades'), findsNothing);

    // 切换为研究生：本科教务功能消失，研究生条目在对应分区原位出现
    // （研究生成绩并入学业区、紧邻成绩统计的位置，顶部视口即可见）。
    appConfig.studentType.value = StudentType.graduate;
    await tester.pumpAndSettle();

    expect(find.text('Grade Statistics'), findsNothing);
    expect(find.text('Exam Schedule'), findsNothing);
    // 通用功能与分区标题不受影响。
    expect(find.text('Academic'), findsOneWidget);
    expect(find.text('Utilities'), findsOneWidget);
    expect(find.text('Graduate Grades'), findsOneWidget);
    expect(find.text('Training Progress'), findsOneWidget);
  });
}
