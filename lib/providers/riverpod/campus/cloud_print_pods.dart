import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/cloud_print_provider.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';

part 'cloud_print_pods.g.dart';

@Riverpod(keepAlive: true)
class CloudPrintNotifier extends _$CloudPrintNotifier {
  @override
  bool updateShouldNotify(
    CloudPrintProvider previous,
    CloudPrintProvider next,
  ) =>
      true;

  @override
  CloudPrintProvider build() {
    final CloudPrintProvider provider;
    if (getIt.isRegistered<CloudPrintProvider>()) {
      provider = getIt<CloudPrintProvider>();
    } else {
      final api = ref.watch(cloudPrintApiServiceBridge);
      final scu = ref.watch(scuAuthBridge);
      provider = CloudPrintProvider(api, scuAuth: scu);
      ref.onDispose(provider.dispose);
    }

    void listener() {
      state = provider;
    }

    provider.addListener(listener);
    ref.onDispose(() => provider.removeListener(listener));

    return provider;
  }
}
