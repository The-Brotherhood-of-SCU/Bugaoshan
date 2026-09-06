import 'dart:convert';
import 'dart:math';
import 'dart:ui' show Offset;

/// 背景图裁剪参数（归一化存储，与图片分辨率、课程页容器尺寸无关）。
///
/// - [focusX]/[focusY]：图片上最终显示在容器中心的归一化坐标（0..1）。
/// - [zoom]：相对 BoxFit.cover 基准缩放的倍数（>= [minZoom]）。
///
/// 全部取默认值时，渲染结果与 BoxFit.cover（居中裁剪）完全一致，
/// 因此旧用户没有裁剪参数（null）时背景显示不发生变化。
class BackgroundCropParams {
  /// 默认焦点：图片中心。
  static const double defaultFocus = 0.5;

  /// 最小缩放：等价于 BoxFit.cover。
  static const double minZoom = 1.0;

  /// 最大缩放，防止过度放大导致画质不可用。
  static const double maxZoom = 5.0;

  final double focusX;
  final double focusY;
  final double zoom;

  const BackgroundCropParams({
    this.focusX = defaultFocus,
    this.focusY = defaultFocus,
    this.zoom = minZoom,
  });

  /// 与 BoxFit.cover 等价的默认参数。
  static const BackgroundCropParams cover = BackgroundCropParams();

  bool get isCover =>
      focusX == defaultFocus && focusY == defaultFocus && zoom == minZoom;

  BackgroundCropParams copyWith({
    double? focusX,
    double? focusY,
    double? zoom,
  }) {
    return BackgroundCropParams(
      focusX: focusX ?? this.focusX,
      focusY: focusY ?? this.focusY,
      zoom: zoom ?? this.zoom,
    );
  }

  // ---- 序列化 ----

  Map<String, dynamic> toJson() => {
    'focusX': focusX,
    'focusY': focusY,
    'zoom': zoom,
  };

  String encode() => jsonEncode(toJson());

  /// 从持久化字符串恢复；字段缺失或类型非法时返回 null（回退 cover 行为），
  /// 数值越界则收敛到合法范围（容忍序列化浮点漂移）。
  static BackgroundCropParams? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final obj = jsonDecode(raw);
      if (obj is! Map<String, dynamic>) return null;
      final fx = (obj['focusX'] as num?)?.toDouble();
      final fy = (obj['focusY'] as num?)?.toDouble();
      final z = (obj['zoom'] as num?)?.toDouble();
      if (fx == null || fy == null || z == null) return null;
      return BackgroundCropParams(
        focusX: fx.clamp(0.0, 1.0),
        focusY: fy.clamp(0.0, 1.0),
        zoom: z.clamp(minZoom, maxZoom),
      );
    } catch (_) {
      return null;
    }
  }

  // ---- 渲染数学（课程页与裁剪编辑器共用，保证预览与实际一致） ----

  /// 计算在指定图片与容器尺寸下的最终布局。
  ///
  /// 返回的 [BackgroundCropLayout.left]/[top] 是缩放后图片相对容器左上角的
  /// 摆放位置（允许为负，超出部分由调用方 ClipRect 裁掉）。
  static BackgroundCropLayout resolveLayout({
    required double imageWidth,
    required double imageHeight,
    required double containerWidth,
    required double containerHeight,
    required BackgroundCropParams params,
  }) {
    final clampedFocus = clampFocus(
      params.focusX,
      params.focusY,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      containerWidth: containerWidth,
      containerHeight: containerHeight,
      zoom: params.zoom,
    );
    final scale =
        _baseCoverScale(
          imageWidth,
          imageHeight,
          containerWidth,
          containerHeight,
        ) *
        params.zoom;
    final scaledWidth = imageWidth * scale;
    final scaledHeight = imageHeight * scale;
    return BackgroundCropLayout(
      scaledWidth: scaledWidth,
      scaledHeight: scaledHeight,
      left:
          (containerWidth - scaledWidth) / 2 +
          (defaultFocus - clampedFocus.dx) * scaledWidth,
      top:
          (containerHeight - scaledHeight) / 2 +
          (defaultFocus - clampedFocus.dy) * scaledHeight,
    );
  }

  /// 将任意焦点收敛到「图片仍铺满容器」的合法范围。
  ///
  /// 焦点表示显示在容器中心的图片坐标，平移余量为
  /// `maxD = (scaled - container) / 2`，超出即露出容器边缘。
  static Offset clampFocus(
    double focusX,
    double focusY, {
    required double imageWidth,
    required double imageHeight,
    required double containerWidth,
    required double containerHeight,
    required double zoom,
  }) {
    final zoomed = max(zoom, minZoom);
    final scale =
        _baseCoverScale(
          imageWidth,
          imageHeight,
          containerWidth,
          containerHeight,
        ) *
        zoomed;
    final scaledWidth = imageWidth * scale;
    final scaledHeight = imageHeight * scale;
    final maxDx = max(0.0, (scaledWidth - containerWidth) / 2);
    final maxDy = max(0.0, (scaledHeight - containerHeight) / 2);
    final dx = ((defaultFocus - focusX) * scaledWidth).clamp(-maxDx, maxDx);
    final dy = ((defaultFocus - focusY) * scaledHeight).clamp(-maxDy, maxDy);
    return Offset(
      defaultFocus - dx / scaledWidth,
      defaultFocus - dy / scaledHeight,
    );
  }

  /// BoxFit.cover 的基准缩放：短边铺满、长边超出。
  static double _baseCoverScale(
    double imageWidth,
    double imageHeight,
    double containerWidth,
    double containerHeight,
  ) {
    return max(containerWidth / imageWidth, containerHeight / imageHeight);
  }

  // ---- 相等性 ----

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackgroundCropParams &&
          other.focusX == focusX &&
          other.focusY == focusY &&
          other.zoom == zoom;

  @override
  int get hashCode => Object.hash(focusX, focusY, zoom);
}

/// [BackgroundCropParams.resolveLayout] 的结果：缩放后图片的尺寸与摆放位置。
class BackgroundCropLayout {
  final double scaledWidth;
  final double scaledHeight;

  /// 缩放后图片相对容器左上角的位置（可为负）。
  final double left;
  final double top;

  const BackgroundCropLayout({
    required this.scaledWidth,
    required this.scaledHeight,
    required this.left,
    required this.top,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackgroundCropLayout &&
          other.scaledWidth == scaledWidth &&
          other.scaledHeight == scaledHeight &&
          other.left == left &&
          other.top == top;

  @override
  int get hashCode => Object.hash(scaledWidth, scaledHeight, left, top);
}
