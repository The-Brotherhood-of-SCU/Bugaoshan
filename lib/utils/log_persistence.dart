import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/app_logger.dart';

const String _tag = 'LogPersistence';
const String kLogPersistenceEnabledKey = 'log_persistence_enabled';

bool readLogPersistenceEnabled(SharedPreferences preferences) =>
    preferences.getBool(kLogPersistenceEnabledKey) ?? true;

/// 在 DI 和应用界面装配前启用落盘，使后续启动失败也能留下记录。
/// 设置无法读取时仅保留内存日志，避免覆盖用户可能已保存的关闭意图。
Future<void> initializeLogPersistence({
  SharedPreferences? preferences,
  AppLogger? logger,
  String? overridePath,
}) async {
  if (kIsWeb) return;
  final log = logger ?? AppLog.bootstrapLogger;
  try {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    if (readLogPersistenceEnabled(prefs)) {
      await log.enableFileSink(
        overridePath: overridePath,
        includeBufferedEntries: true,
      );
    } else {
      await log.deletePersistedFiles(overridePath: overridePath);
    }
  } catch (error, stackTrace) {
    log.e(
      _tag,
      '初始化日志落盘失败',
      error: error,
      stackTrace: stackTrace,
      category: LogCategory.business,
    );
  }
}
