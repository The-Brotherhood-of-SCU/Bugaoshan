import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:webview_windows/webview_windows.dart';
import 'package:zikzak_inappwebview_platform_interface/zikzak_inappwebview_platform_interface.dart';

class InAppWebViewWindowsController extends PlatformInAppWebViewController {
  final WebviewController _controller;

  InAppWebViewWindowsController(
    PlatformInAppWebViewControllerCreationParams params,
    this._controller,
  ) : super.implementation(params);

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    WebUri? allowingReadAccessTo,
  }) async {
    if (urlRequest.url != null) {
      await _controller.loadUrl(urlRequest.url.toString());
    }
  }

  @override
  Future<void> loadData({
    required String data,
    String mimeType = "text/html",
    String encoding = "utf8",
    WebUri? baseUrl,
    WebUri? historyUrl,
    WebUri? allowingReadAccessTo,
  }) async {
    final dataUri = Uri.dataFromString(
      data,
      mimeType: mimeType,
      encoding: Encoding.getByName(encoding),
    ).toString();
    await _controller.loadUrl(dataUri);
  }

  @override
  Future<void> loadFile({required String assetFilePath}) async {
    final assetsDir = p.join(
      p.dirname(Platform.resolvedExecutable),
      'data',
      'flutter_assets',
    );
    final filePath = p.join(assetsDir, assetFilePath);

    // Windows file uri
    final fileUri = Uri.file(filePath).toString();
    await _controller.loadUrl(fileUri);
  }

  @override
  Future<WebUri?> getUrl() async {
    // Return null as we can't synchronously get the current URL without tracking it
    // and we don't want to block on the stream.
    // TODO: Implement URL tracking
    return null;
  }

  @override
  Future<String?> getTitle() async {
    return await _controller.title.first;
  }

  @override
  Future<int?> getProgress() async {
    return 100; // Placeholder
  }

  @override
  Future<String?> getHtml() async {
    final result = await evaluateJavascript(
      source: "document.documentElement.outerHTML",
    );
    return result?.toString();
  }

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    return await _controller.executeScript(source);
  }

  @override
  Future<void> reload() async {
    await _controller.reload();
  }

  @override
  Future<void> goBack() async {
    await _controller.goBack();
  }

  @override
  Future<Uint8List?> createPdf({PDFConfiguration? pdfConfiguration}) async {
    // TODO: Implement createPdf for Windows when webview_windows supports it
    return null;
  }

  @override
  Future<void> goForward() async {
    await _controller.goForward();
  }

  @override
  Future<void> stopLoading() async {
    await _controller.stop();
  }

  @override
  Future<PlatformPrintJobController?> printCurrentPage({
    PrintJobSettings? settings,
  }) async {
    // TODO: Implement printCurrentPage for Windows
    return null;
  }

  @override
  void dispose({bool isKeepAlive = false}) {
    if (!isKeepAlive) {
      _controller.dispose();
    }
  }
}
