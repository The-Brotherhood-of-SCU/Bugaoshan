import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/background_crop.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/common/background_image_view.dart';

/// 背景图裁剪/显示区域编辑器。
///
/// 编辑区与课程页共用 [BackgroundImageView] 和同一套
/// [BackgroundCropParams.resolveLayout] 渲染数学，实时预览即最终效果。
/// 支持拖动调整可见区域、双指/滚轮缩放、恢复默认；点保存后把参数写入
/// [AppConfigProvider.backgroundImageCrop]（null = 恢复 BoxFit.cover 旧行为）。
class BackgroundCropEditorPage extends StatefulWidget {
  const BackgroundCropEditorPage({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<BackgroundCropEditorPage> createState() =>
      _BackgroundCropEditorPageState();
}

class _BackgroundCropEditorPageState extends State<BackgroundCropEditorPage> {
  final AppConfigProvider _appConfig = getIt<AppConfigProvider>();

  double _zoom = BackgroundCropParams.minZoom;
  double _focusX = BackgroundCropParams.defaultFocus;
  double _focusY = BackgroundCropParams.defaultFocus;

  Size? _imageSize;
  Size _containerSize = Size.zero;

  /// GestureDetector.onScaleUpdate 的 scale 是相对手势开始时的累计值，
  /// 记录上一事件的累计值以换算单次事件的增量缩放比。
  double _lastEventScale = 1.0;

  @override
  void initState() {
    super.initState();
    final saved = _appConfig.backgroundImageCrop.value;
    if (saved != null) {
      _zoom = saved.zoom;
      _focusX = saved.focusX;
      _focusY = saved.focusY;
    }
  }

  BackgroundCropParams get _params =>
      BackgroundCropParams(focusX: _focusX, focusY: _focusY, zoom: _zoom);

  void _onImageSize(Size size) {
    _imageSize = size;
  }

  void _reset() {
    setState(() {
      _zoom = BackgroundCropParams.minZoom;
      _focusX = BackgroundCropParams.defaultFocus;
      _focusY = BackgroundCropParams.defaultFocus;
    });
  }

  void _save() {
    _appConfig.backgroundImageCrop.value = _params.isCover ? null : _params;
    Navigator.of(context).pop();
  }

  /// 以 [focal]（编辑区局部坐标）为不动点缩放 ratio 倍：
  /// 保持焦点下的图片坐标缩放前后落在同一点。
  void _zoomAtPoint(double ratio, Offset focal) {
    final imageSize = _imageSize;
    if (imageSize == null || _containerSize.isEmpty) return;
    if (ratio <= 0 || ratio == 1.0) return;

    final oldZoom = _zoom;
    final oldScaledWidth = _scaledWidth(imageSize, oldZoom);
    final oldScaledHeight = _scaledHeight(imageSize, oldZoom);

    // 缩放前焦点下的图片归一化坐标。
    final imageX =
        _focusX + (focal.dx - _containerSize.width / 2) / oldScaledWidth;
    final imageY =
        _focusY + (focal.dy - _containerSize.height / 2) / oldScaledHeight;

    final newZoom = (_zoom * ratio).clamp(
      BackgroundCropParams.minZoom,
      BackgroundCropParams.maxZoom,
    );
    if (newZoom == oldZoom) return;

    final newScaledWidth = _scaledWidth(imageSize, newZoom);
    final newScaledHeight = _scaledHeight(imageSize, newZoom);

    setState(() {
      _zoom = newZoom;
      _focusX = imageX - (focal.dx - _containerSize.width / 2) / newScaledWidth;
      _focusY =
          imageY - (focal.dy - _containerSize.height / 2) / newScaledHeight;
      _clampFocus();
    });
  }

  void _panBy(Offset focalDelta) {
    final imageSize = _imageSize;
    if (imageSize == null || _containerSize.isEmpty) return;
    if (focalDelta == Offset.zero) return;
    setState(() {
      _focusX -= focalDelta.dx / _scaledWidth(imageSize, _zoom);
      _focusY -= focalDelta.dy / _scaledHeight(imageSize, _zoom);
      _clampFocus();
    });
  }

  double _scaledWidth(Size imageSize, double zoom) =>
      imageSize.width * _baseCoverScale(zoom);

  double _scaledHeight(Size imageSize, double zoom) =>
      imageSize.height * _baseCoverScale(zoom);

  double _baseCoverScale(double zoom) {
    final imageSize = _imageSize!;
    return math.max(
          _containerSize.width / imageSize.width,
          _containerSize.height / imageSize.height,
        ) *
        zoom;
  }

  void _clampFocus() {
    final imageSize = _imageSize;
    if (imageSize == null) return;
    final clamped = BackgroundCropParams.clampFocus(
      _focusX,
      _focusY,
      imageWidth: imageSize.width,
      imageHeight: imageSize.height,
      containerWidth: _containerSize.width,
      containerHeight: _containerSize.height,
      zoom: _zoom,
    );
    _focusX = clamped.dx;
    _focusY = clamped.dy;
  }

  void _onScaleStart(ScaleStartDetails details) {
    // onScaleUpdate 的 scale 相对手势开始累计，开始时恒为 1。
    _lastEventScale = 1.0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // 先应用拖动，再以当前焦点为不动点应用增量缩放。
    _panBy(details.focalPointDelta);
    if (details.scale > 0 && _lastEventScale > 0) {
      _zoomAtPoint(details.scale / _lastEventScale, details.localFocalPoint);
      _lastEventScale = details.scale;
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (event.scrollDelta.dy == 0) return;
    // 滚轮向上（dy<0）放大，向下缩小；一个刻度约 ±20% 。
    final ratio = math.pow(math.e, -event.scrollDelta.dy * 0.002).toDouble();
    _zoomAtPoint(ratio, event.localPosition);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editBackgroundArea),
        actions: [
          IconButton(
            tooltip: l10n.resetToDefault,
            icon: const Icon(Icons.restart_alt),
            onPressed: _reset,
          ),
          IconButton(
            tooltip: l10n.save,
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _containerSize = constraints.biggest;
                return Listener(
                  onPointerSignal: _onPointerSignal,
                  child: GestureDetector(
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    // scale 手势（拖动+捏合）注册后会在手势竞技场中胜出，
                    // 不会误触页面级返回手势。
                    behavior: HitTestBehavior.opaque,
                    child: BackgroundImageView(
                      path: widget.imagePath,
                      crop: _params,
                      overlayOpacity: _appConfig.backgroundImageOpacity.value,
                      onImageSize: _onImageSize,
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.cropEditorHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '${(_zoom * 100).round()}%',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
