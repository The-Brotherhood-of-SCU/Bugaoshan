import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/services/download_manager.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'captcha_webview_page.dart';
import 'file_utils.dart';

/// Data for a single attachment item in the sheet.
class AttachItem {
  const AttachItem({required this.url, required this.name});
  final String url;
  final String name;
}

/// Shows a modal bottom sheet listing attachments with download/open/share.
void showAttachmentsSheet(
  BuildContext context, {
  required List<AttachItem> items,
  required String dirName,
  Map<String, String>? downloadHeaders,
}) {
  final manager = getIt<DownloadManager>();
  // Prime the manager: enqueue tasks for items that already exist on disk.
  for (final item in items) {
    checkDownloadedFile(dirName, item.name).then((path) {
      if (path != null) {
        final task = manager.enqueue(item.url, dirName, item.name, headers: downloadHeaders);
        if (task.status == DownloadStatus.pending) {
          manager.updateTask(task, status: DownloadStatus.done, downloadedPath: path);
        }
      }
    });
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _AttachmentsSheetContent(
      items: items,
      dirName: dirName,
      downloadHeaders: downloadHeaders,
    ),
  );
}

class _AttachmentsSheetContent extends StatelessWidget {
  const _AttachmentsSheetContent({
    required this.items,
    required this.dirName,
    this.downloadHeaders,
  });

  final List<AttachItem> items;
  final String dirName;
  final Map<String, String>? downloadHeaders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.8,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.attach_file,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${l10n.attachments} (${items.length})',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: items.length,
              itemBuilder: (ctx, index) => _SheetAttachmentTile(
                item: items[index],
                dirName: dirName,
                downloadHeaders: downloadHeaders,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetAttachmentTile extends StatelessWidget {
  const _SheetAttachmentTile({
    required this.item,
    required this.dirName,
    this.downloadHeaders,
  });

  final AttachItem item;
  final String dirName;
  final Map<String, String>? downloadHeaders;

  IconData _fileIcon() {
    final lower = item.name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Icons.description;
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return Icons.table_chart;
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return Icons.slideshow;
    if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  void _open(String path) => OpenFilex.open(path);
  void _share(String path) => Share.shareXFiles([XFile(path)]);

  Future<void> _startDownload(DownloadManager manager, BuildContext context) async {
    final task = manager.enqueue(item.url, dirName, item.name, headers: downloadHeaders);
    manager.updateTask(task, status: DownloadStatus.downloading);
    try {
      final path = await downloadFile(item.url, dirName, item.name, headers: downloadHeaders);
      if (task.status != DownloadStatus.error) {
        manager.updateTask(task, status: DownloadStatus.done, downloadedPath: path);
      }
    } on CaptchaRequiredException catch (e) {
      final path = await popupOrNavigate(
        context,
        CaptchaWebViewPage(
          captchaUrl: e.captchaUrl,
          dirName: dirName,
          fileName: item.name,
          downloadHeaders: downloadHeaders,
        ),
      );
      if (path != null && context.mounted) {
        manager.updateTask(task, status: DownloadStatus.done, downloadedPath: path as String);
      } else {
        manager.updateTask(task, status: DownloadStatus.error, errorMessage: '需要验证');
      }
    } catch (e) {
      manager.updateTask(task, status: DownloadStatus.error, errorMessage: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = getIt<DownloadManager>();
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final task = manager.taskFor(dirName, item.name);

        // Show done state if task completed or file already known.
        if (task != null && task.status == DownloadStatus.done && task.downloadedPath != null) {
          return _buildDoneTile(context, task.downloadedPath!);
        }

        // Show downloading state.
        if (task != null &&
            (task.status == DownloadStatus.downloading || task.status == DownloadStatus.pending)) {
          return ListTile(
            leading: Icon(_fileIcon(), color: Theme.of(context).colorScheme.primary),
            title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        // Show error state with retry.
        if (task != null && task.status == DownloadStatus.error) {
          return ListTile(
            leading: Icon(_fileIcon(), color: Theme.of(context).colorScheme.primary),
            title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 20),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _startDownload(manager, context),
                ),
              ],
            ),
          );
        }

        // Default: check disk, then show download button.
        return _buildDefaultTile(context, manager);
      },
    );
  }

  Widget _buildDefaultTile(BuildContext context, DownloadManager manager) {
    return ListTile(
      leading: Icon(_fileIcon(), color: Theme.of(context).colorScheme.primary),
      title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: FutureBuilder<String?>(
        future: checkDownloadedFile(dirName, item.name),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (snapshot.data != null) {
            // Already on disk — register in manager.
            final task = manager.enqueue(item.url, dirName, item.name, headers: downloadHeaders);
            if (task.status == DownloadStatus.pending) {
              manager.updateTask(task, status: DownloadStatus.done, downloadedPath: snapshot.data);
            }
            return _doneTrailing(snapshot.data!);
          }
          return IconButton(
            icon: const Icon(Icons.download),
            tooltip: '下载',
            onPressed: () => _startDownload(manager, context),
          );
        },
      ),
    );
  }

  Widget _buildDoneTile(BuildContext context, String path) {
    return ListTile(
      leading: Icon(_fileIcon(), color: Theme.of(context).colorScheme.primary),
      title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: _doneTrailing(path),
    );
  }

  Widget _doneTrailing(String path) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: '分享',
          onPressed: () => _share(path),
        ),
        IconButton(
          icon: const Icon(Icons.check_circle, color: Colors.green),
          tooltip: '打开',
          onPressed: () => _open(path),
        ),
      ],
    );
  }
}
