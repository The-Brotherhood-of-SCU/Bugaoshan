import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

class BackgroundCacheService {
  final AppConfigProvider _appConfig;

  ImageStream? _bgImageStream;
  ImageStreamListener? _bgImageListener;

  BackgroundCacheService(this._appConfig);

  /// 预加载背景图片到 ImageCache，避免全分辨率大图占用内存。
  /// 需在 [MediaQuery] 可用后调用（如 [WidgetsBinding.instance.addPostFrameCallback]）。
  void precache(BuildContext context) {
    final path = _appConfig.backgroundImagePath.value;
    if (path == null) return;
    try {
      final file = File(path);
      final mq = MediaQuery.of(context);
      final dpr = mq.devicePixelRatio;
      final widthPx = (mq.size.width * dpr).round();
      final heightPx = (mq.size.height * dpr).round();

      final longSide = widthPx >= heightPx ? widthPx : heightPx;
      final provider = (widthPx >= heightPx)
          ? ResizeImage(FileImage(file), width: longSide)
          : ResizeImage(FileImage(file), height: longSide);

      _bgImageStream = provider.resolve(
        ImageConfiguration(devicePixelRatio: dpr),
      );
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
    } catch (_) {}
    _bgImageStream = null;
    _bgImageListener = null;
  }

  void dispose() {
    _cleanup();
  }
}
