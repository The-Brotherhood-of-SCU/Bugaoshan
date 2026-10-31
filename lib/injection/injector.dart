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
import 'package:bugaoshan/providers/course_curriculum_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/exam_plan_provider.dart';
import 'package:bugaoshan/providers/fitness_test_provider.dart';
import 'package:bugaoshan/providers/grades_provider.dart';
import 'package:bugaoshan/providers/graduate_grades_provider.dart';
import 'package:bugaoshan/providers/graduate_train_plan_provider.dart';
import 'package:bugaoshan/providers/network_device_provider.dart';
import 'package:bugaoshan/providers/passpoint_provider.dart';
import 'package:bugaoshan/providers/cloud_print_provider.dart';
import 'package:bugaoshan/scu_backend/cloud_print/cloud_print_api_service.dart';
import 'package:bugaoshan/scu_backend/cloud_print/cloud_print_auth.dart';
import 'package:bugaoshan/providers/reservation_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/service_applications_provider.dart';
import 'package:bugaoshan/providers/update_provider.dart';
import 'package:bugaoshan/providers/zhhq_repair_provider.dart';
import 'package:bugaoshan/scu_backend/ccyl/ccyl_api_service.dart';
import 'package:bugaoshan/scu_backend/fitness/fitness_api_service.dart';
import 'package:bugaoshan/scu_backend/forgot_password/forgot_password_service.dart';
import 'package:bugaoshan/scu_backend/gs/gs_api_service.dart';
import 'package:bugaoshan/scu_backend/passpoint/new_service_api_service.dart';
import 'package:bugaoshan/scu_backend/payapp/payapp_api_service.dart';
import 'package:bugaoshan/scu_backend/reservation/reservation_api_service.dart';
import 'package:bugaoshan/scu_backend/service_hall/service_api_service.dart';
import 'package:bugaoshan/scu_backend/wfw/wfw_api_service.dart';
import 'package:bugaoshan/scu_backend/zhhq/zhhq_api_service.dart';
import 'package:bugaoshan/scu_backend/zhjw/zhjw_api_service.dart';
import 'package:bugaoshan/scu_backend/core/auth_coordinator.dart';
import 'package:bugaoshan/scu_backend/core/auth_state.dart';
import 'package:bugaoshan/scu_backend/ccyl/ccyl_auth.dart';
import 'package:bugaoshan/scu_backend/fitness/fitness_auth.dart';
import 'package:bugaoshan/scu_backend/gs/gs_auth.dart';
import 'package:bugaoshan/scu_backend/passpoint/new_service_auth.dart';
import 'package:bugaoshan/scu_backend/payapp/payapp_auth.dart';
import 'package:bugaoshan/scu_backend/reservation/reservation_auth.dart';
import 'package:bugaoshan/scu_backend/core/scu_auth.dart';
import 'package:bugaoshan/scu_backend/service_hall/service_auth.dart';
import 'package:bugaoshan/scu_backend/wfw/wfw_auth.dart';
import 'package:bugaoshan/scu_backend/zhhq/zhhq_auth.dart';
import 'package:bugaoshan/services/download_notification_service.dart';
import 'package:bugaoshan/scu_backend/zhjw/zhjw_auth.dart';
import 'package:bugaoshan/services/background_cache_service.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/services/download_manager.dart';
import 'package:bugaoshan/services/exit_service.dart';
import 'package:bugaoshan/services/github_resource_service.dart';
import 'package:bugaoshan/services/reminder/live_activity_coordinator.dart';
import 'package:bugaoshan/services/reminder/reminder_service.dart';
import 'package:bugaoshan/services/reminder/reminder_transport.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/scu_backend/calendar/academic_calendar_service.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'injector.config.dart';

