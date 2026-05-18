import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:bugaoshan/pages/campus/notice/webview_notice_page.dart';
import 'package:flutter/material.dart';

class PartyNoticePage extends StatelessWidget {
  const PartyNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebViewNoticePage(
      url: 'https://xgb.scu.edu.cn/index/tzgg.htm',
      beautifyAsset: 'assets/js/party_notice_beautify.js',
      title: '党委学工部',
      initialTab: 1,
      attachmentDir: kPartyAttachmentDir,
      heroTag: 'party_attach_fab',
      debugLabel: 'PartyNotice',
    );
  }
}
