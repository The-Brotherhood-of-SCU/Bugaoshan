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

/// 显示下载进度弹窗并执行下载
///
/// 返回 true 表示下载成功，false 表示取消或失败
Future<bool> showDownloadProgressDialog({
  required BuildContext context,
  required String version,
  required String downloadUrl,
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
    builder: (dialogContext) {
      final screenWidth = MediaQuery.of(dialogContext).size.width;
      return Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth * 0.7 > 400 ? 400 : screenWidth * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListenableBuilder(
                  listenable: progressState,
                  builder: (context, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 状态文字 + 百分比
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              progressState.status,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            '${progressState.percent}%',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 进度条
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppShapes.small),
                        child: LinearProgressIndicator(
                          value: progressState.total > 0
                              ? progressState.received / progressState.total
                              : null,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 文件大小
                      if (progressState.total > 0)
                        Text(
                          '${_formatBytes(progressState.received)} / ${_formatBytes(progressState.total)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                // 操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        visible = false;
                        Navigator.of(dialogContext).pop();
                      },
                      child: Text(l10n.downloadInBackground),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        cancelToken.cancel();
                        Navigator.of(dialogContext).pop();
                      },
                      child: Text(l10n.cancel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  try {
    await updateService.downloadAndInstall(
      version,
      downloadUrl,
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
