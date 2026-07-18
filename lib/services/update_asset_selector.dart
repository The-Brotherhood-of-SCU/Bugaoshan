import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

enum UpdateAssetPlatform { android, windows, linux }

/// Android 设备架构到 APK 文件名的映射
const _androidArchMap = {
  'arm64-v8a': '_arm64-v8a.apk',
  'armeabi-v7a': '_armeabi-v7a.apk',
  'x86_64': '_x86_64.apk',
};

/// Android 架构提供者，负责检测和缓存设备架构
class AndroidArchProvider {
  static final AndroidArchProvider _instance = AndroidArchProvider._internal();
  factory AndroidArchProvider() => _instance;
  AndroidArchProvider._internal();

  String? _cachedArch;
  bool _loaded = false;

  /// 获取设备架构（带缓存）
  Future<String?> getArch() async {
    if (_loaded) return _cachedArch;
    _loaded = true;

    if (!Platform.isAndroid) return null;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      // 优先选择 64 位架构
      final supported64BitAbis = androidInfo.supported64BitAbis;
      for (final abi in supported64BitAbis) {
        if (_androidArchMap.containsKey(abi)) {
          _cachedArch = abi;
          return _cachedArch;
        }
      }
      // 回退到 32 位架构
      final supported32BitAbis = androidInfo.supported32BitAbis;
      for (final abi in supported32BitAbis) {
        if (_androidArchMap.containsKey(abi)) {
          _cachedArch = abi;
          return _cachedArch;
        }
      }
    } catch (_) {
      // 获取失败时返回 null，回退到 universal
    }
    return null;
  }
}

bool _matchesUpdatePlatform(
  String assetName,
  UpdateAssetPlatform platform, {
  String? androidArch,
}) {
  final name = assetName.toLowerCase();
  return switch (platform) {
    UpdateAssetPlatform.android => _matchesAndroidApk(name, androidArch),
    UpdateAssetPlatform.windows =>
      name.contains('_windows_') && name.endsWith('.zip'),
    UpdateAssetPlatform.linux =>
      name.contains('_linux_') && name.endsWith('.tar.gz'),
  };
}

/// 匹配 Android APK：优先匹配设备架构，回退到 universal
bool _matchesAndroidApk(String name, String? androidArch) {
  // 如果指定了架构且匹配，优先返回该架构的 APK
  if (androidArch != null) {
    final suffix = _androidArchMap[androidArch];
    if (suffix != null && name.endsWith(suffix)) {
      return true;
    }
  }
  // 回退到 universal
  return name.endsWith('_universal.apk');
}

/// 选择适合当前平台的更新资源（同步版本，需手动传入架构）
///
/// [assets] GitHub Release 的资源列表
/// [platform] 目标平台
/// [androidArch] Android 设备架构（如 'arm64-v8a'），仅 Android 平台使用。
///   提供时会优先匹配架构特定的 APK，找不到则回退到 universal。
Map<String, dynamic>? selectUpdateAsset(
  Iterable<Map<String, dynamic>> assets,
  UpdateAssetPlatform platform, {
  String? androidArch,
}) {
  if (platform == UpdateAssetPlatform.android && androidArch != null) {
    final suffix = _androidArchMap[androidArch];
    Map<String, dynamic>? universal;
    for (final asset in assets) {
      final name = asset['name'];
      if (name is! String) continue;
      final lower = name.toLowerCase();
      // 记住第一个 universal 作为回退
      if (universal == null && lower.endsWith('_universal.apk')) {
        universal = asset;
      }
      // 找到架构匹配的立即返回
      if (suffix != null && lower.endsWith(suffix)) {
        return asset;
      }
    }
    // 回退到 universal
    return universal;
  }

  // 非 Android 或无架构信息：通用匹配
  for (final asset in assets) {
    final name = asset['name'];
    if (name is String && _matchesUpdatePlatform(name, platform)) {
      return asset;
    }
  }
  return null;
}

/// 选择适合当前平台的更新资源（异步版本，自动检测 Android 架构）
///
/// [assets] GitHub Release 的资源列表
/// [platform] 目标平台
/// 对于 Android 平台，会自动检测设备架构并匹配对应的 APK
Future<Map<String, dynamic>?> selectUpdateAssetAsync(
  Iterable<Map<String, dynamic>> assets,
  UpdateAssetPlatform platform,
) async {
  String? androidArch;
  if (platform == UpdateAssetPlatform.android) {
    androidArch = await AndroidArchProvider().getArch();
  }
  return selectUpdateAsset(assets, platform, androidArch: androidArch);
}
