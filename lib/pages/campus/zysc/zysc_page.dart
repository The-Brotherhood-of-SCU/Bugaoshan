import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/widgets/webview/webview_notice_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ZyscPage extends StatelessWidget {
  const ZyscPage({super.key});

  static const _url = 'https://zysc.scyol.com/fzysc/#/pages/tabbar/index';

  Future<void> _openInBrowser(BuildContext context) async {
    try {
      if (await launchUrl(
        Uri.parse(_url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
      AppLog.w('ZyscPage', '打开外部浏览器失败');
    } catch (_) {
      AppLog.w('ZyscPage', '打开外部浏览器时发生异常');
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.operationFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n!.zyscTitle;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return Scaffold(
        appBar: AppBar(title: Text(title), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.campusNoticesExternalLink,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _openInBrowser(context),
                  icon: const Icon(Icons.open_in_browser),
                  label: Text(l10n.campusNoticesOpenInBrowser),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return WebViewNoticePage(
      url: _url,
      beautifyAsset: 'assets/js/volunteer_sichuan.js',
      title: title,
      heroTag: 'zy_attach_fab',
      enableLoadingMask: false,
      debugLabel: 'ZyscNotice',
    );
  }
}
