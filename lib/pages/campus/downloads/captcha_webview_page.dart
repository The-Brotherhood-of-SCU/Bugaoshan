import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

import 'file_utils.dart';

class CaptchaWebViewPage extends StatefulWidget {
  const CaptchaWebViewPage({
    super.key,
    required this.captchaUrl,
    required this.dirName,
    required this.fileName,
    this.downloadHeaders,
  });

  final String captchaUrl;
  final String dirName;
  final String fileName;
  final Map<String, String>? downloadHeaders;

  @override
  State<CaptchaWebViewPage> createState() => _CaptchaWebViewPageState();
}

class _CaptchaWebViewPageState extends State<CaptchaWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: _onNavigationRequest,
        ),
      )
      ..loadRequest(Uri.parse(widget.captchaUrl));
  }

  Future<NavigationDecision> _onNavigationRequest(
    NavigationRequest request,
  ) async {
    final url = request.url;
    if (!url.contains('download.jsp') || !url.contains('codeValue=')) {
      return NavigationDecision.navigate;
    }
    // Post-captcha download URL intercepted — fetch the file.
    try {
      final path = await downloadFile(
        url,
        widget.dirName,
        widget.fileName,
        headers: widget.downloadHeaders,
      );
      if (mounted) Navigator.pop(context, path);
    } catch (_) {
      // downloadFile may throw again — unexpected since codeValue is valid.
      if (mounted) Navigator.pop(context, null);
    }
    return NavigationDecision.prevent;
  }

  @override
  void dispose() {
    // ignore: unused_result
    _controller.loadRequest(Uri.parse('about:blank'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('安全验证'),
      ),
      body: Stack(
        children: [
          Opacity(
            opacity: _loading ? 0.01 : 1,
            child: WebViewWidget(controller: _controller),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
