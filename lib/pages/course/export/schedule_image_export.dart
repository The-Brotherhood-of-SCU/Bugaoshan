import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/share_utils.dart';
import 'schedule_export_view.dart';
import 'schedule_image_renderer.dart';

// 数据模型 / DPR / 渲染器定义在 schedule_image_renderer.dart，
// 这里统一 re-export，保持既有 import 入口不变（仓库 barrel 约定）。
export 'schedule_image_renderer.dart';

/// 课表导出图片的输出层：三项动作 Sheet、相册保存、系统分享与完整交互流程。
///
/// 渲染层见 [schedule_image_renderer.dart]（本文件 re-export 其全部公共符号）。

/// 导出操作菜单选项。
enum ScheduleImageAction { saveToGallery, share, cancel }

/// 弹出课表导出操作菜单底栏（恰好 3 个 ListTile）。
Future<ScheduleImageAction?> showScheduleImageActionSheet(
  BuildContext context,
  AppLocalizations l10n,
) {
  return showModalBottomSheet<ScheduleImageAction>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.saveScheduleImageToGallery),
            onTap: () =>
                Navigator.of(ctx).pop(ScheduleImageAction.saveToGallery),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(l10n.shareScheduleImage),
            onTap: () => Navigator.of(ctx).pop(ScheduleImageAction.share),
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: Text(l10n.cancel),
            onTap: () => Navigator.of(ctx).pop(ScheduleImageAction.cancel),
          ),
        ],
      ),
    ),
  );
}

/// 输出执行状态。
enum ScheduleImageOutputStatus { success, canceled, permissionDenied, failed }

/// 保存课表图片到系统相册。
Future<ScheduleImageOutputStatus> saveScheduleImageToGallery({
  required BuildContext context,
  required AppLocalizations l10n,
  required ScheduleImageArtifact artifact,
}) async {
  try {
    final granted = await Gal.requestAccess();
    if (!granted) {
      AppLog.w('ScheduleImageExport', 'Gallery access denied by user');
      return ScheduleImageOutputStatus.permissionDenied;
    }
    await Gal.putImageBytes(artifact.pngBytes, name: artifact.baseName);
    return ScheduleImageOutputStatus.success;
  } on GalException catch (e) {
    AppLog.w('ScheduleImageExport', 'GalException while saving image: $e');
    if (e.type == GalExceptionType.accessDenied) {
      return ScheduleImageOutputStatus.permissionDenied;
    }
    return ScheduleImageOutputStatus.failed;
  } catch (e, stack) {
    AppLog.e(
      'ScheduleImageExport',
      'Failed to save image to gallery: $e\n$stack',
    );
    return ScheduleImageOutputStatus.failed;
  }
}

/// 将课表图片字节写出到系统临时目录（以 .png 结尾，且分享返回后不删除）。
@visibleForTesting
Future<File> writeScheduleImageTempFile(ScheduleImageArtifact artifact) async {
  final tempDir = await getTemporaryDirectory();
  final fileName =
      '${artifact.baseName}_${DateTime.now().millisecondsSinceEpoch}.png';
  final file = File('${tempDir.path}/$fileName');
  // 异步写：PNG 约 1–2MB，同步写会阻塞 UI 线程（分享前可能出现掉帧）。
  await file.writeAsBytes(artifact.pngBytes, flush: true);
  return file;
}

/// 分享课表图片。
Future<ScheduleImageOutputStatus> shareScheduleImage({
  required BuildContext context,
  required ScheduleImageArtifact artifact,
}) async {
  try {
    final file = await writeScheduleImageTempFile(artifact);
    if (!context.mounted) return ScheduleImageOutputStatus.canceled;
    await shareSingleFile(file.path, context: context);
    return ScheduleImageOutputStatus.success;
  } catch (e, stack) {
    AppLog.e('ScheduleImageExport', 'Failed to share image: $e\n$stack');
    return ScheduleImageOutputStatus.failed;
  }
}

/// 文件级防重入锁。
bool _isExporting = false;

/// 重置导出锁状态（仅供单元测试清理环境使用）。
@visibleForTesting
void resetScheduleImageExportStateForTesting() {
  _isExporting = false;
}

