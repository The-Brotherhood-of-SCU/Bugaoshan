import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/utils/app_shapes.dart';

/// 下载进度状态
class UpdateProgressState extends ChangeNotifier {
  String _status = 'Downloading...';
  int _received = 0;
  int _total = 0;

  String get status => _status;
  int get received => _received;
  int get total => _total;
  int get percent => _total > 0 ? ((_received / _total) * 100).toInt() : 0;

  void setStatus(String status) {
    _status = status;
    notifyListeners();
  }

  void setProgress(int received, int total) {
    _received = received;
    _total = total;
    notifyListeners();
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String proxyDownloadUrl(String url) => 'https://gh-proxy.org/$url';

/// 纯 UI 视图,只渲染下载进度;便于在 widget test 中独立挂载验证。
///
/// 业务逻辑(状态更新、下载请求、错误处理)保留在 [showDownloadProgressDialog] 中。
class DownloadProgressDialogView extends StatelessWidget {
  const DownloadProgressDialogView({
    super.key,
    required this.progressState,
    required this.onDownloadInBackground,
    required this.onCancel,
    required this.l10n,
  });

  final UpdateProgressState progressState;
  final VoidCallback onDownloadInBackground;
  final VoidCallback onCancel;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _maxContentWidth(screenWidth)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度相关(status / percent / 进度条 / 文件大小)随 progressState 重建
              ListenableBuilder(
                listenable: progressState,
                builder: _buildProgressSection,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  /// Dialog 内容区的最大宽度:窄屏占 70%,宽屏上限 400。
  double _maxContentWidth(double screenWidth) =>
      screenWidth * 0.7 > 400 ? 400 : screenWidth * 0.7;

  /// 状态文字 + 百分比。窄屏英文长 status 时通过 Wrap 自然换行,不被截断。
  /// alignment: end 让所有子项都靠右(短 status 也靠右),整体视觉一致。
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: 8,
      children: [
        Text(
          progressState.status,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          '${progressState.percent}%',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  /// 进度条:total == 0 时为 indeterminate(由 LinearProgressIndicator 自动动画)。
  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppShapes.small),
      child: LinearProgressIndicator(
        value: progressState.total > 0
            ? progressState.received / progressState.total
            : null,
        minHeight: 8,
      ),
    );
  }

  /// 已接收到 total 时才显示 "已下载 / 总大小"。
  Widget _buildFileSizeLabel(BuildContext context) {
    return Text(
      '${_formatBytes(progressState.received)} / ${progressState.total == 0 ? l10n.loading : _formatBytes(progressState.total)}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// 进度区组合:头部 + 进度条 + 文件大小。
  Widget _buildProgressSection(BuildContext context, Widget? _) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        _buildHeader(context),
        const SizedBox(height: 16),
        _buildProgressBar(),
        const SizedBox(height: 8),
        _buildFileSizeLabel(context),
      ],
    );
  }

  /// 底部按钮区:窄屏下 Wrap 允许换行,保持右对齐。
  Widget _buildActionButtons() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 4,
        children: [
          TextButton(
            onPressed: onDownloadInBackground,
            child: Text(l10n.downloadInBackground),
          ),
          TextButton(onPressed: onCancel, child: Text(l10n.cancel)),
        ],
      ),
    );
  }
}

/// 显示下载进度弹窗并执行下载
///
/// 返回 true 表示下载成功，false 表示取消或失败
Future<bool> showDownloadProgressDialog({
  required BuildContext context,
  required String version,
  required String downloadUrl,
  String? checksumSha256,
  required UpdateService updateService,
}) async {
  final l10n = AppLocalizations.of(context)!;
  downloadUrl = proxyDownloadUrl(downloadUrl);
  final progressState = UpdateProgressState();
  final cancelToken = CancelToken();
  var visible = true;

  showDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (dialogContext) => DownloadProgressDialogView(
      progressState: progressState,
      l10n: l10n,
      onDownloadInBackground: () {
        visible = false;
        Navigator.of(dialogContext).pop();
      },
      onCancel: () {
        cancelToken.cancel();
        Navigator.of(dialogContext).pop();
      },
    ),
  );

  try {
    await updateService.downloadAndInstall(
      version,
      downloadUrl,
      checksumSha256: checksumSha256,
      cancelToken: cancelToken,
      onStatus: (status) => progressState.setStatus(status),
      onProgress: (received, total) =>
          progressState.setProgress(received, total),
    );
  } on UpdateCancelledException {
    return false;
  } catch (e) {
    if (context.mounted && visible) {
      Navigator.of(context, rootNavigator: true).maybePop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.updateFailed}: $e')));
    }
    return false;
  }

  if (context.mounted && visible) {
    Navigator.of(context, rootNavigator: true).maybePop();
  }
  return true;
}
