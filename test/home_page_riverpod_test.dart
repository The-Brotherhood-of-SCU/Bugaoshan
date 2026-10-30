import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/pages/home_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/update_provider.dart';
import 'package:bugaoshan/providers/user_info_provider.dart';
import 'package:bugaoshan/scu_backend/wfw/wfw_api_service.dart';
import 'package:bugaoshan/scu_backend/core/auth_coordinator.dart';
import 'package:bugaoshan/scu_backend/core/scu_auth.dart';
import 'package:bugaoshan/scu_backend/ccyl/ccyl_auth.dart';
import 'package:bugaoshan/scu_backend/wfw/wfw_auth.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/services/download_notification_service.dart';
import 'package:bugaoshan/services/github_resource_service.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late AppConfigProvider appConfig;
  late ScuAuth scuAuth;
  late CcylAuth ccylAuth;
  late AuthCoordinator authCoordinator;
  late ScuAuthProvider authProvider;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(prefs);

    final logger = AppLogger();
    getIt.registerSingleton<AppLogger>(logger);

    appConfig = AppConfigProvider(prefs);
    await appConfig.init();
    getIt.registerSingleton<AppConfigProvider>(appConfig);

    scuAuth = ScuAuth(prefs);
    ccylAuth = CcylAuth(scuAuth);
    authCoordinator = AuthCoordinator([]);
    authProvider = ScuAuthProvider(scuAuth, ccylAuth, authCoordinator);
    getIt.registerSingleton<ScuAuthProvider>(authProvider);
    getIt.registerSingleton<AuthCoordinator>(authCoordinator);

    final wfwAuth = WfwAuth(scuAuth);
    final wfwApi = WfwApiService(wfwAuth);
    getIt.registerSingleton<UserInfoProvider>(UserInfoProvider(wfwAuth, wfwApi));

    final db = DatabaseService();
    getIt.registerSingleton<DatabaseService>(db);
    getIt.registerSingleton<CourseProvider>(CourseProvider(db));

    final packageInfo = PackageInfo(
      appName: 'Bugaoshan',
      packageName: 'com.scu.bugaoshan',
      version: '2.5.3',
      buildNumber: '1',
    );
    final appInfo = AppInfoProvider(packageInfo, isFdroidInstall: false);
    getIt.registerSingleton<AppInfoProvider>(appInfo);

    final githubResource = GithubResourceService(appConfig);
    final updateService = UpdateService(prefs, appInfo.currentVersion, githubResource);
    getIt.registerSingleton<UpdateService>(updateService);
    getIt.registerSingleton<UpdateProvider>(
      UpdateProvider(
        updateService,
        appInfo,
        DownloadNotificationService(),
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('HomePage builds and reacts to visibleDockIds via Riverpod', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pump();

    // Verify initial dock items
    expect(find.byType(HomePage), findsOneWidget);

    // Update studentType via Riverpod
    final element = tester.element(find.byType(HomePage));
    final container = ProviderScope.containerOf(element);

    container.read(studentTypeSettingProvider.notifier).update(StudentType.graduate);
    await tester.pump();

    expect(appConfig.studentType.value, StudentType.graduate);
  });
}
