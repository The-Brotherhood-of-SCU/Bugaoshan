import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bugaoshan/providers/plan_completion_provider.dart';
import 'package:bugaoshan/providers/profile_labels_provider.dart';
import 'package:bugaoshan/providers/train_program_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/grades_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/auth/auth_manager.dart';
import 'package:bugaoshan/services/background_cache_service.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/services/download_manager.dart';
import 'package:bugaoshan/services/exit_service.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'injector.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init', // default
  preferRelativeImports: true, // default
  asExtension: true, // default
)
void configureDependencies() {
  getIt.init();
  getIt.registerSingleton<ExitService>(ExitService());
  getIt.registerSingleton<DownloadManager>(DownloadManager());
  getIt.registerSingleton<ProfileLabelsProvider>(ProfileLabelsProvider());
  _configureAsyncDependencies();
}

void _configureAsyncDependencies() {
  getIt.registerSingletonAsync<SharedPreferences>(
    () => SharedPreferences.getInstance(),
  );
  getIt.registerSingletonAsync<AppConfigProvider>(() async {
    await getIt.isReady<SharedPreferences>();
    final prefs = getIt<SharedPreferences>();
    final instance = AppConfigProvider(prefs);
    await instance.init();
    return instance;
  });
  getIt.registerSingletonAsync<PackageInfo>(() => PackageInfo.fromPlatform());
  getIt.registerSingletonAsync<AppInfoProvider>(() async {
    await getIt.isReady<PackageInfo>();
    final packageInfo = getIt<PackageInfo>();
    return AppInfoProvider(packageInfo);
  });
  getIt.registerSingletonAsync<DatabaseService>(() async {
    final db = DatabaseService();
    await db.init();
    return db;
  });
  getIt.registerSingletonAsync<CourseProvider>(() async {
    await getIt.isReady<DatabaseService>();
    final db = getIt<DatabaseService>();
    return CourseProvider(db);
  });
  // AuthManager — 统一认证管理（初始化所有 session）
  getIt.registerSingletonAsync<AuthManager>(() async {
    await getIt.isReady<SharedPreferences>();
    final prefs = getIt<SharedPreferences>();
    final mgr = AuthManager(prefs);
    await mgr.init();
    return mgr;
  });
  getIt.registerSingletonAsync<ScuAuthProvider>(() async {
    await getIt.isReady<AuthManager>();
    final provider = ScuAuthProvider(getIt<AuthManager>());
    await provider.init();
    return provider;
  });
  getIt.registerSingletonAsync<CcylProvider>(() async {
    await getIt.isReady<AuthManager>();
    return CcylProvider.create(getIt<AuthManager>());
  });
  getIt.registerSingletonAsync<GradesProvider>(() async {
    await getIt.isReady<SharedPreferences>();
    await getIt.isReady<ScuAuthProvider>();
    final prefs = getIt<SharedPreferences>();
    final auth = getIt<ScuAuthProvider>();
    return GradesProvider(prefs, auth);
  });
  getIt.registerSingletonAsync<TrainProgramProvider>(() async {
    await getIt.isReady<ScuAuthProvider>();
    final auth = getIt<ScuAuthProvider>();
    return TrainProgramProvider(auth);
  });
  getIt.registerSingletonAsync<PlanCompletionProvider>(() async {
    await getIt.isReady<SharedPreferences>();
    await getIt.isReady<ScuAuthProvider>();
    final prefs = getIt<SharedPreferences>();
    final auth = getIt<ScuAuthProvider>();
    return PlanCompletionProvider(prefs, auth);
  });
  getIt.registerSingletonAsync<UpdateService>(() async {
    await getIt.isReady<SharedPreferences>();
    await getIt.isReady<AppInfoProvider>();
    return UpdateService(
      getIt<SharedPreferences>(),
      getIt<AppInfoProvider>().currentVersion,
    );
  });
  getIt.registerSingletonAsync<BackgroundCacheService>(() async {
    await getIt.isReady<AppConfigProvider>();
    final appConfig = getIt<AppConfigProvider>();
    return BackgroundCacheService(appConfig);
  });
  getIt.registerSingletonAsync<WidgetUpdateService>(() async {
    await getIt.isReady<CourseProvider>();
    final courseProvider = getIt<CourseProvider>();
    final service = WidgetUpdateService();
    courseProvider.onCoursesChanged = () {
      service.updateWidgetData().catchError((e) {
        // Ignore widget update errors to prevent unhandled async errors
      });
    };
    return service;
  });
}

Future<void> ensureBasicDependencies() async {
  await getIt.allReady();
}
