import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:os_type/os_type.dart';
import 'package:url_launcher/url_launcher.dart';

import 'download_options.dart';
import 'webview_notice_handlers.dart';
import 'webview_unsupported_page.dart';

export 'download_options.dart';
export 'webview_unsupported_page.dart';

/// Shared WebView-based notice page used by party/XGB and tuanwei/Youth SCU.
class WebViewNoticePage extends StatefulWidget {
  const WebViewNoticePage({
    super.key,
    required this.url,
    required this.beautifyAsset,
    required this.title,
    required this.heroTag,
    required this.debugLabel,
    this.downloadOptions,
    this.enableLoadingMask = true,
  });

  final String url;
  final String? beautifyAsset;
  final String title;
  final String heroTag;
  final String debugLabel;
  final DownloadOptions? downloadOptions;
  final bool enableLoadingMask;

  @override
  State<WebViewNoticePage> createState() => _WebViewNoticePageState();
}

class _WebViewNoticePageState extends State<WebViewNoticePage>
    with WebViewNoticeHandlers {
  InAppWebViewController? _controller;
  String _beautifyScript = '';
  String _domReadyScript = '';
  bool _realLoading = false;
  //disable loading if beautify script is empty
  bool get _loading =>
      _beautifyScript.isNotEmpty && _realLoading && widget.enableLoadingMask;
  set _loading(bool value) {
    if (_beautifyScript.isNotEmpty) _realLoading = value;
  }

  bool _canGoBack = false;
  bool _canGoForward = false;
  List<AttachItem> _pageAttachments = [];
  String _errorHtmlTemplate = '';

  @override
  InAppWebViewController? get controller => _controller;

  @override
  String get debugLabel => widget.debugLabel;

  @override
  DownloadOptions? get downloadOptions => widget.downloadOptions;

  @override
  List<AttachItem> get pageAttachments => _pageAttachments;

  @override
  set pageAttachments(List<AttachItem> value) => _pageAttachments = value;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/webview_error.html').then((s) {
      _errorHtmlTemplate = s;
    });
    if (widget.beautifyAsset == null) return;
    rootBundle.loadString(widget.beautifyAsset!).then((s) {
      if (mounted) setState(() => _beautifyScript = s);
    });
    rootBundle.loadString('assets/js/dom_ready.js').then((s) {
      _domReadyScript = s;
    });
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: 'AttachmentsChannel',
      callback: onAttachmentsMessage,
    );
    controller.addJavaScriptHandler(
      handlerName: 'DOMReady',
      callback: (_) => _onDomReady(),
    );
    if (widget.downloadOptions != null) {
      controller.addJavaScriptHandler(
        handlerName: 'DownloadAttachment',
        callback: onDownloadAttachment,
      );
    }
    controller.addJavaScriptHandler(
      handlerName: 'OpenImage',
      callback: onOpenImage,
    );
    controller.addJavaScriptHandler(
      handlerName: 'OpenExternalLink',
      callback: onOpenExternalLink,
    );
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
      if (_domReadyScript.isNotEmpty) {
        try {
          await controller.evaluateJavascript(source: _domReadyScript);
        } catch (e) {
          debugPrint('${widget.debugLabel} dom ready script error: $e');
          await _finishLoading();
        }
        return;
      }
    }
    await _finishLoading();
  }

  Future<void> _onDomReady() async {
    await _finishLoading();
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
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.linux || OS.isHarmony) {
      return WebViewUnsupportedPage(title: widget.title);
    }
    return _buildWebViewPage(context);
  }

  Widget _buildWebViewPage(BuildContext context) {
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
          centerTitle: true,
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
            if (widget.downloadOptions != null)
              IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: '已下载附件',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoticeDownloadedPage(
                      initialTab: widget.downloadOptions!.initialTab,
                    ),
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
                onDownloadStarting: onDownloadStarting,
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
              if (_pageAttachments.isNotEmpty && widget.downloadOptions != null)
                NoticeAttachmentFab(
                  items: _pageAttachments,
                  dirName: widget.downloadOptions!.attachmentDir,
                  downloadHeaders: widget.downloadOptions!.downloadHeaders,
                  onWebViewDownload: widget.downloadOptions!.useWebViewDownload
                      ? onWebViewDownload
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
