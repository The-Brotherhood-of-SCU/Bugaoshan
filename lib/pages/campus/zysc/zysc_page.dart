import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/widgets/webview/webview_notice_page.dart';
import 'package:flutter/cupertino.dart';

class ZyscPage extends StatelessWidget {
  const ZyscPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n!.zyscTitle;
    return WebViewNoticePage(
      url: 'https://zysc.scyol.com/fzysc/#/pages/tabbar/index',
      beautifyAsset: null,
      title: title,
      heroTag: 'zy_attach_fab',
      debugLabel: 'ZyscNotice',
    );
  }
}
