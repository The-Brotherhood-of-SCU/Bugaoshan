import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/utils/app_log.dart';

part 'network_device_pods.g.dart';

@riverpod
class OffliningDeviceId extends _$OffliningDeviceId {
  @override
  String? build() => null;

  void setDevice(String? id) => state = id;
}

@riverpod
class NetworkDevicesNotifier extends _$NetworkDevicesNotifier {
  static const String _tag = 'NetworkDevicesNotifier';

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final api = ref.watch(wfwApiServiceBridge);
    return api.fetchNetworkDevices();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(wfwApiServiceBridge);
      return api.fetchNetworkDevices();
    });
  }

  /// 下线设备并在成功后刷新列表。
  Future<bool> forceOffline(Map<String, dynamic> device) async {
    final deviceId = device['device_id']?.toString();
    final ip = device['ip']?.toString();
    if (deviceId == null || deviceId.isEmpty || ip == null || ip.isEmpty) {
      return false;
    }

    ref.read(offliningDeviceIdProvider.notifier).setDevice(deviceId);
    try {
      final api = ref.read(wfwApiServiceBridge);
      await api.forceNetworkDeviceOffline(deviceId: deviceId, ip: ip);
      await refresh();
      return true;
    } catch (error, stackTrace) {
      AppLog.e(
        _tag,
        'forceOffline 失败',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      ref.read(offliningDeviceIdProvider.notifier).setDevice(null);
    }
  }
}
