import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:bugaoshan/pages/campus/notice/jwc/campus_notice_page.dart';
import 'package:bugaoshan/pages/campus/notice/webview_notice_page.dart';

class NoticePage extends StatefulWidget {
  const NoticePage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.noticeSection),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.noticeTabJwc),
            Tab(text: l10n.dockLabelNoticeParty),
            Tab(text: l10n.dockLabelNoticeTuanwei),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const CampusNoticePage(),
          const WebViewNoticePage(
            url: 'https://xgb.scu.edu.cn/index/tzgg.htm',
            beautifyAsset: 'assets/js/party_notice_beautify.js',
            title: '党委学工部',
            initialTab: 1,
            attachmentDir: kPartyAttachmentDir,
            heroTag: 'party_attach_fab',
            debugLabel: 'PartyNotice',
            showNavigation: false,
          ),
          const WebViewNoticePage(
            url: 'https://tuanwei.scu.edu.cn/index/gg.htm',
            beautifyAsset: 'assets/js/tuanwei_notice_beautify.js',
            title: '青春川大',
            initialTab: 2,
            attachmentDir: kTuanweiAttachmentDir,
            heroTag: 'tuanwei_attach_fab',
            downloadHeaders: {'Referer': 'https://tuanwei.scu.edu.cn'},
            debugLabel: 'TuanweiNotice',
            useWebViewDownload: true,
            showNavigation: false,
          ),
        ],
      ),
    );
  }
}
