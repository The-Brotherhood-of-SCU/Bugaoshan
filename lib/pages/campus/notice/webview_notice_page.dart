import 'dart:convert';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/download_manager.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared WebView-based notice page used by party/XGB and tuanwei/Youth SCU.
class WebViewNoticePage extends StatefulWidget {
  const WebViewNoticePage({
    super.key,
    required this.url,
    required this.beautifyAsset,
    required this.title,
    required this.initialTab,
    required this.attachmentDir,
    required this.heroTag,
    required this.debugLabel,
    this.downloadHeaders,
    this.useWebViewDownload = false,
  });

  final String url;
  final String beautifyAsset;
  final String title;
  final int initialTab;
  final String attachmentDir;
  final String heroTag;
  final String debugLabel;
  final Map<String, String>? downloadHeaders;
  final bool useWebViewDownload;

  @override
  State<WebViewNoticePage> createState() => _WebViewNoticePageState();
}

class _WebViewNoticePageState extends State<WebViewNoticePage> {
  InAppWebViewController? _controller;
  String _beautifyScript = '';
  String _domReadyScript = '';
  bool _loading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  List<AttachItem> _pageAttachments = [];
  String _errorHtmlTemplate = '';

  @override
  void initState() {
    super.initState();
    rootBundle.loadString(widget.beautifyAsset).then((s) {
      if (mounted) setState(() => _beautifyScript = s);
    });
    rootBundle.loadString('assets/webview_error.html').then((s) {
      _errorHtmlTemplate = s;
    });
    rootBundle.loadString('assets/js/dom_ready.js').then((s) {
      _domReadyScript = s;
    });
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: 'AttachmentsChannel',
      callback: _onAttachmentsMessage,
    );
    controller.addJavaScriptHandler(
      handlerName: 'DOMReady',
      callback: (_) => _onDomReady(),
    );
  }

  void _onAttachmentsMessage(List<dynamic> args) {
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
      if (mounted) setState(() => _pageAttachments = attachments);
    } catch (e) {
      debugPrint('${widget.debugLabel} parse attachments error: $e');
    }
  }

  void _onWebViewDownload(String url) {
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Future<void> _onLoadStart(InAppWebViewController controller, Uri? url) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _pageAttachments = [];
    });
  }

  Future<void> _finishLoading() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 50));
    final ctrl = _controller;
    if (ctrl == null) return;
    final back = await ctrl.canGoBack();
    final forward = await ctrl.canGoForward();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  Future<void> _onLoadStop(InAppWebViewController controller, Uri? url) async {
    if (_beautifyScript.isNotEmpty) {
      try {
        await controller.evaluateJavascript(source: _beautifyScript);
      } catch (e) {
        debugPrint('${widget.debugLabel} beautify script error: $e');
      }
      await controller.evaluateJavascript(source: _domReadyScript);
      // DOMReady handler will invoke _finishLoading after JS finishes.
      return;
    }
    await _finishLoading();
  }

  Future<void> _onDomReady() async {
    await _finishLoading();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<DownloadStartResponse?> _onDownloadStarting(
    InAppWebViewController controller,
    DownloadStartRequest request,
  ) async {
    final url = request.url.toString();
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(url),
      );
      final headers = <String, String>{
        if (widget.downloadHeaders != null) ...widget.downloadHeaders!,
        if (cookies.isNotEmpty)
          'Cookie': cookies.map((c) => '${c.name}=${c.value}').join('; '),
      };
      await getIt<DownloadManager>().download(
        url,
        widget.attachmentDir,
        request.suggestedFilename ?? 'download',
        headers: headers,
      );
      // Navigate back after download — the WebView left the notice page.
      // if (await controller.canGoBack()) {
      //   await controller.goBack();
      // }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('下载完成')));
      }
    } catch (e) {
      debugPrint('${widget.debugLabel} download error: $e');
    }
    return DownloadStartResponse(handled: true);
  }

  Future<void> _openInBrowser() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    final current = await ctrl.getUrl();
    final uri = current ?? Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _goBack() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (await ctrl.canGoBack()) {
      setState(() => _loading = true);
      await ctrl.goBack();
    }
  }

  Future<void> _goForward() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (await ctrl.canGoForward()) {
      setState(() => _loading = true);
      await ctrl.goForward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ctrl = _controller;
        if (ctrl != null && await ctrl.canGoBack()) {
          setState(() => _loading = true);
          await ctrl.goBack();
        } else if (mounted) {
          if (logicRootContext.mounted) Navigator.of(logicRootContext).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 152,
          title: Text(widget.title),
          leading: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                  onPressed: () {
                    if (logicRootContext.mounted) {
                      Navigator.of(logicRootContext).pop();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: '后退',
                  onPressed: _canGoBack ? _goBack : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: '前进',
                  onPressed: _canGoForward ? _goForward : null,
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: '已下载附件',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      NoticeDownloadedPage(initialTab: widget.initialTab),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: '在浏览器中打开',
              onPressed: _openInBrowser,
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              InAppWebView(
                onWebViewCreated: _onWebViewCreated,
                initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  useWideViewPort: false,
                ),
                onDownloadStarting: _onDownloadStarting,
                onLoadStart: _onLoadStart,
                onLoadStop: _onLoadStop,
                onReceivedError: (controller, request, error) {
                  debugPrint('${widget.debugLabel} WebView error: $error');
                  if ((request.isForMainFrame ?? false) &&
                      _errorHtmlTemplate.isNotEmpty) {
                    final html = _errorHtmlTemplate.replaceAll(
                      '{{error}}',
                      '${error.description} (${error.type})',
                    );
                    controller.loadData(data: html);
                  }
                },
              ),
              IgnorePointer(
                ignoring: !_loading,
                child: AnimatedOpacity(
                  opacity: _loading ? 0.99 : 0,
                  duration: _loading
                      ? Duration.zero
                      : appConfigService.cardSizeAnimationDuration.value,
                  curve: appCurve,
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
              if (_pageAttachments.isNotEmpty)
                NoticeAttachmentFab(
                  items: _pageAttachments,
                  dirName: widget.attachmentDir,
                  downloadHeaders: widget.downloadHeaders,
                  onWebViewDownload: widget.useWebViewDownload
                      ? _onWebViewDownload
                      : null,
                  boundarySize: Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  ),
                  heroTag: widget.heroTag,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
