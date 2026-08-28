import 'dart:math';
import 'dart:ui';

/// 背景图裁剪参数。
///
/// 采用归一化的「焦点位置 + 缩放」表示（而非破坏性裁剪后的图片），
/// 这样能保留原图、避免重复压缩，并能在不同尺寸的课表容器上重新计算
/// 显示区域（手机 / 平板 / 桌面窗口比例不一致时仍可用同一组参数）。
///
/// - [scale]：相对 `BoxFit.cover` 基准的额外放大倍数，必须 >= 1。
///   1 表示不放大（等同于 cover 居中）。
/// - [focusX] / [focusY]：焦点偏移，范围 [-1, 1]。0 表示居中；
///   正值向右 / 下偏移，负值向左 / 上偏移。
///
/// 当该参数为 `null`（旧用户未设置）时，沿用当前的 `BoxFit.cover` 居中行为，
/// 保证向后兼容。
class BackgroundImageCrop {
  const BackgroundImageCrop({
    this.scale = 1.0,
    this.focusX = 0.0,
    this.focusY = 0.0,
  })  : assert(scale >= 1.0, 'scale must be >= 1.0'),
        assert(focusX >= -1.0 && focusX <= 1.0, 'focusX must be in [-1, 1]'),
        assert(focusY >= -1.0 && focusY <= 1.0, 'focusY must be in [-1, 1]');

  /// 默认（未裁剪）参数：等同于 `BoxFit.cover` 居中。
  static const BackgroundImageCrop centered = BackgroundImageCrop(
    scale: 1.0,
    focusX: 0.0,
    focusY: 0.0,
  );

  final double scale;
  final double focusX;
  final double focusY;

  bool get isCentered =>
      scale <= 1.0 + 1e-6 && focusX.abs() < 1e-6 && focusY.abs() < 1e-6;

  BackgroundImageCrop copyWith({
    double? scale,
    double? focusX,
    double? focusY,
  }) {
    return BackgroundImageCrop(
      scale: scale ?? this.scale,
      focusX: focusX ?? this.focusX,
      focusY: focusY ?? this.focusY,
    );
  }

  Map<String, double> toJson() => {
        'scale': scale,
        'focusX': focusX,
        'focusY': focusY,
      };

  factory BackgroundImageCrop.fromJson(Map<String, dynamic> json) {
    final scale = (json['scale'] as num?)?.toDouble() ?? 1.0;
    final focusX = (json['focusX'] as num?)?.toDouble() ?? 0.0;
    final focusY = (json['focusY'] as num?)?.toDouble() ?? 0.0;
    return BackgroundImageCrop(
      scale: scale.clamp(1.0, 8.0),
      focusX: focusX.clamp(-1.0, 1.0),
      focusY: focusY.clamp(-1.0, 1.0),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackgroundImageCrop &&
          scale == other.scale &&
          focusX == other.focusX &&
          focusY == other.focusY;

  @override
  int get hashCode =>
      scale.hashCode ^ focusX.hashCode ^ focusY.hashCode;
}

/// 把裁剪参数换算成图片在容器坐标系中应绘制的矩形。
///
/// 纯函数，便于单元测试；渲染层与裁剪编辑器共用，保证「预览即所得」。
///
/// 算法：先按 `BoxFit.cover` 计算图片在容器内的最小填满尺寸，再按
/// [BackgroundImageCrop.scale] 放大（围绕焦点），最后按焦点偏移求出
/// top-left。返回的矩形可能超出容器边界，调用方需用 `ClipRect` 裁掉。
Rect computeCropRect({
  required Size container,
  required Size image,
  required BackgroundImageCrop crop,
}) {
  assert(container.width > 0 && container.height > 0,
      'container must have positive size');
  assert(image.width > 0 && image.height > 0, 'image must have positive size');

  final cw = container.width;
  final ch = container.height;

  // BoxFit.cover: 填满容器所需的最小显示尺寸。
  final coverScale = max(cw / image.width, ch / image.height);
  var dw = image.width * coverScale;
  var dh = image.height * coverScale;

  // 围绕焦点放大（与 Transform.scale(alignment: focus) 语义一致）。
  dw *= crop.scale;
  dh *= crop.scale;

  // 焦点对齐：focusX = -1 → 左对齐(图片左缘贴容器左缘)；
  // focusX = 1 → 右对齐；0 → 居中。
  // 居中时偏移 = (容器 - 图片)/2；焦点偏移线性映射。
  final offsetX = (cw - dw) / 2 - crop.focusX * (cw - dw) / 2;
  final offsetY = (ch - dh) / 2 - crop.focusY * (ch - dh) / 2;

  return Rect.fromLTWH(offsetX, offsetY, dw, dh);
}
