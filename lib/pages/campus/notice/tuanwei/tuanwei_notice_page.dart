import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:bugaoshan/pages/campus/notice/webview_notice_page.dart';
import 'package:flutter/material.dart';

class TuanweiNoticePage extends StatelessWidget {
  const TuanweiNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebViewNoticePage(
      url: 'https://tuanwei.scu.edu.cn/index/gg.htm',
      beautifyAsset: 'assets/js/tuanwei_notice_beautify.js',
      title: '青春川大',
      initialTab: 2,
      attachmentDir: kTuanweiAttachmentDir,
      heroTag: 'tuanwei_attach_fab',
      downloadHeaders: {'Referer': 'https://tuanwei.scu.edu.cn'},
      debugLabel: 'TuanweiNotice',
      useWebViewDownload: true,
    );
  }
}
