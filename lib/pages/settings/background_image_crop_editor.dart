import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/background_image_crop.dart';
import 'package:bugaoshan/widgets/background_image_widget.dart';

/// 背景图裁剪 / 显示区域调整编辑器。
///
/// 用户可在裁剪框内拖动（调整焦点）、捏合或滚轮缩放（围绕焦点放大），
/// 编辑区本身即按 [BackgroundImageCrop] 参数实时渲染（与课程页使用同一
/// [BackgroundImageWidget]），保证「预览即所得」。
///
/// 返回 [BackgroundImageCrop] 表示保存；返回 `null` 表示取消。
class BackgroundImageCropEditor extends StatefulWidget {
  const BackgroundImageCropEditor({
    super.key,
    required this.imagePath,
    this.initialCrop,
  });

  final String imagePath;
  final BackgroundImageCrop? initialCrop;

  @override
  State<BackgroundImageCropEditor> createState() =>
      _BackgroundImageCropEditorState();
}

class _BackgroundImageCropEditorState extends State<BackgroundImageCropEditor> {
  late BackgroundImageCrop _crop;

  // 手势状态：记录缩放起始值。
  double _startScale = 1.0;

  @override
  void initState() {
    super.initState();
    _crop = widget.initialCrop ?? BackgroundImageCrop.centered;
  }

  void _save() => Navigator.of(context).pop<BackgroundImageCrop>(_crop);

  void _reset() => setState(() {
        _crop = BackgroundImageCrop.centered;
      });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.editBackgroundImageCrop),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: localizations.cancel,
          onPressed: () => Navigator.of(context).pop<BackgroundImageCrop>(),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.check),
            label: Text(localizations.save),
            onPressed: _save,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                // 裁剪框：编辑区即显示容器，所见即所得。
                child: AspectRatio(
                  aspectRatio: _previewAspectRatio(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withAlpha(120),
                        ),
                      ),
                      child: _buildInteractiveLayer(),
                    ),
                  ),
                ),
              ),
            ),
            _buildControls(context, localizations),
          ],
        ),
      ),
    );
  }

  /// 让编辑框比例接近课程页容器的常见比例（竖屏手机 ~ 9:16 偏宽）。
  /// 直接用可用宽度 / 预览高度即可；这里用 3:4 便于在多数屏幕看到完整框。
  double _previewAspectRatio(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // 竖屏：用 3:4；横屏/桌面：用 4:3，尽量贴近实际课表容器观感。
    final isPortrait = size.height >= size.width;
    return isPortrait ? 3 / 4 : 4 / 3;
  }

  Widget _buildInteractiveLayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth;
        final boxHeight = constraints.maxHeight;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              // 向下滚放大，向上滚缩小。
              final delta = signal.scrollDelta.dy;
              final next = (_crop.scale * (delta > 0 ? 1.1 : 0.9))
                  .clamp(1.0, 8.0);
              setState(() => _crop = _crop.copyWith(scale: next));
            }
          },
          child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (d) {
            _startScale = _crop.scale;
          },
          onScaleUpdate: (d) {
            // 平移：用双指/单指中点相对上一帧的位移，反向更新焦点。
            final dx = -d.focalPointDelta.dx / boxWidth * 2;
            final dy = -d.focalPointDelta.dy / boxHeight * 2;
            final scale = (d.scale == 1.0)
                ? _crop.scale // 纯平移（scale 识别器未放大）
                : (_startScale * d.scale).clamp(1.0, 8.0);
            setState(() {
              _crop = _crop.copyWith(
                scale: scale,
                focusX: (_crop.focusX + dx).clamp(-1.0, 1.0),
                focusY: (_crop.focusY + dy).clamp(-1.0, 1.0),
              );
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              BackgroundImageWidget(
                imagePath: widget.imagePath,
                crop: _crop,
                opacity: 1.0,
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildControls(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  localizations.zoom,
                ),
              ),
              Text('${_crop.scale.toStringAsFixed(2)}x'),
            ],
          ),
          Slider(
            value: _crop.scale,
            min: 1.0,
            max: 8.0,
            divisions: 70,
            onChanged: (v) => setState(() => _crop = _crop.copyWith(scale: v)),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.crop_free),
            label: Text(localizations.resetCrop),
            onPressed: _reset,
          ),
          const SizedBox(height: 8),
          Text(
            localizations.backgroundImageCropHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
