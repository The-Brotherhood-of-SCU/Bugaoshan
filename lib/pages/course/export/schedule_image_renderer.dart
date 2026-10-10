import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'schedule_export_view.dart';

/// 课表导出图片的渲染层：数据模型、DPR 策略与「离屏挂载 + RepaintBoundary 捕获」。
///
/// 由 [schedule_image_export.dart] 以 barrel 方式 re-export，
/// 保持调用方（导出弹层、测试）的 import 入口不变。

/// 课表导出错误类型枚举。
///
/// 其中 [noSchedule] / [backgroundMissing] / [backgroundDecodeFailed] /
/// [fontLoadFailed] 当前**不会被抛出**：无课表在接线层提前返回，背景缺失、
/// 背景解码失败与字体超时都按「降级继续」处理（只写 AppLog.w）。保留这些取值
/// 是为了让「已识别的异常来源」与「实际致命路径」共用一套词汇表；改动前请先
/// 确认是否已经有真实的抛出点，不要假设它们会出现。
enum ScheduleImageErrorType {
  noSchedule,
  emptySchedule,
  invalidTargetWeek,
  backgroundMissing,
  backgroundDecodeFailed,
  fontLoadFailed,
  boundaryNotPainted,
  frameTimeout,
  captureFailed,
  emptyPngBytes,
}

/// 课表导出异常类。
class ScheduleImageExportException implements Exception {
  const ScheduleImageExportException(this.type, {this.cause});

  final ScheduleImageErrorType type;
  final Object? cause;

  @override
  String toString() =>
      'ScheduleImageExportException(type: $type, cause: $cause)';
}

/// 导出的课表图片产物。
@immutable
class ScheduleImageArtifact {
  const ScheduleImageArtifact({
    required this.pngBytes,
    required this.baseName,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.effectiveDpr,
  });

  final Uint8List pngBytes;
  final String baseName;
  final int pixelWidth;
  final int pixelHeight;
  final double effectiveDpr;

  String get suggestedFileName => '$baseName.png';
}

/// 生成课表图片基础文件名（不带扩展名）。
String scheduleImageBaseName(int week) => '课表_第$week周';

/// 生成课表图片完整文件名（带 .png 扩展名）。
String scheduleImageFileName(int week) => '${scheduleImageBaseName(week)}.png';

/// 当前平台是否支持课表图片导出。
bool get isScheduleImageExportSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// 根据逻辑尺寸与像素上限动态计算安全 DPR。
///
/// 契约公式：
/// area = logicalWidth * logicalHeight;
/// area * dpr^2 > maxPixels → sqrt(maxPixels / area);
/// 再 clamp(1.0, targetDpr)。
double resolveEffectiveDpr({
  required double logicalWidth,
  required double logicalHeight,
  double targetDpr = 2.0,
  int maxPixels = 8 * 1024 * 1024,
}) {
  final area = logicalWidth * logicalHeight;
  if (area <= 0) return 1.0;
  var dpr = targetDpr;
  if (area * dpr * dpr > maxPixels) {
    dpr = math.sqrt(maxPixels / area);
  }
  return dpr.clamp(1.0, targetDpr);
}

/// 渲染函数签名。
typedef ScheduleImageRender =
    Future<ScheduleImageArtifact> Function(
      BuildContext context,
      ScheduleExportData exportData,
    );

/// 离屏路由返回结果内部封装。
class _ScheduleImageRenderResult {
  const _ScheduleImageRenderResult.success(this.artifact)
    : error = null,
      stackTrace = null;

  const _ScheduleImageRenderResult.failure(this.error, [this.stackTrace])
    : artifact = null;

  final ScheduleImageArtifact? artifact;
  final Object? error;
  final StackTrace? stackTrace;
}

/// 渲染课表图片产物。
Future<ScheduleImageArtifact> renderScheduleImageArtifact(
  BuildContext context,
  ScheduleExportData exportData,
) async {
  if (!exportData.isValid) {
    if (exportData.courses.isEmpty) {
      throw const ScheduleImageExportException(
        ScheduleImageErrorType.emptySchedule,
      );
    }
    throw const ScheduleImageExportException(
      ScheduleImageErrorType.invalidTargetWeek,
    );
  }

  final theme = Theme.of(context);
  final l10n = AppLocalizations.of(context)!;

  final result = await showGeneralDialog<_ScheduleImageRenderResult?>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    transitionBuilder: (_, _, _, child) => child,
    useRootNavigator: true,
    pageBuilder: (dialogContext, _, _) {
      return _ScheduleImageExportDialog(
        exportData: exportData,
        theme: theme,
        l10n: l10n,
      );
    },
  );

  if (result == null) {
    throw const ScheduleImageExportException(
      ScheduleImageErrorType.captureFailed,
    );
  }
  if (result.error != null) {
    final error = result.error;
    if (error is ScheduleImageExportException) {
      throw error;
    }
    throw ScheduleImageExportException(
      ScheduleImageErrorType.captureFailed,
      cause: error,
    );
  }
  final artifact = result.artifact;
  if (artifact == null) {
    throw const ScheduleImageExportException(
      ScheduleImageErrorType.captureFailed,
    );
  }
  return artifact;
}

/// 宿主 StatefulWidget，字段必须命名 exportData。
class _ScheduleImageExportDialog extends StatefulWidget {
  const _ScheduleImageExportDialog({
    required this.exportData,
    required this.theme,
    required this.l10n,
  });

