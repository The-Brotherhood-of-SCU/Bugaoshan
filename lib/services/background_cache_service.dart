import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

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
        onError: (_, _) => _cleanup(),
      );
      _bgImageStream?.addListener(_bgImageListener!);
    } catch (_) {
      // ignore precache/resolve errors
    }
  }

  void _cleanup() {
    try {
      _bgImageStream?.removeListener(_bgImageListener!);
    } catch (e) {
      debugPrint('BackgroundCacheService._cleanup error: $e');
    }
    _bgImageStream = null;
    _bgImageListener = null;
  }

  void dispose() {
    _cleanup();
  }
}
