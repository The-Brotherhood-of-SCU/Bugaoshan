import 'dart:developer';

import 'package:flutter/foundation.dart';

import 'src/os_type_platform_interface.dart';

export 'src/os_type_plugin.dart';

/// 🌐en:
///
/// Useful for OS and web environment detection
///
/// 🌐中文:
///
/// 用于检测操作系统类型和web环境
abstract class OS {
  /// 🌐en:
  ///
  /// HarmonyOS Device Type, need to call initHarmonyDeviceType() first
  ///
  /// 🌐中文:
  ///
  /// 鸿蒙设备类型，需要调用initHarmonyDeviceType()才可用
  static String? _harmonyDeviceType;

  /// 🌐en:
  ///
  /// Initialize HarmonyOS Device Type
  ///
  /// ⚠️warning: In web environment, it cannot work
  ///
  /// 🌐中文:
  ///
  /// 初始化鸿蒙设备类型
  ///
  /// ⚠️注意，在web环境中无法获取
  static Future<void> initHarmonyDeviceType() async {
    assert(isHarmony, '不能也不需要在非鸿蒙系统中获取鸿蒙设备类型');
    if (isWebEnv) {
      _harmonyDeviceType = '2in1';
      log('暂时无法在web环境中获取鸿蒙设备类型，默认为2in1', name: 'os_type');
      return;
    }
    _harmonyDeviceType = await OsTypePlatform.instance.getDeviceType();
    if (_harmonyDeviceType == null) {
      _harmonyDeviceType = '2in1';
      log('未能获取到鸿蒙设备类型，默认为2in1', name: 'os_type');
    }
  }

  /// 🌐en:
  ///
  /// Current operating system
  ///
  /// 🌐中文:
  ///
  /// 当前操作系统
  static final value = defaultTargetPlatform;

  /// 🌐en:
  ///
  /// Android OS?
  ///
  /// 🌐中文:
  ///
  /// 是否为安卓操作系统
  static final isAndroid = value == TargetPlatform.android;

  /// 🌐en:
  ///
  /// Fuchsia OS?
  ///
  /// 🌐中文:
  ///
  /// 是否为Fuchsia操作系统
  static final isFuchsia = value == TargetPlatform.fuchsia;

  /// 🌐en:
  ///
  /// iOS?
  ///
  /// 🌐中文:
  ///
  /// 是否为iOS
  static final isIOS = value == TargetPlatform.iOS;

  /// 🌐en:
  ///
  /// Linux OS?
  ///
  /// 🌐中文:
  ///
  /// 是否为Linux操作系统
  static final isLinux = value == TargetPlatform.linux;

  /// 🌐en:
  ///
  /// mac OS?
  ///
  /// 🌐中文:
  ///
  /// 是否为mac操作系统
  static final isMacOS = value == TargetPlatform.macOS;

  /// 🌐en:
  ///
  /// Windows OS?
  ///
  /// 🌐中文:
  ///
  /// 是否为Windows操作系统
  static final isWindows = value == TargetPlatform.windows;

  /// 🌐en:
  ///
  /// Harmony OS?
  ///
  /// 🌐中文:
  ///
  /// 是否为鸿蒙操作系统
  static final isHarmony = value.toString() == 'TargetPlatform.ohos';

  /// 🌐en:
  ///
  /// Web environment? ⚠️warning: isWebEnv == kIsWeb, Not related to OS
  ///
  /// 🌐中文:
  ///
  /// 是否为web环境，⚠️注意：isWebEnv == kIsWeb，和操作系统无关
  static final isWebEnv = kIsWeb;

  /// 🌐en:
  ///
  /// Whether it is a PC OS
  ///
  /// Currently, linux, mac and windows are considered PC OS
  ///
  /// For Harmony, When the device type is 2in1, it is considered a PC OS, so need to call [initHarmonyDeviceType] first
  ///
  /// It means that there will be problems in the web environment of HarmonyOS. See [_isPCOS] and [initHarmonyDeviceType]
  ///
  /// 🌐中文:
  ///
  /// 是否属于PC操作系统
  ///
  /// 目前认为linux、mac和windows属于PC操作系统
  ///
  /// 对于鸿蒙，认为设备类型为2in1时属于PC操作系统，所以需要先调用[initHarmonyDeviceType]
  ///
  /// 这意味着鸿蒙web环境中会有问题，见[_isPCOS]和[initHarmonyDeviceType]
  static final isPCOS = _isPCOS();

  /// 🌐en:
  ///
  /// Whether it is a mobile OS, == !isPCOS
  ///
  /// For Harmony, need to call [initHarmonyDeviceType] first, see [isPCOS]
  ///
  /// 🌐中文:
  ///
  /// 是否属于移动操作系统，== !isPCOS
  ///
  /// 对于鸿蒙，需要先调用[initHarmonyDeviceType]，见[isPCOS]
  static final isMobileOS = !isPCOS;

  /// 🌐en:
  ///
  /// See [isPCOS]
  ///
  /// 🌐中文:
  ///
  /// 见[isPCOS]
  static bool _isPCOS() {
    switch (value) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return true;
      default:
        if (isHarmony) {
          assert(
            _harmonyDeviceType != null,
            '在鸿蒙上使用isPC/isMobile之前请先initHarmonyDeviceType()',
          );
          return _harmonyDeviceType == '2in1';
        }
        // 默认其它系统不属于PC，但其实至少fuchsia是不清楚的
        return false;
    }
  }
}