  final ScheduleExportData exportData;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  State<_ScheduleImageExportDialog> createState() =>
      _ScheduleImageExportDialogState();
}

class _ScheduleImageExportDialogState
    extends State<_ScheduleImageExportDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _ready = false;
  String? _effectiveBackgroundPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startWarmupAndRender();
      }
    });
  }

  Future<ByteData?> _encodePngAndDispose(ui.Image image) async {
    try {
      return await image.toByteData(format: ui.ImageByteFormat.png);
    } finally {
      image.dispose();
    }
  }

  Future<void> _startWarmupAndRender() async {
    try {
      final appConfig = getIt<AppConfigProvider>();
      if (appConfig.useGoogleFonts.value) {
        try {
          await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 3));
        } catch (e) {
          AppLog.w(
            'ScheduleImageExport',
            'GoogleFonts.pendingFonts timeout or failed: $e',
          );
        }
      }

      final rawPath = appConfig.backgroundImagePath.value;
      if (rawPath != null) {
        final file = File(rawPath);
        bool exists = false;
        try {
          exists = await file.exists();
        } catch (e) {
          AppLog.w(
            'ScheduleImageExport',
            'Check background file exists failed: $e',
          );
        }
        if (!exists) {
          AppLog.w(
            'ScheduleImageExport',
            'Background image file not found: $rawPath',
          );
          _effectiveBackgroundPath = null;
        } else {
          bool decodeFailed = false;
          try {
            if (mounted) {
              await precacheImage(
                FileImage(file),
                context,
                onError: (e, s) {
                  decodeFailed = true;
                  AppLog.w(
                    'ScheduleImageExport',
                    'Background image precache onError: $e',
                  );
                },
              );
            }
          } catch (e) {
            decodeFailed = true;
            AppLog.w(
              'ScheduleImageExport',
              'Background image precache threw: $e',
            );
          }
          if (!decodeFailed) {
            _effectiveBackgroundPath = rawPath;
          } else {
            _effectiveBackgroundPath = null;
          }
        }
      } else {
        _effectiveBackgroundPath = null;
      }

      if (!mounted) return;
      setState(() {
        _ready = true;
      });

      try {
        await WidgetsBinding.instance.endOfFrame.timeout(
          const Duration(seconds: 8),
        );
      } catch (e) {
        throw ScheduleImageExportException(
          ScheduleImageErrorType.frameTimeout,
          cause: e,
        );
      }

      if (!mounted) return;

      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      // 读取 @protected 的 RenderObject.layer 仅作「至少已合成过一次」的非空守卫，
      // 避免 toImage 内部 `layer! as OffsetLayer` 直接抛错；它并不代表最新一帧已 paint
      //（release 下没有等价检查，新鲜度由上面的预热顺序 + endOfFrame 结构性保证）。
      // ignore: invalid_use_of_protected_member
      if (boundary == null || boundary.layer == null) {
        throw const ScheduleImageExportException(
          ScheduleImageErrorType.boundaryNotPainted,
        );
      }

      assert(!boundary.debugNeedsPaint, '导出边界在捕获前仍需 paint');

      final size = boundary.size;
      final dpr = resolveEffectiveDpr(
        logicalWidth: size.width,
        logicalHeight: size.height,
      );

      final ui.Image image;
      try {
        image = await boundary.toImage(pixelRatio: dpr);
      } catch (e) {
        throw ScheduleImageExportException(
          ScheduleImageErrorType.captureFailed,
          cause: e,
        );
      }

      final pixelWidth = image.width;
      final pixelHeight = image.height;

      final ByteData? byteData;
      try {
        byteData = await _encodePngAndDispose(image);
      } catch (e) {
        throw ScheduleImageExportException(
          ScheduleImageErrorType.captureFailed,
          cause: e,
        );
      }

      if (byteData == null) {
        throw const ScheduleImageExportException(
          ScheduleImageErrorType.emptyPngBytes,
        );
      }

      final pngBytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      final baseName = scheduleImageBaseName(widget.exportData.targetWeek);
      final artifact = ScheduleImageArtifact(
        pngBytes: pngBytes,
        baseName: baseName,
        pixelWidth: pixelWidth,
        pixelHeight: pixelHeight,
        effectiveDpr: dpr,
      );

      // 真机核验「PNG 只生成一次」的可观测证据：每次导出只应出现一条。
      AppLog.i(
        'ScheduleImageExport',
        'rendered ${artifact.pixelWidth}x${artifact.pixelHeight} '
            'dpr=${artifact.effectiveDpr.toStringAsFixed(2)} '
            'bytes=${artifact.pngBytes.length} '
            'week=${widget.exportData.targetWeek}',
      );

      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(_ScheduleImageRenderResult.success(artifact));
      }
    } catch (e, stack) {
      AppLog.e('ScheduleImageExport', 'Warmup/Render error: $e\n$stack');
      if (mounted) {
        final exportException = e is ScheduleImageExportException
            ? e
            : ScheduleImageExportException(
                ScheduleImageErrorType.captureFailed,
                cause: e,
              );
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(_ScheduleImageRenderResult.failure(exportException, stack));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: widget.theme.colorScheme.surface,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topLeft,
          children: [
            if (_ready)
              Positioned(
                left: 0,
                top: 0,
                width: kScheduleImageLogicalWidth,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: ScheduleExportView(
                        data: widget.exportData,
                        backgroundImagePath: _effectiveBackgroundPath,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: ColoredBox(
                color: widget.theme.colorScheme.surface,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(widget.l10n.generatingScheduleImage),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
