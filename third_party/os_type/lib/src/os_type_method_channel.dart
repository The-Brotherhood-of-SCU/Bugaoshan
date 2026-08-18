import 'package:flutter/services.dart';

import 'os_type_platform_interface.dart';

/// An implementation of [OsTypePlatform] that uses method channels.
class MethodChannelOsType extends OsTypePlatform {
  /// The method channel used to interact with the native platform.
  final methodChannel = const MethodChannel('os_type');

  @override
  Future<String?> getDeviceType() async {
    return await methodChannel.invokeMethod<String>('getDeviceType');
  }
}
