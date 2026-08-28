import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bugaoshan/models/background_image_crop.dart';

/// 在指定容器内按 [BackgroundImageCrop] 参数渲染背景图。
///
/// 同时被课程页（[CoursePage]）与背景图裁剪编辑器使用，保证两者渲染逻辑
/// 完全一致（预览即所得）。
///
/// - [imagePath] 为空时返回空组件。
/// - [crop] 为 `null` 时退化为 `BoxFit.cover` 居中（向后兼容旧用户）。
/// - 通过 [Transform.scale]（以焦点为锚点）实现放大、[ClipRect] 裁掉溢出，
///   与 [computeCropRect] 的几何语义一致。
class BackgroundImageWidget extends StatelessWidget {
  const BackgroundImageWidget({
    super.key,
    required this.imagePath,
    this.crop,
    this.opacity = 1.0,
    this.fit = BoxFit.cover,
  });

  final String? imagePath;
  final BackgroundImageCrop? crop;
  final double opacity;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path == null || path.isEmpty) {
      return const SizedBox.shrink();
    }

    final useCrop = crop != null && !crop!.isCentered;
    final alignment = useCrop
        ? Alignment(crop!.focusX, crop!.focusY)
        : Alignment.center;

    final image = Image(
      image: FileImage(File(path)),
      fit: fit,
      alignment: alignment,
      color: Colors.white.withAlpha(((1.0 - opacity) * 255).round()),
      colorBlendMode: BlendMode.modulate,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );

    if (!useCrop) {
      return Positioned.fill(child: image);
    }

    return Positioned.fill(
      child: ClipRect(
        child: Transform.scale(
          scale: crop!.scale,
          alignment: alignment,
          child: SizedBox.expand(child: image),
        ),
      ),
    );
  }
}
