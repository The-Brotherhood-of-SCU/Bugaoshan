import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';

part 'service_applications_pods.g.dart';

@Riverpod(keepAlive: true)
class ServiceApplicationsNotifier extends _$ServiceApplicationsNotifier {
  @override
  FutureOr<List<Map<String, dynamic>>> build() async {
    final auth = ref.watch(scuAuthProviderBridge);
    if (!auth.isLoggedIn) return const [];
    final api = ref.watch(serviceApiServiceBridge);
    return api.fetchMyApplications();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(serviceApiServiceBridge);
      return api.fetchMyApplications();
    });
  }
}
