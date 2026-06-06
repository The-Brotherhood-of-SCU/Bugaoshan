import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bugaoshan/providers/plan_completion_provider.dart';
import 'package:bugaoshan/providers/user_info_provider.dart';
import 'package:bugaoshan/providers/train_program_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/balance_query_provider.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/grades_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/ccyl_api_service.dart';
import 'package:bugaoshan/services/api/payapp_api_service.dart';
import 'package:bugaoshan/services/api/wfw_api_service.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/auth_coordinator.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/ccyl_auth.dart';
import 'package:bugaoshan/services/auth/fitness_auth.dart';
import 'package:bugaoshan/services/auth/payapp_auth.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/wfw_auth.dart';
import 'package:bugaoshan/services/auth/zhjw_auth.dart';
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

  // ── 第3层：ScuAuth ──────────────────────────────────────────────
  getIt.registerSingletonAsync<ScuAuth>(() async {
    await getIt.isReady<SharedPreferences>();
    final prefs = getIt<SharedPreferences>();
    final auth = ScuAuth(prefs);
    await auth.init();
    return auth;
  });

  // ── 第2层：子系统 Auth ──────────────────────────────────────────
  getIt.registerSingletonAsync<ZhjwAuth>(() async {
    await getIt.isReady<ScuAuth>();
    return ZhjwAuth(getIt<ScuAuth>());
  });
  getIt.registerSingletonAsync<WfwAuth>(() async {
    await getIt.isReady<ScuAuth>();
    return WfwAuth(getIt<ScuAuth>());
  });
  getIt.registerSingletonAsync<PayAppAuth>(() async {
    await getIt.isReady<ScuAuth>();
    await getIt.isReady<WfwAuth>();
    return PayAppAuth(getIt<ScuAuth>(), getIt<WfwAuth>());
  });
  getIt.registerSingletonAsync<FitnessAuth>(() async {
    await getIt.isReady<ScuAuth>();
    return FitnessAuth(getIt<ScuAuth>());
  });
  getIt.registerSingletonAsync<CcylAuth>(() async {
    await getIt.isReady<ScuAuth>();
    final auth = CcylAuth(getIt<ScuAuth>());
    await auth.init();
    return auth;
  });
  getIt.registerSingletonAsync<AuthCoordinator>(() async {
    await getIt.isReady<ZhjwAuth>();
    await getIt.isReady<WfwAuth>();
    await getIt.isReady<PayAppAuth>();
    await getIt.isReady<FitnessAuth>();
    await getIt.isReady<CcylAuth>();
    return AuthCoordinator([
      getIt<ZhjwAuth>(),
      getIt<WfwAuth>(),
      getIt<PayAppAuth>(),
      getIt<FitnessAuth>(),
      getIt<CcylAuth>(),
    ]);
  });

  // ── 第1层：API Service ──────────────────────────────────────────
  getIt.registerSingletonAsync<ZhjwApiService>(() async {
    await getIt.isReady<ZhjwAuth>();
    return ZhjwApiService(getIt<ZhjwAuth>());
  });
  getIt.registerSingletonAsync<WfwApiService>(() async {
    await getIt.isReady<WfwAuth>();
    return WfwApiService(getIt<WfwAuth>());
  });
  getIt.registerSingletonAsync<PayAppApiService>(() async {
    await getIt.isReady<PayAppAuth>();
    return PayAppApiService(getIt<PayAppAuth>());
  });
  getIt.registerSingletonAsync<CcylApiService>(() async {
    await getIt.isReady<CcylAuth>();
    return CcylApiService(getIt<CcylAuth>());
  });

  // ── Provider ────────────────────────────────────────────────────
  getIt.registerSingletonAsync<ScuAuthProvider>(() async {
    await getIt.isReady<ScuAuth>();
    await getIt.isReady<CcylAuth>();
    await getIt.isReady<AuthCoordinator>();
    final provider = ScuAuthProvider(
      getIt<ScuAuth>(),
      getIt<CcylAuth>(),
      getIt<AuthCoordinator>(),
    );
    await provider.init();
    return provider;
  });
  getIt.registerSingletonAsync<CcylProvider>(() async {
    await getIt.isReady<CcylAuth>();
    await getIt.isReady<CcylApiService>();
    return CcylProvider(getIt<CcylAuth>(), getIt<CcylApiService>());
  });
  getIt.registerSingletonAsync<UserInfoProvider>(() async {
    await getIt.isReady<WfwAuth>();
    await getIt.isReady<WfwApiService>();
    return UserInfoProvider(getIt<WfwAuth>(), getIt<WfwApiService>());
  });
  getIt.registerSingletonAsync<GradesProvider>(() async {
    await getIt.isReady<SharedPreferences>();
    await getIt.isReady<ZhjwApiService>();
    final prefs = getIt<SharedPreferences>();
    final zhjwApi = getIt<ZhjwApiService>();
    return GradesProvider(prefs, zhjwApi);
  });
  getIt.registerSingletonAsync<TrainProgramProvider>(() async {
    await getIt.isReady<ZhjwApiService>();
    return TrainProgramProvider(getIt<ZhjwApiService>());
  });
  getIt.registerSingletonAsync<PlanCompletionProvider>(() async {
    await getIt.isReady<SharedPreferences>();
    await getIt.isReady<ZhjwApiService>();
    final prefs = getIt<SharedPreferences>();
    final zhjwApi = getIt<ZhjwApiService>();
    return PlanCompletionProvider(prefs, zhjwApi);
  });
  getIt.registerSingletonAsync<BalanceQueryProvider>(() async {
    await getIt.isReady<SharedPreferences>();
    await getIt.isReady<PayAppApiService>();
    final prefs = getIt<SharedPreferences>();
    return BalanceQueryProvider(prefs, getIt<PayAppApiService>());
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

  // ── Logout cleanup listener ──────────────────────────────────────
  // 当 ScuAuth 状态变为 unknown（logout）时，清理下游 Provider 缓存。
  // 用 listener 机制替代 ScuAuthProvider 直接 getIt 调用（PRR-05）。
  getIt.isReady<ScuAuth>().then((_) {
    getIt<ScuAuth>().addListener(() {
      final scu = getIt<ScuAuth>();
      if (scu.state == AuthState.unknown) {
        // logout 发生，清理需要登录态的 Provider 缓存
        if (getIt.isRegistered<PlanCompletionProvider>()) {
          getIt<PlanCompletionProvider>().clearCache();
        }
        if (getIt.isRegistered<UserInfoProvider>()) {
          getIt<UserInfoProvider>().clear();
        }
      }
    });
  });
}

Future<void> ensureBasicDependencies() async {
  await getIt.allReady();
}
