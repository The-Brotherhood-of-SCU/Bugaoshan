import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:bugaoshan/utils/app_log.dart';

class BackgroundCacheService {
  static const String _tag = 'BackgroundCacheService';

  final String? Function() _getBackgroundImagePath;

  ImageStream? _bgImageStream;
  ImageStreamListener? _bgImageListener;

  BackgroundCacheService({required String? Function() getBackgroundImagePath})
      : _getBackgroundImagePath = getBackgroundImagePath;

  /// 预加载背景图片到 ImageCache。
  void precache() {
    final path = _getBackgroundImagePath();
    if (path == null) return;
    try {
      final file = File(path);
      final provider = FileImage(file);

      _bgImageStream = provider.resolve(ImageConfiguration.empty);
      _bgImageListener = ImageStreamListener(
        (_, _) => _cleanup(),
        onError: (error, stackTrace) {
          AppLog.e(_tag, '背景图片预加载失败', error: error, stackTrace: stackTrace);
          _cleanup();
        },
      );
      _bgImageStream?.addListener(_bgImageListener!);
    } catch (logError, logStackTrace) {
      AppLog.e(_tag, 'precache 失败', error: logError, stackTrace: logStackTrace);
      // ignore precache/resolve errors
    }
  }

  void _cleanup() {
    try {
      _bgImageStream?.removeListener(_bgImageListener!);
    } catch (e, logStackTrace) {
      AppLog.e(_tag, '_cleanup 失败', error: e, stackTrace: logStackTrace);
    }
    _bgImageStream = null;
    _bgImageListener = null;
  }

  void dispose() {
    _cleanup();
  }
}
