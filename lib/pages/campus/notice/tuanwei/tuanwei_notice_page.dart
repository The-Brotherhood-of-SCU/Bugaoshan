import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:bugaoshan/widgets/webview/webview_notice_page.dart';
import 'package:flutter/material.dart';

class TuanweiNoticePage extends StatelessWidget {
  const TuanweiNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n!.tuanweiTabLabel;

    return WebViewNoticePage(
      url: 'https://tuanwei.scu.edu.cn/index/gg.htm',
      beautifyAsset: 'assets/js/tuanwei_notice_beautify.js',
      title: title,
      heroTag: 'tuanwei_attach_fab',
      debugLabel: 'TuanweiNotice',
      downloadOptions: DownloadOptions(
        useWebViewDownload: true,
        attachmentDir: kTuanweiAttachmentDir,
        downloadHeaders: {'Referer': 'https://tuanwei.scu.edu.cn'},
        initialTab: 2,
      ),
    );
  }
}
