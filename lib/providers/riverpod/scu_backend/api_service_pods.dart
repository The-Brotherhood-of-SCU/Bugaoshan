import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/scu_backend/ccyl/ccyl_api_service.dart';
import 'package:bugaoshan/scu_backend/cloud_print/cloud_print_api_service.dart';
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

part 'api_service_pods.g.dart';

@Riverpod(keepAlive: true)
ZhjwApiService zhjwApiService(Ref ref) {
  if (getIt.isRegistered<ZhjwApiService>()) {
    return getIt<ZhjwApiService>();
  }
  final auth = ref.watch(zhjwAuthBridge);
  return ZhjwApiService(auth);
}

@Riverpod(keepAlive: true)
WfwApiService wfwApiService(Ref ref) {
  if (getIt.isRegistered<WfwApiService>()) {
    return getIt<WfwApiService>();
  }
  final auth = ref.watch(wfwAuthBridge);
  return WfwApiService(auth);
}

@Riverpod(keepAlive: true)
FitnessApiService fitnessApiService(Ref ref) {
  if (getIt.isRegistered<FitnessApiService>()) {
    return getIt<FitnessApiService>();
  }
  final auth = ref.watch(fitnessAuthBridge);
  return FitnessApiService(auth);
}

@Riverpod(keepAlive: true)
PayAppApiService payAppApiService(Ref ref) {
  if (getIt.isRegistered<PayAppApiService>()) {
    return getIt<PayAppApiService>();
  }
  final auth = ref.watch(payAppAuthBridge);
  return PayAppApiService(auth);
}

@Riverpod(keepAlive: true)
CcylApiService ccylApiService(Ref ref) {
  if (getIt.isRegistered<CcylApiService>()) {
    return getIt<CcylApiService>();
  }
  final auth = ref.watch(ccylAuthBridge);
  return CcylApiService(auth);
}

@Riverpod(keepAlive: true)
ServiceApiService serviceApiService(Ref ref) {
  if (getIt.isRegistered<ServiceApiService>()) {
    return getIt<ServiceApiService>();
  }
  final auth = ref.watch(serviceAuthBridge);
  return ServiceApiService(auth);
}

@Riverpod(keepAlive: true)
ZhhqApiService zhhqApiService(Ref ref) {
  if (getIt.isRegistered<ZhhqApiService>()) {
    return getIt<ZhhqApiService>();
  }
  final auth = ref.watch(zhhqAuthBridge);
  return ZhhqApiService(auth);
}

@Riverpod(keepAlive: true)
NewServiceApiService newServiceApiService(Ref ref) {
  if (getIt.isRegistered<NewServiceApiService>()) {
    return getIt<NewServiceApiService>();
  }
  final auth = ref.watch(newServiceAuthBridge);
  return NewServiceApiService(auth);
}

@Riverpod(keepAlive: true)
GsApiService gsApiService(Ref ref) {
  if (getIt.isRegistered<GsApiService>()) {
    return getIt<GsApiService>();
  }
  final auth = ref.watch(gsAuthBridge);
  return GsApiService(auth);
}

@Riverpod(keepAlive: true)
ReservationApiService reservationApiService(Ref ref) {
  if (getIt.isRegistered<ReservationApiService>()) {
    return getIt<ReservationApiService>();
  }
  final auth = ref.watch(reservationAuthBridge);
  return ReservationApiService(auth);
}

@Riverpod(keepAlive: true)
CloudPrintApiService cloudPrintApiService(Ref ref) {
  if (getIt.isRegistered<CloudPrintApiService>()) {
    return getIt<CloudPrintApiService>();
  }
  final auth = ref.watch(cloudPrintAuthBridge);
  return CloudPrintApiService(auth);
}

@Riverpod(keepAlive: true)
ForgotPasswordService forgotPasswordService(Ref ref) {
  if (getIt.isRegistered<ForgotPasswordService>()) {
    return getIt<ForgotPasswordService>();
  }
  return ForgotPasswordService();
}
