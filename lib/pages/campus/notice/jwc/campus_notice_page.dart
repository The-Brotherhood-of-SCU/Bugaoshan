import 'package:bugaoshan/pages/campus/downloads/shared_notice_downloads.dart';
import 'package:bugaoshan/pages/campus/notice/webview_notice_page.dart';
import 'package:flutter/material.dart';

class CampusNoticePage extends StatelessWidget {
  const CampusNoticePage({super.key, this.searchQuery, this.searchDate});

  /// 页面加载后自动搜索的关键词。
  final String? searchQuery;

  /// 对应的假日日期，用于搜索结果的时间间隔判断。
  final DateTime? searchDate;

  @override
  Widget build(BuildContext context) {
    return WebViewNoticePage(
      url: 'https://jwc.scu.edu.cn/tzgg.htm',
      beautifyAsset: 'assets/js/jwc_notice_beautify.js',
      title: '教务处',
      initialTab: 0,
      attachmentDir: kNoticeAttachmentDir,
      heroTag: 'jwc_attach_fab',
      debugLabel: 'JwcNotice',
      searchQuery: searchQuery,
      searchDate: searchDate,
    );
  }
}
