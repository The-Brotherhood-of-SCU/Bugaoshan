import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:bugaoshan/widgets/webview/download_options.dart';
import 'package:bugaoshan/widgets/webview/webview_notice_handlers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mergeDownloadHeaders', () {
    test('allows omitted configured headers', () {
      expect(mergeDownloadHeaders(null, cookieHeader: null), isEmpty);
    });

    test('adds cookies without mutating configured headers', () {
      const configured = {'Referer': 'https://example.com'};

      final headers = mergeDownloadHeaders(
        configured,
        cookieHeader: 'session=abc',
      );

      expect(headers, {
        'Referer': 'https://example.com',
        'Cookie': 'session=abc',
      });
      expect(configured, {'Referer': 'https://example.com'});
    });
  });

  group('WebViewNoticeHandlers download callback', () {
    test('handles a download when headers are omitted', () async {
      final state = _TestNoticeState();

      final handled = await state.handleDownloadStartRequest(_request());

      expect(handled, isTrue);
      expect(state.downloadedHeaders, isEmpty);
    });

    test('does not claim a failed download was handled', () async {
      final state = _TestNoticeState(downloadError: Exception('failed'));

      final handled = await state.handleDownloadStartRequest(_request());

      expect(handled, isFalse);
    });
  });
}

DownloadStartRequest _request() => DownloadStartRequest(
  contentLength: 1,
  suggestedFilename: 'attachment.pdf',
  url: WebUri('https://example.com/attachment.pdf'),
);

class _TestNoticeWidget extends StatefulWidget {
  const _TestNoticeWidget();

  @override
  State<_TestNoticeWidget> createState() => _TestNoticeState();
}

class _TestNoticeState extends State<_TestNoticeWidget>
    with WebViewNoticeHandlers<_TestNoticeWidget> {
  _TestNoticeState({this.downloadError});

  final Object? downloadError;
  Map<String, String>? downloadedHeaders;
  List<AttachItem> _attachments = const [];

  @override
  InAppWebViewController? get controller => null;

  @override
  String get debugLabel => 'TestNotice';

  @override
  DownloadOptions get downloadOptions =>
      const DownloadOptions(attachmentDir: 'test', initialTab: 0);

  @override
  List<AttachItem> get pageAttachments => _attachments;

  @override
  set pageAttachments(List<AttachItem> value) => _attachments = value;

  @override
  Future<String?> getDownloadCookieHeader(String url) async => null;

  @override
  Future<void> downloadNoticeFile(
    String url,
    String dirName,
    String fileName, {
    required Map<String, String> headers,
  }) async {
    downloadedHeaders = headers;
    if (downloadError case final error?) throw error;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
