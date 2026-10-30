import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/service_applications_provider.dart';
import 'package:bugaoshan/providers/update_provider.dart';
import 'package:bugaoshan/scu_backend/calendar/academic_calendar_service.dart';
import 'package:bugaoshan/scu_backend/ccyl/ccyl_api_service.dart';
import 'package:bugaoshan/scu_backend/cloud_print/cloud_print_api_service.dart';
import 'package:bugaoshan/scu_backend/fitness/fitness_api_service.dart';
import 'package:bugaoshan/scu_backend/gs/gs_api_service.dart';
import 'package:bugaoshan/scu_backend/passpoint/new_service_api_service.dart';
import 'package:bugaoshan/scu_backend/payapp/payapp_api_service.dart';
import 'package:bugaoshan/scu_backend/reservation/reservation_api_service.dart';
import 'package:bugaoshan/scu_backend/service_hall/service_api_service.dart';
import 'package:bugaoshan/scu_backend/wfw/wfw_api_service.dart';
import 'package:bugaoshan/scu_backend/zhhq/zhhq_api_service.dart';
import 'package:bugaoshan/scu_backend/zhjw/zhjw_api_service.dart';
import 'package:bugaoshan/scu_backend/core/auth_coordinator.dart';
import 'package:bugaoshan/scu_backend/ccyl/ccyl_auth.dart';
import 'package:bugaoshan/scu_backend/cloud_print/cloud_print_auth.dart';
import 'package:bugaoshan/scu_backend/fitness/fitness_auth.dart';
import 'package:bugaoshan/scu_backend/gs/gs_auth.dart';
import 'package:bugaoshan/scu_backend/passpoint/new_service_auth.dart';
import 'package:bugaoshan/scu_backend/payapp/payapp_auth.dart';
import 'package:bugaoshan/scu_backend/reservation/reservation_auth.dart';
import 'package:bugaoshan/scu_backend/core/scu_auth.dart';
import 'package:bugaoshan/scu_backend/service_hall/service_auth.dart';
import 'package:bugaoshan/scu_backend/wfw/wfw_auth.dart';
import 'package:bugaoshan/scu_backend/zhhq/zhhq_auth.dart';
import 'package:bugaoshan/scu_backend/zhjw/zhjw_auth.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/services/download_manager.dart';
import 'package:bugaoshan/services/github_resource_service.dart';
import 'package:bugaoshan/utils/app_logger.dart';

// ── 基础单例桥接 ─────────────────────────────────────────────────────────────

final sharedPreferencesBridge = Provider<SharedPreferences>(
  (ref) => getIt<SharedPreferences>(),
);

final appLoggerBridge = Provider<AppLogger>(
  (ref) => getIt<AppLogger>(),
);

final databaseServiceBridge = Provider<DatabaseService>(
  (ref) => getIt<DatabaseService>(),
);

final downloadManagerBridge = Provider<DownloadManager>(
  (ref) => getIt<DownloadManager>(),
);

final githubResourceServiceBridge = Provider<GithubResourceService>(
  (ref) => getIt<GithubResourceService>(),
);

// ── 认证层桥接 ───────────────────────────────────────────────────────────────

final scuAuthBridge = Provider<ScuAuth>(
  (ref) => getIt<ScuAuth>(),
);

final authCoordinatorBridge = Provider<AuthCoordinator>(
  (ref) => getIt<AuthCoordinator>(),
);

final zhjwAuthBridge = Provider<ZhjwAuth>(
  (ref) => getIt<ZhjwAuth>(),
);

final wfwAuthBridge = Provider<WfwAuth>(
  (ref) => getIt<WfwAuth>(),
);

final payAppAuthBridge = Provider<PayAppAuth>(
  (ref) => getIt<PayAppAuth>(),
);

final fitnessAuthBridge = Provider<FitnessAuth>(
  (ref) => getIt<FitnessAuth>(),
);