const String _tag = 'Injector';

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
  // 复用 AppLog 的启动缓冲实例，而非新建：DI 装配完成前（getIt 尚未能
  // 提供实例）的启动日志已经写进这个缓冲，若此处另建实例，那批日志将无人
  // 观察——而启动失败恰恰是最需要留痕的时刻。
  // 移植自 PR #369（moranfanhua）。
  getIt.registerLazySingleton<AppLogger>(() => AppLog.bootstrapLogger);
  // 忘记密码流程不依赖登录态，纯 HTTP 工具，同步注册即可
  getIt.registerLazySingleton<ForgotPasswordService>(
    () => ForgotPasswordService(),
  );
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

  // GitHub 资源统一访问入口：镜像/直连选择与回退内聚于 service 内部。
  getIt.registerSingletonAsync<GithubResourceService>(() async {
    await getIt.isReady<AppConfigProvider>();
    return GithubResourceService(getIt<AppConfigProvider>());
  });
  getIt.registerSingletonAsync<PackageInfo>(() => PackageInfo.fromPlatform());
  getIt.registerSingletonAsync<AppInfoProvider>(() async {
    await getIt.isReady<PackageInfo>();
    final packageInfo = getIt<PackageInfo>();
    return AppInfoProvider(
      packageInfo,
      isFdroidInstall: await AppInfoProvider.resolveFdroidInstall(
        packageInfo.installerStore,
      ),
    );
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
    await getIt.isReady<GsAuth>();
    // 预约系统不参与登录后预热：本科生也用不到它，冷启动多打一次只是浪费。
    // 页面首次进入时由 ReservationProvider 的 `ensureLoaded` 触发懒加载。
    return AuthCoordinator([
      getIt<ZhjwAuth>(),
      getIt<WfwAuth>(),
      getIt<PayAppAuth>(),
      getIt<FitnessAuth>(),
      getIt<CcylAuth>(),
      getIt<ServiceAuth>(),
      getIt<ZhhqAuth>(),
      getIt<NewServiceAuth>(),
      getIt<GsAuth>(),
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

  // ── 研教务（gsapp / ehall，研究生模块）──────────────────────────
  getIt.registerSingletonAsync<GsAuth>(() async {
    await getIt.isReady<ScuAuth>();
    return GsAuth(getIt<ScuAuth>());
  });
  getIt.registerSingletonAsync<GsApiService>(() async {
    await getIt.isReady<GsAuth>();
    return GsApiService(getIt<GsAuth>());
  });
  // 研究生成绩：依赖 GsApiService（_postForm 自愈链）。
  getIt.registerSingletonAsync<GraduateGradesProvider>(() async {
    await getIt.isReady<GsApiService>();
    return GraduateGradesProvider(getIt<GsApiService>());
  });
  // 研究生培养进度：依赖 GsApiService（wdpyjhapp 零信封 GET 自愈链）。
  getIt.registerSingletonAsync<GraduateTrainPlanProvider>(() async {
    await getIt.isReady<GsApiService>();
    return GraduateTrainPlanProvider(getIt<GsApiService>());
  });

  // ── 图书馆打印与扫描（按需认证，不加入全站预热）────────────────
  getIt.registerSingletonAsync<CloudPrintAuth>(() async {
    await getIt.isReady<ScuAuth>();
    return CloudPrintAuth(getIt<ScuAuth>());
  }, dispose: (auth) => auth.dispose());
  getIt.registerSingletonAsync<CloudPrintApiService>(() async {
    await getIt.isReady<CloudPrintAuth>();
    return CloudPrintApiService(getIt<CloudPrintAuth>());
  });
  getIt.registerSingletonAsync<CloudPrintProvider>(() async {
    await getIt.isReady<CloudPrintApiService>();
    await getIt.isReady<ScuAuth>();
    return CloudPrintProvider(
      getIt<CloudPrintApiService>(),
      scuAuth: getIt<ScuAuth>(),
    );
  }, dispose: (provider) => provider.dispose());

  // ── 预约系统（service.scu.edu.cn/reservation，活动室预约）────────
  getIt.registerSingletonAsync<ReservationAuth>(() async {
    await getIt.isReady<ScuAuth>();
    return ReservationAuth(getIt<ScuAuth>());
  });
  getIt.registerSingletonAsync<ReservationApiService>(() async {
    await getIt.isReady<ReservationAuth>();
    return ReservationApiService(getIt<ReservationAuth>());
  });
  getIt.registerSingletonAsync<ReservationProvider>(() async {
    await getIt.isReady<ReservationApiService>();
    return ReservationProvider(getIt<ReservationApiService>());
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
  getIt.registerSingletonAsync<CourseCurriculumProvider>(() async {
    await getIt.isReady<ZhjwApiService>();
    return CourseCurriculumProvider(getIt<ZhjwApiService>());
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
    await getIt.isReady<GithubResourceService>();
    return UpdateService(
      getIt<SharedPreferences>(),
      getIt<AppInfoProvider>().currentVersion,
      getIt<GithubResourceService>(),
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
    await getIt.isReady<GithubResourceService>();
    return AcademicCalendarService(
      getIt<SharedPreferences>(),
      getIt<GithubResourceService>(),
    );
  });
  getIt.registerSingletonAsync<WidgetUpdateService>(() async {
    await getIt.isReady<CourseProvider>();
    await getIt.isReady<AppConfigProvider>();
    final courseProvider = getIt<CourseProvider>();
    final appConfig = getIt<AppConfigProvider>();
    final service = WidgetUpdateService();
    courseProvider.onCoursesChanged = () {
      service.updateWidgetData().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        AppLog.e(_tag, '课表变更后同步小组件失败', error: error, stackTrace: stackTrace);
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
      } catch (error, stackTrace) {
        AppLog.e(_tag, '初始化小组件设置失败', error: error, stackTrace: stackTrace);
      }
    }

    return service;
  });

  // 本地提醒排期服务：依赖 CourseProvider 与 AppConfigProvider，负责排期计算与原生同步。
  getIt.registerSingletonAsync<ReminderService>(() async {
    await getIt.isReady<CourseProvider>();
    await getIt.isReady<AppConfigProvider>();
    final service = ReminderService(
      courseProvider: getIt<CourseProvider>(),
      appConfig: getIt<AppConfigProvider>(),
      transport: createReminderTransport(),
    );
    await service.start();
    return service;
  });

  // 实时活动（Live Activity）协调器：仅在 iOS 平台执行物理调度，其他平台完成能力探测后自动停用。
  // 异步触发 start() 而不阻塞启动流程，其内部监听课表状态并在异步就绪后自动对齐。
  getIt.registerSingletonAsync<LiveActivityCoordinator>(() async {
    await getIt.isReady<CourseProvider>();
    final coordinator = LiveActivityCoordinator(
      courseProvider: getIt<CourseProvider>(),
    );
    unawaited(coordinator.start());
    return coordinator;
  });

  // ── Logout cleanup listener ──────────────────────────────────────
  // 当 ScuAuth 状态变为 unknown（logout）时，清理下游 Provider 缓存。
  // 用 listener 机制替代 ScuAuthProvider 直接 getIt 调用（PRR-05）。
  getIt.isReady<ScuAuth>().then((_) {
    getIt<ScuAuth>().addListener(() {
      final scu = getIt<ScuAuth>();
      if (scu.state == AuthState.unknown) {
        // logout 发生，清理子系统会话缓存
        if (getIt.isRegistered<GsAuth>()) {
          getIt<GsAuth>().invalidate();
        }
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
        if (getIt.isRegistered<CloudPrintProvider>()) {
          getIt<CloudPrintProvider>().clear();
        }
        if (getIt.isRegistered<ClassroomProvider>()) {
          getIt<ClassroomProvider>().clear();
        }
        if (getIt.isRegistered<ClassScheduleInquiryProvider>()) {
          getIt<ClassScheduleInquiryProvider>().clear();
        }
        if (getIt.isRegistered<CourseCurriculumProvider>()) {
          getIt<CourseCurriculumProvider>().clear();
        }
        if (getIt.isRegistered<ExamPlanProvider>()) {
          getIt<ExamPlanProvider>().clear();
        }
        if (getIt.isRegistered<GraduateGradesProvider>()) {
          getIt<GraduateGradesProvider>().clear();
        }
        if (getIt.isRegistered<GraduateTrainPlanProvider>()) {
          getIt<GraduateTrainPlanProvider>().clear();
        }
        // 预约系统是独立的 reservation_uid 会话，换号后必须丢弃上一个账号
        // 的活动室与时段缓存，否则会继续展示过期数据。
        if (getIt.isRegistered<ReservationProvider>()) {
          getIt<ReservationProvider>().clear();
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
