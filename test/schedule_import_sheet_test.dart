import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/pages/course/import/import_source_sheet.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDatabaseService implements DatabaseService {
  @override
  List<ScheduleConfig> getAllSchedules() => const [];

  @override
  ScheduleConfig? getScheduleConfig() => null;

  @override
  List<Course> getCourses({String? scheduleId}) => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppConfigProvider appConfig;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    appConfig = AppConfigProvider(prefs);
    await appConfig.init();
    await getIt.reset();
    getIt.registerSingleton<AppConfigProvider>(appConfig);
  });

  /// 打开共用导入弹窗并返回 l10n（用于取文案）。
  Future<AppLocalizations> openSheet(WidgetTester tester) async {
    final provider = CourseProvider(_FakeDatabaseService());
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showScheduleImportSheet(
                    context,
                    courseProvider: provider,
                  ),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('本科生模式：分享 + 教务处两入口，无研究生入口', (tester) async {
    final l10n = await openSheet(tester);

    expect(appConfig.studentType.value, StudentType.undergraduate);
    expect(find.byType(ListTile), findsNWidgets(3));
    for (final label in [
      l10n.importFromShare,
      l10n.importFromJwxt,
      l10n.importFromJwxtOnline,
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text(l10n.importFromGraduate), findsNothing);
  });

  testWidgets('研究生模式：分享 + 研究生入口，无教务处入口', (tester) async {
    appConfig.studentType.value = StudentType.graduate;
    final l10n = await openSheet(tester);

    expect(find.byType(ListTile), findsNWidgets(2));
    for (final label in [l10n.importFromShare, l10n.importFromGraduate]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text(l10n.importFromJwxt), findsNothing);
    expect(find.text(l10n.importFromJwxtOnline), findsNothing);
  });

  testWidgets('矮屏/横屏下最后一个入口仍可滚动触达（回归：9/16 屏高裁切）', (tester) async {
    // 1080x700 物理像素 ÷ 2.625 ≈ 411x267 逻辑像素，比入口加标题的总高度还矮。
    tester.view.physicalSize = const Size(1080, 700);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final l10n = await openSheet(tester);
    final lastTile = find.text(l10n.importFromJwxtOnline);
    expect(lastTile, findsOneWidget);

    // 弹窗内容不可滚动时 ensureVisible 会抛「no Scrollable ancestor」，即本回归的失败点。
    await tester.ensureVisible(lastTile);
    await tester.pumpAndSettle();

    final rect = tester.getRect(lastTile);
    final viewHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(viewHeight));
  });
}
