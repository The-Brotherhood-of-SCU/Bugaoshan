part of 'campus_notice_page.dart';

// ── Constants ───────────────────────────────────────────────────────────────────

const _noticeBase = 'https://jwc.scu.edu.cn';
const _noticeListUrl = '$_noticeBase/tzgg.htm';
const _noticeUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
const _scrollLoadThreshold = 160.0;
const _noticePageFirstNum = 200;

// ── Shared RegExp constants ────────────────────────────────────────────────────

final _filterSpaceReg = RegExp(r'\s+');

final _listItemReg = RegExp(
  r'<li>\s*<a[^>]+href="([^"]+)"[^>]*>'
  r'(?:(?!</li>)[\s\S])*?<div class="date">'
  r'[\s\S]*?<p>(\d{2}/\d{2})\s*</p>\s*'
  r'<span>(\d{4})</span>'
  r'(?:(?!</li>)[\s\S])*?<div class="text">'
  r'[\s\S]*?<p>(.*?)</p>',
  caseSensitive: false,
);

final _pageNumReg = RegExp(r'tzgg/(\d+)\.htm$');

final _pinnedReg = RegExp(
  r'<li[^>]*>\s*<a[^>]+href="([^"]+)"[^>]*>'
  r'(?:(?!</li>)[\s\S])*?<div class="bq">\s*\[置顶\]',
  caseSensitive: false,
);

final _imgReg = RegExp(
  r'<img[^>]+src="([^"]+)"[^>]*>',
  caseSensitive: false,
);

final _linkReg = RegExp(
  r'<a[^>]+href="([^"]+)"[^>]*>([\s\S]*?)</a>',
  caseSensitive: false,
);

final _paragraphReg = RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false);

final _tableReg = RegExp(r'<table[^>]*>([\s\S]*?)</table>', caseSensitive: false);
final _tableRowReg = RegExp(r'<tr[^>]*>([\s\S]*?)</tr>', caseSensitive: false);
final _tableCellReg = RegExp(r'<t[dh][^>]*>([\s\S]*?)</t[dh]>', caseSensitive: false);

final _contentContainerReg = RegExp(
  r'<div[^>]+(?:class="v_news_content"|id="vsb_content"|class="detail-text"|class="art-text"|class="jxgl"|class="content"|class="wp_articlecontent")[^>]*>',
  caseSensitive: false,
);

final _articleOpenReg = RegExp(r'<article[^>]*>', caseSensitive: false);

/// Strips JS click-tracking calls (e.g. _showDynClicks("wbnews", ...))
/// and other inline script artifacts from content HTML.
final _scriptCallReg = RegExp(r'_showDynClicks\s*\([^)]*\)', caseSensitive: false);

/// Chinese punctuation characters that may appear in URLs or text content
/// from the SCU website, causing rendering issues.
final _chinesePunctReg = RegExp(r'[　-〿＀-￯‘’“”—–]');

// ── Utility functions ──────────────────────────────────────────────────────────

String _normalizeNoticeUrl(String url, {String? baseUrl}) {
  // Strip Chinese punctuation that may appear in raw href attributes.
  url = url.replaceAll(_chinesePunctReg, '');
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  if (url.startsWith('/')) {
    return '$_noticeBase$url';
  }
  // Relative path: resolve against the current page URL to preserve
  // path prefix (e.g., /info/1069/10336.htm → /info/1069/10337.htm).
  if (baseUrl != null) {
    return Uri.parse(baseUrl.replaceAll(_chinesePunctReg, '')).resolve(url).toString();
  }
  return '$_noticeBase/$url';
}

String _stripTags(String input) {
  return input
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();
}

String _normalizeText(String input) {
  var text = input;
  // Strip Chinese punctuation that leaks from raw HTML content.
  text = text.replaceAll(_chinesePunctReg, '');
  text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  text = text.replaceAll(RegExp(r'\n[ \t]+'), '\n');
  text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
