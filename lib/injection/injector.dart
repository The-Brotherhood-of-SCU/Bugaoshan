import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
import 'package:bugaoshan/providers/class_schedule_inquiry_provider.dart';
import 'package:bugaoshan/providers/classroom_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/exam_plan_provider.dart';
import 'package:bugaoshan/providers/fitness_test_provider.dart';
import 'package:bugaoshan/providers/grades_provider.dart';
import 'package:bugaoshan/providers/network_device_provider.dart';
import 'package:bugaoshan/providers/passpoint_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/service_applications_provider.dart';
import 'package:bugaoshan/providers/update_provider.dart';
import 'package:bugaoshan/providers/zhhq_repair_provider.dart';
import 'package:bugaoshan/services/api/ccyl_api_service.dart';
import 'package:bugaoshan/services/api/fitness_api_service.dart';
import 'package:bugaoshan/services/api/new_service_api_service.dart';
import 'package:bugaoshan/services/api/payapp_api_service.dart';
import 'package:bugaoshan/services/api/service_api_service.dart';
import 'package:bugaoshan/services/api/wfw_api_service.dart';
import 'package:bugaoshan/services/api/zhhq_api_service.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/auth_coordinator.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/ccyl_auth.dart';
import 'package:bugaoshan/services/auth/fitness_auth.dart';
import 'package:bugaoshan/services/auth/new_service_auth.dart';
import 'package:bugaoshan/services/auth/payapp_auth.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/service_auth.dart';
import 'package:bugaoshan/services/auth/wfw_auth.dart';
import 'package:bugaoshan/services/auth/zhhq_auth.dart';
import 'package:bugaoshan/services/download_notification_service.dart';
import 'package:bugaoshan/services/auth/zhjw_auth.dart';
import 'package:bugaoshan/services/background_cache_service.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/services/download_manager.dart';
import 'package:bugaoshan/services/exit_service.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/services/api/academic_calendar_service.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
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
  getIt.registerLazySingleton<AuthLogger>(() => AuthLogger());
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
  getIt.registerSingletonAsync<ServiceAuth>(() async {
    await getIt.isReady<ScuAuth>();
    return ServiceAuth(getIt<ScuAuth>());
  });
  getIt.registerSingletonAsync<ZhhqAuth>(() async {
    await getIt.isReady<ScuAuth>();
    final auth = ZhhqAuth(getIt<ScuAuth>());
    await auth.init();
    return auth;
  });
  getIt.registerSingletonAsync<NewServiceAuth>(() async {
    await getIt.isReady<ScuAuth>();
    return NewServiceAuth(getIt<ScuAuth>());
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
    await getIt.isReady<ServiceAuth>();
    await getIt.isReady<ZhhqAuth>();
    await getIt.isReady<NewServiceAuth>();
    return AuthCoordinator([
      getIt<ZhjwAuth>(),
      getIt<WfwAuth>(),
      getIt<PayAppAuth>(),
      getIt<FitnessAuth>(),
      getIt<CcylAuth>(),
      getIt<ServiceAuth>(),
      getIt<ZhhqAuth>(),
      getIt<NewServiceAuth>(),
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
  getIt.registerSingletonAsync<FitnessApiService>(() async {
    await getIt.isReady<FitnessAuth>();
    return FitnessApiService(getIt<FitnessAuth>());
  });
  getIt.registerSingletonAsync<PayAppApiService>(() async {
    await getIt.isReady<PayAppAuth>();
    return PayAppApiService(getIt<PayAppAuth>());
  });
  getIt.registerSingletonAsync<CcylApiService>(() async {
    await getIt.isReady<CcylAuth>();
    return CcylApiService(getIt<CcylAuth>());
  });
  getIt.registerSingletonAsync<ServiceApiService>(() async {
    await getIt.isReady<ServiceAuth>();
    return ServiceApiService(getIt<ServiceAuth>());
  });
  getIt.registerSingletonAsync<ZhhqApiService>(() async {
    await getIt.isReady<ZhhqAuth>();
    return ZhhqApiService(getIt<ZhhqAuth>());
  });
  getIt.registerSingletonAsync<NewServiceApiService>(() async {
    await getIt.isReady<NewServiceAuth>();
    return NewServiceApiService(getIt<NewServiceAuth>());
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
    await getIt.isReady<ScuAuthProvider>();
    await getIt.isReady<ScuAuth>();
    final prefs = getIt<SharedPreferences>();
    final zhjwApi = getIt<ZhjwApiService>();
    final authProvider = getIt<ScuAuthProvider>();
    final scuAuth = getIt<ScuAuth>();
    String? currentIdentity() => GradesProvider.confirmedUserIdentity(
      isLoggedIn: authProvider.isLoggedIn,
      principal: scuAuth.principal,
    );
    final gradesProvider = GradesProvider(
      prefs,
      zhjwApi,
      initialUserId: currentIdentity(),
    );
    authProvider.addListener(() {
      gradesProvider.setUserIdentity(currentIdentity());
    });
    return gradesProvider;
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
  getIt.registerSingletonAsync<FitnessTestProvider>(() async {
    await getIt.isReady<SharedPreferences>();
    await getIt.isReady<FitnessApiService>();
    return FitnessTestProvider(
      getIt<SharedPreferences>(),
      getIt<FitnessApiService>(),
    );
  });
  getIt.registerSingletonAsync<NetworkDeviceProvider>(() async {
    await getIt.isReady<WfwApiService>();
    await getIt.isReady<WfwAuth>();
    await getIt.isReady<ScuAuth>();
    return NetworkDeviceProvider(
      getIt<WfwApiService>(),
      getIt<WfwAuth>(),
      getIt<ScuAuth>(),
    );
  });
  getIt.registerSingletonAsync<ZhhqRepairProvider>(() async {
    await getIt.isReady<ZhhqApiService>();
    await getIt.isReady<ZhhqAuth>();
    await getIt.isReady<ScuAuth>();
    return ZhhqRepairProvider(
      getIt<ZhhqApiService>(),
      getIt<ZhhqAuth>(),
      getIt<ScuAuth>(),
    );
  });
  getIt.registerSingletonAsync<PasspointProvider>(() async {
    await getIt.isReady<NewServiceApiService>();
    await getIt.isReady<NewServiceAuth>();
    await getIt.isReady<ScuAuth>();
    return PasspointProvider(
      getIt<NewServiceApiService>(),
      getIt<NewServiceAuth>(),
      getIt<ScuAuth>(),
    );
  });
  getIt.registerSingletonAsync<ClassroomProvider>(() async {
    await getIt.isReady<ZhjwApiService>();
    return ClassroomProvider(getIt<ZhjwApiService>());
  });
  getIt.registerSingletonAsync<ClassScheduleInquiryProvider>(() async {
    await getIt.isReady<ZhjwApiService>();
    return ClassScheduleInquiryProvider(getIt<ZhjwApiService>());
  });
  getIt.registerSingletonAsync<ExamPlanProvider>(() async {
    await getIt.isReady<ZhjwApiService>();
    return ExamPlanProvider(getIt<ZhjwApiService>());
  });
  getIt.registerSingletonAsync<ServiceApplicationsProvider>(() async {
    await getIt.isReady<ServiceApiService>();
    return ServiceApplicationsProvider(getIt<ServiceApiService>());
  });
  getIt.registerSingletonAsync<BalanceQueryProvider>(() async {
    await getIt.isReady<SharedPreferences>();
    await getIt.isReady<PayAppApiService>();
    await getIt.isReady<DatabaseService>();
    await getIt.isReady<PayAppAuth>();
    await getIt.isReady<AppConfigProvider>();
    return BalanceQueryProvider(
      getIt<SharedPreferences>(),
      getIt<PayAppApiService>(),
      getIt<DatabaseService>(),
      getIt<PayAppAuth>(),
      getIt<AppConfigProvider>(),
    );
  });
  getIt.registerSingletonAsync<UpdateService>(() async {
    await getIt.isReady<SharedPreferences>();
    await getIt.isReady<AppInfoProvider>();
    return UpdateService(
      getIt<SharedPreferences>(),
      getIt<AppInfoProvider>().currentVersion,
    );
  });
  getIt.registerSingletonAsync<UpdateProvider>(() async {
    await getIt.isReady<UpdateService>();
    await getIt.isReady<AppInfoProvider>();
    return UpdateProvider(
      getIt<UpdateService>(),
      getIt<AppInfoProvider>(),
      DownloadNotificationService(),
    );
  });
  getIt.registerSingletonAsync<BackgroundCacheService>(() async {
    await getIt.isReady<AppConfigProvider>();
    final appConfig = getIt<AppConfigProvider>();
    return BackgroundCacheService(appConfig);
  });
  getIt.registerSingletonAsync<AcademicCalendarService>(() async {
    await getIt.isReady<SharedPreferences>();
    return AcademicCalendarService(getIt<SharedPreferences>());
  });
  getIt.registerSingletonAsync<WidgetUpdateService>(() async {
    await getIt.isReady<CourseProvider>();
    await getIt.isReady<AppConfigProvider>();
    final courseProvider = getIt<CourseProvider>();
    final appConfig = getIt<AppConfigProvider>();
    final service = WidgetUpdateService();
    courseProvider.onCoursesChanged = () {
      service.updateWidgetData().catchError((e) {
        // Ignore widget update errors to prevent unhandled async errors
      });
    };

    // Sync initial widget_show_tomorrow setting to App Group
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      try {
        await service.syncWidgetShowTomorrow(
          appConfig.widgetShowTomorrow.value,
        );
        if (Platform.isIOS) {
          await service.syncWidgetAppearance(
            colorStyle: appConfig.widgetColorStyle.value,
            density: appConfig.widgetDensity.value,
          );
        }
      } catch (e) {
        debugPrint('Failed to sync initial widget setting: $e');
      }
    }

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
        if (getIt.isRegistered<FitnessTestProvider>()) {
          getIt<FitnessTestProvider>().clear();
        }
        if (getIt.isRegistered<NetworkDeviceProvider>()) {
          getIt<NetworkDeviceProvider>().clear();
        }
        if (getIt.isRegistered<ZhhqRepairProvider>()) {
          getIt<ZhhqRepairProvider>().clear();
        }
        if (getIt.isRegistered<PasspointProvider>()) {
          getIt<PasspointProvider>().clear();
        }
        if (getIt.isRegistered<ClassroomProvider>()) {
          getIt<ClassroomProvider>().clear();
        }
        if (getIt.isRegistered<ClassScheduleInquiryProvider>()) {
          getIt<ClassScheduleInquiryProvider>().clear();
        }
        if (getIt.isRegistered<ExamPlanProvider>()) {
          getIt<ExamPlanProvider>().clear();
        }
        if (getIt.isRegistered<ServiceApplicationsProvider>()) {
          getIt<ServiceApplicationsProvider>().clear();
        }
      }
    });
  });
}

Future<void> ensureBasicDependencies() async {
  await getIt.allReady();
}
