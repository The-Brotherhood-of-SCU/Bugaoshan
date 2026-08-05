import 'dart:convert';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:bugaoshan/services/download_manager.dart';
import 'package:bugaoshan/widgets/common/image_viewer.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart'; // for appConfigService
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'download_options.dart';

/// JavaScript handlers and download logic for WebViewNoticePage.
mixin WebViewNoticeHandlers<T extends StatefulWidget> on State<T> {
  InAppWebViewController? get controller;
  String get debugLabel;
  DownloadOptions? get downloadOptions;
  List<AttachItem> get pageAttachments;
  set pageAttachments(List<AttachItem> value);

  void onAttachmentsMessage(List<dynamic> args) {
    if (args.isEmpty) return;
    try {
      final data = jsonDecode(args[0] as String) as List;
      final attachments = data
          .map(
            (e) => AttachItem(
              url: e['url'] as String,
              name: utf8.decode(base64Decode(e['name'] as String)),
            ),
          )
          .toList();
      if (mounted) setState(() => pageAttachments = attachments);
    } catch (e) {
      debugPrint('$debugLabel parse attachments error: $e');
    }
  }

  /// Downloads a file through the WebView session with CAPTCHA handling.
  /// Called from the attachment sheet when [DownloadOptions.useWebViewDownload] is true.
  /// The task must already be enqueued in [DownloadManager].
  Future<void> onWebViewDownload(String url) async {
    final options = downloadOptions;
    if (options == null) return;

    final manager = getIt<DownloadManager>();
    final task = manager.taskFor(url, options.attachmentDir);
    if (task == null) return;

    await _downloadWithCaptchaHandling(
      url,
      task.fileName,
      options,
      task,
    );
  }

  void onOpenImage(List<dynamic> args) {
    if (args.isEmpty) return;
    final url = args[0] as String;
    if (url.isEmpty) return;
    showFullScreenImageViewer(context, imageUrl: url);
  }

  void onOpenExternalLink(List<dynamic> args) {
    if (args.isEmpty) return;
    final url = args[0] as String;
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final l10n = AppLocalizations.of(context)!;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.campusNoticesExternalLink),
        content: Text(l10n.campusNoticesConfirmOpenLink(url)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.campusNoticesOpenInBrowser),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    });
  }

  // ── CAPTCHA-aware download ────────────────────────────────────────────────────

  /// Downloads [url] and updates [task] in DownloadManager.
  /// On CAPTCHA, opens a WebView dialog so the user can complete verification
  /// directly on the server page.
  Future<void> _downloadWithCaptchaHandling(
    String url,
    String fileName,
    DownloadOptions options,
    DownloadTask task,
  ) async {
    final manager = getIt<DownloadManager>();
    manager.updateTask(task, status: DownloadStatus.downloading);

    try {
      final path = await _doDownload(url, fileName, options);
      manager.updateTask(
        task,
        status: DownloadStatus.done,
        downloadedPath: path,
      );
    } on CaptchaRequiredException catch (_) {
      if (!mounted) return;
      // Let the user complete the CAPTCHA in a WebView — it handles the rest.
      final ok = await _showCaptchaWebViewDialog(url, options, task);
      if (!ok && mounted) {
        manager.updateTask(
          task,
          status: DownloadStatus.error,
          errorMessage: AppLocalizations.of(context)!.captchaCancelled,
        );
      }
    } catch (e) {
      if (mounted) {
        manager.updateTask(
          task,
          status: DownloadStatus.error,
          errorMessage: e.toString(),
        );
      }
    }
  }

  /// Downloads a file via HTTP with WebView session cookies.
  Future<String> _doDownload(
    String url,
    String fileName,
    DownloadOptions options,
  ) async {
    if (appConfigService.forceCaptchaForDownload.value) {
      throw const CaptchaRequiredException();
    }
    final cookieHeader = await getDownloadCookieHeader(url);
    final headers = mergeDownloadHeaders(
      options.downloadHeaders,
      cookieHeader: cookieHeader,
    );
    return downloadFile(url, options.attachmentDir, fileName, headers: headers);
  }

  /// Opens a dialog with a WebView that loads the CAPTCHA page.
  /// Returns true if the user completed the CAPTCHA and the file was downloaded.
  Future<bool> _showCaptchaWebViewDialog(
    String url,
    DownloadOptions options,
    DownloadTask task,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CaptchaWebViewDialog(
        url: url,
        onDownloadComplete: (String filePath) {
          getIt<DownloadManager>().updateTask(
            task,
            status: DownloadStatus.done,
            downloadedPath: filePath,
          );
          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.downloadComplete)));
          }
          Navigator.pop(ctx, true);
        },
        getCookies: () => getDownloadCookieHeader(url),
        downloadHeaders: options.downloadHeaders,
        attachmentDir: options.attachmentDir,
      ),
    );
    return result ?? false;
  }

  Future<String?> getDownloadCookieHeader(String url) async {
    final cookies = await CookieManager.instance().getCookies(url: WebUri(url));
    if (cookies.isEmpty) return null;
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  }

  Future<void> downloadNoticeFile(
    String url,
    String dirName,
    String fileName, {
    required Map<String, String> headers,
  }) {
    return getIt<DownloadManager>().download(
      url,
      dirName,
      fileName,
      headers: headers,
    );
  }

  Future<void> onDownloadAttachment(List<dynamic> args) async {
    if (downloadOptions == null) return;
    if (args.length < 2) return;
    final url = args[0] as String;
    final name = args[1] as String;
    final options = downloadOptions!;

    // Enqueue a task so the sheet (if opened) shows progress.
    final manager = getIt<DownloadManager>();
    final task = manager.enqueue(
      url,
      options.attachmentDir,
      name,
      headers: mergeDownloadHeaders(options.downloadHeaders, cookieHeader: null),
    );

    try {
      await _downloadWithCaptchaHandling(url, name, options, task);
      if (mounted) {
        showAttachmentsSheet(
          context,
          items: pageAttachments,
          dirName: options.attachmentDir,
          downloadHeaders: null, // headers already embedded in task
          onWebViewDownload: options.useWebViewDownload
              ? onWebViewDownload
              : null,
        );
      }
    } catch (e) {
      debugPrint('$debugLabel download attachment error: $e');
    }
  }

  Future<bool> handleDownloadStartRequest(DownloadStartRequest request) async {
    final options = downloadOptions;
    if (options == null) return false;
    final url = request.url.toString();
    try {
      final headers = mergeDownloadHeaders(
        options.downloadHeaders,
        cookieHeader: await getDownloadCookieHeader(url),
      );
      await downloadNoticeFile(
        url,
        options.attachmentDir,
        request.suggestedFilename ?? 'download',
        headers: headers,
      );
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.downloadComplete)));
      }
      return true;
    } catch (e) {
      debugPrint('$debugLabel download error: $e');
      return false;
    }
  }

  Future<DownloadStartResponse?> onDownloadStarting(
    InAppWebViewController controller,
    DownloadStartRequest request,
  ) async {
    if (downloadOptions == null) return null;
    return DownloadStartResponse(
      handled: await handleDownloadStartRequest(request),
    );
  }
}

