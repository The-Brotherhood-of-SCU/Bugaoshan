import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus_page/campus_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpCampusPage(WidgetTester tester) async {
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
}
