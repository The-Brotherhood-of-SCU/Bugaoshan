import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/models/passpoint.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_log.dart';

part 'passpoint_pods.g.dart';

class PasspointData {
  final List<PasspointDevice> devices;
  final PasspointUserInfo? userInfo;

  const PasspointData({
    required this.devices,
    this.userInfo,
  });
}

@riverpod
class CancellingPasspointMac extends _$CancellingPasspointMac {
  @override
  String? build() => null;

  void setMac(String? mac) => state = mac;
}

@riverpod
class PasspointNotifier extends _$PasspointNotifier {
  static const String _tag = 'PasspointNotifier';

  @override
  Future<PasspointData> build() async {
    final api = ref.watch(newServiceApiServiceBridge);
    final devices = await api.fetchDevices();
    PasspointUserInfo? userInfo;
    try {
      userInfo = await api.fetchUserInfo();
    } catch (error, stackTrace) {
      AppLog.e(
        _tag,
        'fetchUserInfo 失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return PasspointData(devices: devices, userInfo: userInfo);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(newServiceApiServiceBridge);
      final devices = await api.fetchDevices();
      PasspointUserInfo? userInfo;
      try {
        userInfo = await api.fetchUserInfo();
      } catch (error, stackTrace) {
        AppLog.e(
          _tag,
          'fetchUserInfo 失败',
          error: error,
          stackTrace: stackTrace,
        );
      }
      return PasspointData(devices: devices, userInfo: userInfo);
    });
  }

  /// 添加无感设备，成功后刷新列表。
  Future<({bool success, String? errorMessage})> addDevice({
    required String userMac,
    required int macExpireTime,
    String defaultServiceName = '',
  }) async {
    try {
      final api = ref.read(newServiceApiServiceBridge);
      await api.addDevice(
        userMac: userMac,
        macExpireTime: macExpireTime,
        defaultServiceName: defaultServiceName,
      );
      await refresh();
      return (success: true, errorMessage: null);
    } catch (error, stackTrace) {
      AppLog.e(_tag, 'addDevice 失败', error: error, stackTrace: stackTrace);
      final message = _extractMessage(error);
      return (success: false, errorMessage: message);
    }
  }

  /// 取消指定设备的无感认证，成功后刷新列表。
  Future<({bool success, String? errorMessage})> cancelDevice(
    PasspointDevice device,
  ) async {
    ref.read(cancellingPasspointMacProvider.notifier).setMac(device.userMac);
    try {
      final api = ref.read(newServiceApiServiceBridge);
      await api.cancelDevice(userMac: device.userMac);
      await refresh();
      return (success: true, errorMessage: null);
    } catch (error, stackTrace) {
      AppLog.e(
        _tag,
        'cancelDevice 失败',
        error: error,
        stackTrace: stackTrace,
      );
      final message = _extractMessage(error);
      return (success: false, errorMessage: message);
    } finally {
      ref.read(cancellingPasspointMacProvider.notifier).setMac(null);
    }
  }

  static String? _extractMessage(Object error) {
    if (error is ScuException) {
      final message = error.message;
      if (message.isNotEmpty && message != '未登录或登录已过期') {
        return message;
      }
    }
    return null;
  }
}
