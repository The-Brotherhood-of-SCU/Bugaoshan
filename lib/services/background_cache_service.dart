import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/app_log.dart';

class BackgroundCacheService {
  final AppConfigProvider _appConfig;

  ImageStream? _bgImageStream;
  ImageStreamListener? _bgImageListener;

  BackgroundCacheService(this._appConfig);

  /// 预加载背景图片到 ImageCache。
  void precache() {
    final path = _appConfig.backgroundImagePath.value;
    if (path == null) return;
    try {
      final file = File(path);
      final provider = FileImage(file);

      _bgImageStream = provider.resolve(ImageConfiguration.empty);
      _bgImageListener = ImageStreamListener(
        (_, _) => _cleanup(),
        onError: (error, stackTrace) {
          AppLog.e(
            'BackgroundCacheService',
            '背景图片预加载失败',
            error: error,
            stackTrace: stackTrace,
          );
          _cleanup();
        },
      );
      _bgImageStream?.addListener(_bgImageListener!);
    } catch (logError, logStackTrace) {
      AppLog.e(
        'BackgroundCacheService',
        'precache 失败',
        error: logError,
        stackTrace: logStackTrace,
      );
      // ignore precache/resolve errors
    }
  }

  void _cleanup() {
    try {
      _bgImageStream?.removeListener(_bgImageListener!);
    } catch (e, logStackTrace) {
      AppLog.e(
        'BackgroundCacheService',
        '_cleanup 失败',
        error: e,
        stackTrace: logStackTrace,
      );
    }
    _bgImageStream = null;
    _bgImageListener = null;
  }

  void dispose() {
    _cleanup();
  }
}
