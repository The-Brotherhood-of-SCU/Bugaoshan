import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:bugaoshan/widgets/webview/webview_notice_page.dart';
import 'package:flutter/material.dart';

class CampusNoticePage extends StatelessWidget {
  const CampusNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n!.jwcTabLabel;
    return WebViewNoticePage(
      url: 'https://jwc.scu.edu.cn/tzgg.htm',
      beautifyAsset: 'assets/js/jwc_notice_beautify.js',
      title: title,
      heroTag: 'jwc_attach_fab',
      debugLabel: 'JwcNotice',
      downloadOptions: DownloadOptions(
        attachmentDir: kNoticeAttachmentDir,
        initialTab: 0,
      ),
    );
  }
}