// ── CAPTCHA WebView Dialog ────────────────────────────────────────────────────

/// Dialog that loads the CAPTCHA page directly in a WebView.
///
/// The user completes the verification form on the original server page. When
/// the server returns the actual file after verification, [onDownloadStarting]
/// intercepts it, downloads the file, and calls [onDownloadComplete].
class _CaptchaWebViewDialog extends StatefulWidget {
  const _CaptchaWebViewDialog({
    required this.url,
    required this.onDownloadComplete,
    required this.getCookies,
    required this.attachmentDir,
    this.downloadHeaders,
  });

  final String url;
  final void Function(String filePath) onDownloadComplete;
  final Future<String?> Function() getCookies;
  final String attachmentDir;
  final Map<String, String>? downloadHeaders;

  @override
  State<_CaptchaWebViewDialog> createState() => _CaptchaWebViewDialogState();
}

class _CaptchaWebViewDialogState extends State<_CaptchaWebViewDialog> {
  bool _loading = true;

  Future<DownloadStartResponse?> _onDownloadStarting(
    InAppWebViewController controller,
    DownloadStartRequest request,
  ) async {
    final cookieHeader = await widget.getCookies();
    final headers = mergeDownloadHeaders(
      widget.downloadHeaders,
      cookieHeader: cookieHeader,
    );
    try {
      final path = await downloadFile(
        request.url.toString(),
        widget.attachmentDir,
        request.suggestedFilename ?? 'download',
        headers: headers,
      );
      widget.onDownloadComplete(path);
    } catch (_) {
      // Download failed — let the WebView keep showing whatever the server returned.
    }
    return DownloadStartResponse(handled: true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 420,
        height: 260,
        child: Column(
          children: [
            AppBar(
              title: Text(AppLocalizations.of(context)!.captchaDialogTitle),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context, false),
              ),
              toolbarHeight: 44,
            ),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                    ),
                    onDownloadStarting: _onDownloadStarting,
                    onLoadStop: (ctrl, uri) {
                      if (mounted) setState(() => _loading = false);
                    },
                  ),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
