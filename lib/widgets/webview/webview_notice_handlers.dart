import 'dart:convert';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:bugaoshan/services/download_manager.dart';
import 'package:bugaoshan/widgets/common/image_viewer.dart';
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
  /// If the server returns a CAPTCHA page, shows a dialog and retries with the
  /// user-supplied verification code.
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
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.downloadComplete)));
      }
    } on CaptchaRequiredException catch (e) {
      if (!mounted) return;
      final code = await _showCaptchaDialog(e);
      if (code == null || code.isEmpty) {
        if (mounted) {
          manager.updateTask(
            task,
            status: DownloadStatus.error,
            errorMessage: '验证码已取消',
          );
        }
        return;
      }
      if (!mounted) return;
      // Retry with the verification code appended.
      final codeUrl = '${e.originalUrl}&codeValue=$code';
      try {
        manager.updateTask(task, status: DownloadStatus.downloading);
        final path = await _doDownload(codeUrl, fileName, options);
        manager.updateTask(
          task,
          status: DownloadStatus.done,
          downloadedPath: path,
        );
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.downloadComplete)));
        }
      } on CaptchaRequiredException catch (_) {
        // Wrong code — server returned CAPTCHA again.
        if (mounted) {
          manager.updateTask(
            task,
            status: DownloadStatus.error,
            errorMessage: '验证码错误，请重试',
          );
        }
      } catch (retryErr) {
        if (mounted) {
          manager.updateTask(
            task,
            status: DownloadStatus.error,
            errorMessage: retryErr.toString(),
          );
        }
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
    final cookieHeader = await getDownloadCookieHeader(url);
    final headers = mergeDownloadHeaders(
      options.downloadHeaders,
      cookieHeader: cookieHeader,
    );
    return downloadFile(url, options.attachmentDir, fileName, headers: headers);
  }

  /// Shows a dialog that displays the CAPTCHA image and collects the code.
  Future<String?> _showCaptchaDialog(CaptchaRequiredException e) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CaptchaDialog(
        captchaException: e,
        getCookies: () => getDownloadCookieHeader(e.originalUrl),
        downloadHeaders: downloadOptions?.downloadHeaders,
      ),
    );
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

// ── CAPTCHA Dialog ────────────────────────────────────────────────────────────

class _CaptchaDialog extends StatefulWidget {
  const _CaptchaDialog({
    required this.captchaException,
    required this.getCookies,
    this.downloadHeaders,
  });

  final CaptchaRequiredException captchaException;
  final Future<String?> Function() getCookies;
  final Map<String, String>? downloadHeaders;

  @override
  State<_CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<_CaptchaDialog> {
  final _controller = TextEditingController();
  int _refreshTick = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _buildHeaders() async {
    final cookieHeader = await widget.getCookies();
    return <String, String>{
      ...?widget.downloadHeaders,
      if (cookieHeader != null && cookieHeader.isNotEmpty)
        'Cookie': cookieHeader,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Append a cache-busting random parameter so each refresh loads a fresh image.
    final now = DateTime.now().millisecondsSinceEpoch;
    final captchaUrl =
        '${widget.captchaException.captchaAbsoluteUrl}&randnum=$now$_refreshTick';

    return AlertDialog(
      title: const Text('请输入验证码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _refreshTick++),
            child: FutureBuilder<Map<String, String>>(
              future: _buildHeaders(),
              builder: (ctx, snap) {
                final headers = snap.data ?? {};
                return Image.network(
                  captchaUrl,
                  headers: headers,
                  height: 42,
                  fit: BoxFit.fitHeight,
                  errorBuilder: (_, err, stack) => const SizedBox(
                    height: 42,
                    child: Center(child: Icon(Icons.error_outline)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _refreshTick++),
            child: Text(
              '看不清？点我换一张',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLength: 4,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '验证码',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
