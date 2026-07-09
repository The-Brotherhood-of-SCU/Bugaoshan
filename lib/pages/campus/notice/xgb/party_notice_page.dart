import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:bugaoshan/pages/campus/notice/webview_notice_page.dart';
import 'package:flutter/material.dart';

class PartyNoticePage extends StatelessWidget {
  const PartyNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n!.xgbTabLabel;

    return WebViewNoticePage(
      url: 'https://xgb.scu.edu.cn/index/tzgg.htm',
      beautifyAsset: 'assets/js/party_notice_beautify.js',
      title: title,
      heroTag: 'party_attach_fab',
      debugLabel: 'PartyNotice',
      downloadOptions: DownloadOptions(
        attachmentDir: kPartyAttachmentDir,
        initialTab: 1,
      ),
    );
  }
}
