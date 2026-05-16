import 'dart:convert';

import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_all/webview_all.dart';

const _kTuanweiNoticeUrl = 'https://tuanwei.scu.edu.cn/index/gg.htm';
const _kBeautifyAsset = 'assets/js/tuanwei_notice_beautify.js';

class TuanweiNoticePage extends StatefulWidget {
  const TuanweiNoticePage({super.key});

  @override
  State<TuanweiNoticePage> createState() => _TuanweiNoticePageState();
}

class _TuanweiNoticePageState extends State<TuanweiNoticePage> {
  late final WebViewController _controller;
  String _beautifyScript = '';
  bool _loading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  List<AttachItem> _pageAttachments = [];

  @override
  void initState() {
    super.initState();
    rootBundle.loadString(_kBeautifyAsset).then((s) {
      if (mounted) setState(() => _beautifyScript = s);
    });
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'AttachmentsChannel',
        onMessageReceived: _onAttachmentsMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _pageAttachments = [];
            });
          },
          onPageFinished: (_) async {
            if (_beautifyScript.isNotEmpty) {
              try {
                await _controller.runJavaScript(_beautifyScript);
              } catch (e) {
                debugPrint('TuanweiNotice beautify script error: $e');
              }
            }
            if (!mounted) return;
            final back = await _controller.canGoBack();
            final forward = await _controller.canGoForward();
            await Future.delayed(const Duration(milliseconds: 100));
            setState(() {
              _loading = false;
              _canGoBack = back;
              _canGoForward = forward;
            });
          },
          onWebResourceError: (error) {
            debugPrint('TuanweiNotice WebView error: $error');
          },
        ),
      )
      ..loadRequest(Uri.parse(_kTuanweiNoticeUrl));
  }

  void _onAttachmentsMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as List;
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
      debugPrint('TuanweiNotice parse attachments error: $e');
    }
  }

  @override
  void dispose() {
    _controller.loadRequest(Uri.parse('about:blank'));
    super.dispose();
  }

  Future<void> _openInBrowser() async {
    final current = await _controller.currentUrl();
    final uri = Uri.parse(current ?? _kTuanweiNoticeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      setState(() => _loading = true);
      await _controller.goBack();
    }
  }

  Future<void> _goForward() async {
    if (await _controller.canGoForward()) {
      setState(() => _loading = true);
      await _controller.goForward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 152,
          title: const Text('青春川大通知'),
          leading: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(logicRootContext).pop(),
                ),
                if (_canGoBack)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: '后退',
                    onPressed: _goBack,
                  ),
                if (_canGoForward)
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: '前进',
                    onPressed: _goForward,
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
                  builder: (_) => const NoticeDownloadedPage(initialTab: 2),
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
              Opacity(
                opacity: _loading ? 0.01 : 1,
                child: WebViewWidget(controller: _controller),
              ),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_pageAttachments.isNotEmpty)
                NoticeAttachmentFab(
                  items: _pageAttachments,
                  dirName: kTuanweiAttachmentDir,
                  downloadHeaders: const {'Referer': 'https://tuanwei.scu.edu.cn'},
                  boundarySize: Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  ),
                  heroTag: 'tuanwei_attach_fab',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
