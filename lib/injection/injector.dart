import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bugaoshan/models/reminder_plan.dart';
import 'package:bugaoshan/models/widget_appearance.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/update_provider.dart';
import 'package:bugaoshan/scu_backend/core/auth_coordinator.dart';
import 'package:bugaoshan/scu_backend/core/auth_state.dart';
import 'package:bugaoshan/scu_backend/core/scu_auth.dart';
import 'package:bugaoshan/scu_backend/ccyl/ccyl_auth.dart';
import 'package:bugaoshan/scu_backend/cloud_print/cloud_print_auth.dart';
import 'package:bugaoshan/scu_backend/fitness/fitness_auth.dart';
import 'package:bugaoshan/scu_backend/gs/gs_auth.dart';
import 'package:bugaoshan/scu_backend/passpoint/new_service_auth.dart';
import 'package:bugaoshan/scu_backend/payapp/payapp_auth.dart';
import 'package:bugaoshan/scu_backend/reservation/reservation_auth.dart';
import 'package:bugaoshan/scu_backend/service_hall/service_auth.dart';
import 'package:bugaoshan/scu_backend/wfw/wfw_auth.dart';
import 'package:bugaoshan/scu_backend/zhhq/zhhq_auth.dart';
import 'package:bugaoshan/scu_backend/zhjw/zhjw_auth.dart';
import 'package:bugaoshan/services/background_cache_service.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/services/download_manager.dart';
import 'package:bugaoshan/services/download_notification_service.dart';
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
  _configureAsyncDependencies();
}

void _configureAsyncDependencies() {
  getIt.registerSingletonAsync<SharedPreferences>(
    () => SharedPreferences.getInstance(),
  );

  // GitHub 资源统一访问入口：镜像/直连选择与回退内聚于 service 内部。
  getIt.registerSingletonAsync<GithubResourceService>(() async {
    await getIt.isReady<SharedPreferences>();
    final prefs = getIt<SharedPreferences>();
    return GithubResourceService(
      useProxy: () => prefs.getBool('useGithubProxy') ?? true,
    );
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
  getIt.registerSingletonAsync<GsAuth>(() async {
    await getIt.isReady<ScuAuth>();
    return GsAuth(getIt<ScuAuth>());
  });
  getIt.registerSingletonAsync<CloudPrintAuth>(() async {
    await getIt.isReady<ScuAuth>();
    return CloudPrintAuth(getIt<ScuAuth>());
  }, dispose: (auth) => auth.dispose());
  getIt.registerSingletonAsync<ReservationAuth>(() async {
    await getIt.isReady<ScuAuth>();
    return ReservationAuth(getIt<ScuAuth>());
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

  // ── Auth Provider ───────────────────────────────────────────────
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

  // ── 客户端辅助服务 ──────────────────────────────────────────────
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
    await getIt.isReady<SharedPreferences>();
    final prefs = getIt<SharedPreferences>();
    return BackgroundCacheService(
      getBackgroundImagePath: () => prefs.getString('backgroundImagePath'),
    );
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
    await getIt.isReady<SharedPreferences>();
    final courseProvider = getIt<CourseProvider>();
    final prefs = getIt<SharedPreferences>();
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
          prefs.getBool('widget_show_tomorrow') ?? false,
        );
        if (Platform.isIOS) {
          final colorIdx = prefs.getInt('widget_color_style') ?? 0;
          final densityIdx = prefs.getInt('widget_density') ?? 0;
          await service.syncWidgetAppearance(
            colorStyle: colorIdx < WidgetColorStyle.values.length
                ? WidgetColorStyle.values[colorIdx]
                : WidgetColorStyle.colorful,
            density: densityIdx < WidgetDensity.values.length
                ? WidgetDensity.values[densityIdx]
                : WidgetDensity.standard,
          );
        }
      } catch (error, stackTrace) {
        AppLog.e(_tag, '初始化小组件设置失败', error: error, stackTrace: stackTrace);
      }
    }

    return service;
  });

  // 本地提醒排期服务：依赖 CourseProvider 与原生排期 Transport
  getIt.registerSingletonAsync<ReminderService>(() async {
    await getIt.isReady<CourseProvider>();
    await getIt.isReady<SharedPreferences>();
    final prefs = getIt<SharedPreferences>();
    final service = ReminderService(
      courseProvider: getIt<CourseProvider>(),
      getSettings: () {
        final leadList = prefs.getStringList('reminder_lead_minutes')
            ?.map(int.tryParse)
            .whereType<int>()
            .toList();
        final qStart = prefs.getInt('reminder_quiet_start');
        final qEnd = prefs.getInt('reminder_quiet_end');
        return ReminderSettings(
          courseReminderEnabled: prefs.getBool('reminder_enabled') ?? false,
          leadMinutes: (leadList == null || leadList.isEmpty) ? const [15] : leadList,
          quietStart: (qStart == null || qStart < 0)
              ? null
              : TimeOfDay(hour: qStart ~/ 60, minute: qStart % 60),
          quietEnd: (qEnd == null || qEnd < 0)
              ? null
              : TimeOfDay(hour: qEnd ~/ 60, minute: qEnd % 60),
          windowDays: prefs.getInt('reminder_window_days') ?? ReminderSettings.defaultWindowDays,
          includeLocation: prefs.getBool('showLocation') ?? true,
          includeTeacher: prefs.getBool('showTeacherName') ?? true,
        );
      },
      transport: createReminderTransport(),
    );
    await service.start();
    return service;
  });

  // 实时活动（Live Activity）协调器：仅在 iOS 平台执行物理调度，其他平台完成能力探测后自动停用。
  getIt.registerSingletonAsync<LiveActivityCoordinator>(() async {
    await getIt.isReady<CourseProvider>();
    final coordinator = LiveActivityCoordinator(
      courseProvider: getIt<CourseProvider>(),
    );
    unawaited(coordinator.start());
    return coordinator;
  });

  // ── Logout cleanup listener ──────────────────────────────────────
  getIt.isReady<ScuAuth>().then((_) {
    getIt<ScuAuth>().addListener(() {
      final scu = getIt<ScuAuth>();
      if (scu.state == AuthState.unknown) {
        if (getIt.isRegistered<GsAuth>()) {
          getIt<GsAuth>().invalidate();
        }
      }
    });
  });
}

Future<void> ensureBasicDependencies() async {
  await getIt.allReady();
}