final ccylAuthBridge = Provider<CcylAuth>(
  (ref) => getIt<CcylAuth>(),
);

final serviceAuthBridge = Provider<ServiceAuth>(
  (ref) => getIt<ServiceAuth>(),
);

final zhhqAuthBridge = Provider<ZhhqAuth>(
  (ref) => getIt<ZhhqAuth>(),
);

final newServiceAuthBridge = Provider<NewServiceAuth>(
  (ref) => getIt<NewServiceAuth>(),
);

final gsAuthBridge = Provider<GsAuth>(
  (ref) => getIt<GsAuth>(),
);

final reservationAuthBridge = Provider<ReservationAuth>(
  (ref) => getIt<ReservationAuth>(),
);

final cloudPrintAuthBridge = Provider<CloudPrintAuth>(
  (ref) => getIt<CloudPrintAuth>(),
);

// ── API 服务层桥接 ───────────────────────────────────────────────────────────

final zhjwApiServiceBridge = Provider<ZhjwApiService>(
  (ref) => getIt<ZhjwApiService>(),
);

final wfwApiServiceBridge = Provider<WfwApiService>(
  (ref) => getIt<WfwApiService>(),
);

final fitnessApiServiceBridge = Provider<FitnessApiService>(
  (ref) => getIt<FitnessApiService>(),
);

final payAppApiServiceBridge = Provider<PayAppApiService>(
  (ref) => getIt<PayAppApiService>(),
);

final ccylApiServiceBridge = Provider<CcylApiService>(
  (ref) => getIt<CcylApiService>(),
);

final serviceApiServiceBridge = Provider<ServiceApiService>(
  (ref) => getIt<ServiceApiService>(),
);

final zhhqApiServiceBridge = Provider<ZhhqApiService>(
  (ref) => getIt<ZhhqApiService>(),
);

final newServiceApiServiceBridge = Provider<NewServiceApiService>(
  (ref) => getIt<NewServiceApiService>(),
);

final gsApiServiceBridge = Provider<GsApiService>(
  (ref) => getIt<GsApiService>(),
);

final reservationApiServiceBridge = Provider<ReservationApiService>(
  (ref) => getIt<ReservationApiService>(),
);

final cloudPrintApiServiceBridge = Provider<CloudPrintApiService>(
  (ref) => getIt<CloudPrintApiService>(),
);

final academicCalendarServiceBridge = Provider<AcademicCalendarService>(
  (ref) => getIt<AcademicCalendarService>(),
);

// ── 过渡期 Provider 桥接（允许在完全重构前被 Riverpod 消费）─────────────────────

class ScuAuthProviderBridgeNotifier extends Notifier<ScuAuthProvider> {
  @override
  bool updateShouldNotify(ScuAuthProvider previous, ScuAuthProvider next) => true;

  @override
  ScuAuthProvider build() {
    final auth = getIt<ScuAuthProvider>();
    void listener() {
      state = auth;
    }
    auth.addListener(listener);
    ref.onDispose(() => auth.removeListener(listener));
    return auth;
  }
}

final scuAuthProviderBridge =
    NotifierProvider<ScuAuthProviderBridgeNotifier, ScuAuthProvider>(
  ScuAuthProviderBridgeNotifier.new,
);

final appConfigProviderBridge = Provider<AppConfigProvider>(
  (ref) => getIt<AppConfigProvider>(),
);

final appInfoProviderBridge = Provider<AppInfoProvider>(
  (ref) => getIt<AppInfoProvider>(),
);

final courseProviderBridge = Provider<CourseProvider>(
  (ref) => getIt<CourseProvider>(),
);

final updateProviderBridge = Provider<UpdateProvider>(
  (ref) => getIt<UpdateProvider>(),
);

final serviceApplicationsProviderBridge = Provider<ServiceApplicationsProvider>(
  (ref) => getIt<ServiceApplicationsProvider>(),
);
