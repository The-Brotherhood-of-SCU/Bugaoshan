import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'download_options.dart';

// ── CAPTCHA WebView Dialog ────────────────────────────────────────────────────

/// Dialog that loads the CAPTCHA page directly in a WebView.
///
/// The user completes the verification form on the original server page. When
/// the server returns the actual file after verification, [onDownloadStarting]
/// intercepts it, downloads the file, and calls [onDownloadComplete].
class CaptchaWebViewDialog extends StatefulWidget {
  const CaptchaWebViewDialog({
    super.key,
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
  State<CaptchaWebViewDialog> createState() => _CaptchaWebViewDialogState();
}

class _CaptchaWebViewDialogState extends State<CaptchaWebViewDialog> {
  bool _loading = true;
  // 弹窗是否已被用户主动关闭。关闭后 WebView 的下载回调可能仍在途，
  // 需要用 _closed + mounted 双重防护，避免对已关闭的弹窗执行 pop。
  bool _closed = false;

  Future<DownloadStartResponse?> _onDownloadStarting(
    InAppWebViewController controller,
    DownloadStartRequest request,
  ) async {
    // getCookies 也在 try 内：CookieManager 抛异常时同样要关闭弹窗并返回
    // 失败，不能静默卡住。
    try {
      final cookieHeader = await widget.getCookies();
      final headers = mergeDownloadHeaders(
        widget.downloadHeaders,
        cookieHeader: cookieHeader,
      );
      final path = await downloadFile(
        request.url.toString(),
        widget.attachmentDir,
        request.suggestedFilename ?? 'download',
        headers: headers,
      );
      // 无论弹窗是否已关闭，都回调更新任务状态为 done（文件确实已落盘，
      // 状态必须一致，避免「任务显示失败但文件已写入」）；但只在弹窗仍
      // 打开时才 pop，已关闭时不再触碰导航栈。
      if (mounted) {
        widget.onDownloadComplete(path);
        if (!_closed) {
          Navigator.pop(context, true);
        }
      }
    } catch (_) {
      // 下载失败：若弹窗仍打开则关闭它并返回 false，由调用方把任务标记
      // 为失败；已关闭时调用方已标记 captchaCancelled，无需处理。
      // WebView 始终接管下载（handled: true）不落到默认行为。
      if (!_closed && mounted) {
        Navigator.pop(context, false);
      }
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
                onPressed: () {
                  _closed = true;
                  Navigator.pop(context, false);
                },
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