/// 输出分发签名：把「已生成的 PNG + 用户选择的动作」映射成输出状态。
///
/// 生产默认实现是 [dispatchScheduleImageOutput]。flow 测试可注入 fake，
/// 从而在不触发真实文件 IO 的前提下断言「只渲染一次 + 只分发一次」。
typedef ScheduleImageOutputDispatcher =
    Future<ScheduleImageOutputStatus> Function(
      BuildContext context,
      AppLocalizations l10n,
      ScheduleImageAction action,
      ScheduleImageArtifact artifact,
    );

/// 默认输出分发：相册 / 分享（取消不会走到这里）。
Future<ScheduleImageOutputStatus> dispatchScheduleImageOutput(
  BuildContext context,
  AppLocalizations l10n,
  ScheduleImageAction action,
  ScheduleImageArtifact artifact,
) {
  switch (action) {
    case ScheduleImageAction.saveToGallery:
      return saveScheduleImageToGallery(
        context: context,
        l10n: l10n,
        artifact: artifact,
      );
    case ScheduleImageAction.share:
      return shareScheduleImage(context: context, artifact: artifact);
    case ScheduleImageAction.cancel:
      return Future<ScheduleImageOutputStatus>.value(
        ScheduleImageOutputStatus.canceled,
      );
  }
}

/// 完整的课表图片导出交互流程。
///
/// 顺序固定为「先生成 PNG（加载页由渲染器内部显示/关闭）→ 再弹出三项动作」：
/// 需求规定 PNG 生成成功后才出现输出选择，生成失败时用户不应先做选择。
/// 两个输出动作只消费同一个 [ScheduleImageArtifact]，不会重新渲染。
Future<void> showScheduleImageExportFlow(
  BuildContext context, {
  required ScheduleExportData data,
  ScheduleImageRender render = renderScheduleImageArtifact,
  ScheduleImageOutputDispatcher output = dispatchScheduleImageOutput,
}) async {
  if (_isExporting) {
    AppLog.w('ScheduleImageExport', 'Export flow is already running, ignoring');
    return;
  }
  _isExporting = true;
  try {
    final l10n = AppLocalizations.of(context)!;
    if (!data.isValid) {
      AppLog.w(
        'ScheduleImageExport',
        'Invalid ScheduleExportData: courses=${data.courses.length}, targetWeek=${data.targetWeek}',
      );
      final message = data.courses.isEmpty
          ? l10n.exportScheduleAsImageEmpty
          : l10n.exportScheduleAsImageFailed;
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    // ① 先生成 PNG：加载页由渲染器内部显示，并在成功/失败两条路径上关闭。
    final ScheduleImageArtifact artifact;
    try {
      artifact = await render(context, data);
    } on ScheduleImageExportException catch (e) {
      AppLog.w(
        'ScheduleImageExport',
        'ScheduleImageExportException: ${e.type}',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportScheduleAsImageFailed)),
        );
      }
      return;
    } catch (e, stack) {
      AppLog.e('ScheduleImageExport', 'Render failed unexpectedly: $e\n$stack');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportScheduleAsImageFailed)),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // ② PNG 生成成功，才出现三项动作。
    final action = await showScheduleImageActionSheet(context, l10n);
    if (!context.mounted) return;

    if (action == null || action == ScheduleImageAction.cancel) {
      AppLog.i('ScheduleImageExport', 'Export flow cancelled by user');
      return;
    }

    // ③ 只消费同一个 artifact，不重新渲染。
    final status = await output(context, l10n, action, artifact);
    if (!context.mounted) return;

    switch (action) {
      case ScheduleImageAction.saveToGallery:
        switch (status) {
          case ScheduleImageOutputStatus.success:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.scheduleImageSavedToGallery)),
            );
          case ScheduleImageOutputStatus.permissionDenied:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.scheduleImageGalleryPermissionDenied),
              ),
            );
          case ScheduleImageOutputStatus.failed:
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.imageSaveFailed)));
          case ScheduleImageOutputStatus.canceled:
            break;
        }

      case ScheduleImageAction.share:
        switch (status) {
          case ScheduleImageOutputStatus.failed:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.scheduleImageShareFailed)),
            );
          case ScheduleImageOutputStatus.permissionDenied:
          case ScheduleImageOutputStatus.success:
          case ScheduleImageOutputStatus.canceled:
            break;
        }

      case ScheduleImageAction.cancel:
        break;
    }
  } finally {
    _isExporting = false;
  }
}
