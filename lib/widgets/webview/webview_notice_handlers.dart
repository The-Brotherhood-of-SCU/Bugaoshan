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

  void onWebViewDownload(String url) {
    controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
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

  Future<void> onDownloadAttachment(List<dynamic> args) async {
    if (downloadOptions == null) return;
    if (args.length < 2) return;
    final url = args[0] as String;
    final name = args[1] as String;
    final options = downloadOptions!;
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(url),
      );
      final headers = <String, String>{
        ...options.downloadHeaders!,
        if (cookies.isNotEmpty)
          'Cookie': cookies.map((c) => '${c.name}=${c.value}').join('; '),
      };
      await getIt<DownloadManager>().download(
        url,
        options.attachmentDir,
        name,
        headers: headers,
      );
      if (mounted) {
        showAttachmentsSheet(
          context,
          items: pageAttachments,
          dirName: options.attachmentDir,
          downloadHeaders: headers,
          onWebViewDownload: options.useWebViewDownload
              ? onWebViewDownload
              : null,
        );
      }
    } catch (e) {
      debugPrint('$debugLabel download attachment error: $e');
    }
  }

  Future<DownloadStartResponse?> onDownloadStarting(
    InAppWebViewController controller,
    DownloadStartRequest request,
  ) async {
    if (downloadOptions == null) return null;
    final options = downloadOptions!;
    final url = request.url.toString();
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(url),
      );
      final headers = <String, String>{
        ...options.downloadHeaders!,
        if (cookies.isNotEmpty)
          'Cookie': cookies.map((c) => '${c.name}=${c.value}').join('; '),
      };
      await getIt<DownloadManager>().download(
        url,
        options.attachmentDir,
        request.suggestedFilename ?? 'download',
        headers: headers,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('下载完成')));
      }
    } catch (e) {
      debugPrint('$debugLabel download error: $e');
    }
    return DownloadStartResponse(handled: true);
  }
}
