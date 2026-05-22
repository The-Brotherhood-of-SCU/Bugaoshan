import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:bugaoshan/pages/campus/notice/webview_notice_page.dart';
import 'package:flutter/material.dart';

class CampusNoticePage extends StatelessWidget {
  const CampusNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebViewNoticePage(
      url: 'https://jwc.scu.edu.cn/tzgg.htm',
      beautifyAsset: 'assets/js/jwc_notice_beautify.js',
      title: '教务处',
      initialTab: 0,
      attachmentDir: kNoticeAttachmentDir,
      heroTag: 'jwc_attach_fab',
      debugLabel: 'JwcNotice',
    );
  }
}
