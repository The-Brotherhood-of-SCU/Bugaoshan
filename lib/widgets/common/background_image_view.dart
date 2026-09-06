import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bugaoshan/models/background_crop.dart';

/// 课程页背景图渲染组件：按 [crop] 裁剪参数把原图缩放/平移进容器，超出部分裁掉。
///
/// [crop] 为 null（或等于默认值）时走 `fit: BoxFit.cover` 分支，与旧版渲染
/// 完全一致，保证旧用户没有裁剪参数时背景显示不发生变化。
///
/// 图片尺寸通过 ImageStream 获取后用 [BackgroundCropParams.resolveLayout]
/// 计算布局 —— 课程页与裁剪编辑器共用同一套渲染数学，保证预览与实际一致。
/// 图片仍由 FileImage 驱动，GIF 动画、淡入与图片缓存行为不受影响。
class BackgroundImageView extends StatefulWidget {
  const BackgroundImageView({
    super.key,
    required this.path,
    required this.overlayOpacity,
    this.crop,
    this.onImageSize,
  });

  final String path;

  /// 白色叠加不透明度（对应原 Image color + BlendMode.modulate 行为）。
  final double overlayOpacity;

  final BackgroundCropParams? crop;

  /// 首帧解码后的图片像素尺寸回调（裁剪编辑器做手势换算用）。
  final ValueChanged<Size>? onImageSize;

  @override
  State<BackgroundImageView> createState() => _BackgroundImageViewState();
}

class _BackgroundImageViewState extends State<BackgroundImageView> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;

  bool get _hasCustomCrop => widget.crop != null && !widget.crop!.isCover;

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
  }

  @override
  void didUpdateWidget(covariant BackgroundImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _imageSize = null;
      _resolveImageSize();
    }
  }

  /// 监听同一个 FileImage 缓存条目拿到图片尺寸；Image widget 内部的解析
  /// 与这里共享 ImageCache，不产生二次解码。
  void _resolveImageSize() {
    _removeListener();
    try {
      final stream = FileImage(
        File(widget.path),
      ).resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (info, _) {
          if (!mounted) return;
          final size = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
          if (size != _imageSize) {
            setState(() => _imageSize = size);
            widget.onImageSize?.call(size);
          }
        },
        onError: (_, _) {
          // 解码失败保持空显示，与 Image.errorBuilder 行为一致。
          _removeListener();
        },
      );
      _stream = stream;
      _listener = listener;
      stream.addListener(listener);
    } catch (_) {
      // 文件不存在等同步异常：保持空显示。
    }
  }

  void _removeListener() {
    try {
      _stream?.removeListener(_listener!);
    } catch (_) {}
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = _imageSize;
    if (imageSize == null || imageSize.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final container = constraints.biggest;
        if (container.isEmpty) return const SizedBox.shrink();
        return _hasCustomCrop
            ? _buildCroppedImage(imageSize, container)
            : _buildImage(fit: BoxFit.cover);
      },
    );
  }

  /// 按裁剪参数摆放缩放后的图片；Stack 默认 hardEdge 裁剪超出部分。
  Widget _buildCroppedImage(Size imageSize, Size container) {
    final layout = BackgroundCropParams.resolveLayout(
      imageWidth: imageSize.width,
      imageHeight: imageSize.height,
      containerWidth: container.width,
      containerHeight: container.height,
      params: widget.crop!,
    );
    return ClipRect(
      child: Stack(
        children: [
          Positioned(
            left: layout.left,
            top: layout.top,
            width: layout.scaledWidth,
            height: layout.scaledHeight,
            child: _buildImage(fit: BoxFit.fill),
          ),
        ],
      ),
    );
  }

  Widget _buildImage({required BoxFit fit}) {
    return Image(
      image: FileImage(File(widget.path)),
      fit: fit,
      // 使用 frameBuilder 监听第一帧完成并做淡入动画，避免白屏突变
      frameBuilder: (BuildContext ctx, Widget child, int? frame, bool wasSync) {
        final visible = frame != null || wasSync;
        return AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: child,
        );
      },
      color: Colors.white.withAlpha(
        (widget.overlayOpacity.clamp(0.0, 1.0) * 255).round(),
      ),
      colorBlendMode: BlendMode.modulate,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
