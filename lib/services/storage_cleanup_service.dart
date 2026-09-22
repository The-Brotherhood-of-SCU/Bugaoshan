import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';

/// 应用本地存储的清理入口，供启动失败恢复页等场景使用。
///
/// 全部为静态方法，调用方自行处理异常与结果反馈。
class StorageCleanupService {
  const StorageCleanupService._();

  /// `getTemporaryDirectory()` 是否等价于「本应用的缓存目录」。
  ///
  /// 只有应用数据隔离的平台支持
  static bool get canClearCacheDirectory =>
      !kIsWeb && !Platform.isWindows && !Platform.isLinux;

  /// 清空 SharedPreferences（登录时间戳、用户信息、设置等）。
  static Future<void> clearSharedPreferences() async {
    await getIt<SharedPreferences>().clear();
  }

  /// 清空缓存目录（`getTemporaryDirectory()`），保留目录本身。
  ///
  /// 仅在 [canClearCacheDirectory] 为 true 的平台调用。
  static Future<void> clearCacheDirectory() async {
    await clearDirectory(await getTemporaryDirectory());
  }

  /// 清空应用数据目录（`getApplicationSupportDirectory()`，含 SQLite 数据库）。
  static Future<void> clearDataDirectory() async {
    await clearDirectory(await getApplicationSupportDirectory());
  }

  /// 删除目录下的全部条目；单条失败（如文件被其他进程占用）只记录日志，
  /// 不中断其余条目的清理。
  static Future<void> clearDirectory(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      try {
        await entity.delete(recursive: true);
      } catch (error) {
        debugPrint('Failed to delete ${entity.path}: $error');
      }
    }
  }
}
