part of 'campus_notice_page.dart';

// ── Constants ───────────────────────────────────────────────────────────────────

const _noticeBase = 'https://jwc.scu.edu.cn';
const _noticeListUrl = '$_noticeBase/tzgg.htm';
const _noticeUserAgent = kDefaultUserAgent;
const _scrollLoadThreshold = 160.0;
const _noticePageFirstNum = 200;
const _searchUrl = '$_noticeBase/ssjgy.jsp?wbtreeid=1001';
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

/// Matches search result items from the search API response.
/// Format: <li><a href="info/{catId}/{artId}.htm">title</a><span>date</span></li>
/// The href must point to an article page (info/...) to exclude navigation items.
final _searchItemReg = RegExp(
  r'<li>\s*<a[^>]+href="(info/[^"]+)"[^>]*>'
  r'([\s\S]*?)</a>'
  r'\s*<span>(\d{4}-\d{2}-\d{2})</span>',
  caseSensitive: false,
);

/// Matches the total result count in search response: "共有 X,XXX 条"
final _searchTotalReg = RegExp(r'共有\s*([\d,]+)\s*条');

final _imgReg = RegExp(r'<img[^>]+src="([^"]+)"[^>]*>', caseSensitive: false);

final _linkReg = RegExp(
  r'<a[^>]+href="([^"]+)"[^>]*>([\s\S]*?)</a>',
  caseSensitive: false,
);

final _paragraphReg = RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false);

final _tableReg = RegExp(
  r'<table[^>]*>([\s\S]*?)</table>',
  caseSensitive: false,
);
final _tableRowReg = RegExp(r'<tr[^>]*>([\s\S]*?)</tr>', caseSensitive: false);
final _tableCellReg = RegExp(
  r'<t[dh][^>]*>([\s\S]*?)</t[dh]>',
  caseSensitive: false,
);

final _contentContainerReg = RegExp(
  r"""<div[^>]+(?:class=["']v_news_content["']|id=["']vsb_content["']|class=["']detail-text["']|class=["']art-text["']|class=["']content["']|class=["']wp_articlecontent["'])[^>]*>""",
  caseSensitive: false,
);

final _articleOpenReg = RegExp(r'<article[^>]*>', caseSensitive: false);

/// Strips the "点击次数：" label together with its inline `<script>` block
/// (e.g. `_showDynClicks("wbnews", ...)`), since the JS cannot execute
/// in a non-browser context and leaving the label produces a bare prefix.
final _clickCountReg = RegExp(
  r'点击次数[：:]\s*<script[^>]*>\s*_showDynClicks\s*\([^)]*\)\s*</script>',
  caseSensitive: false,
);

/// Matches the "上一条" / "下一条" navigation paragraphs at the bottom of
/// SCU notice pages (e.g. `<p><span>上一条：</span><a href="...">...</a></p>`).
final _prevNextReg = RegExp(
  r'<p[^>]*>\s*<span>\s*[上下]一条[：:]?\s*</span>[\s\S]*?</p>',
  caseSensitive: false,
);

/// Detects bare HTTP(S) URLs in plain text that are not wrapped in `<a>`
/// tags.  Stops at whitespace, CJK characters, or fullwidth punctuation.
final _bareUrlReg = RegExp(
  r'https?://[^\s一-鿿　-〿＀-￯，。、；：？！“”‘’（）【】《》]+',
  caseSensitive: false,
);

/// Splits [text] into segments, promoting bare HTTP(S) URLs to clickable
/// link entries in [parts].
void _extractBareUrls(String text, List<_InlineElement> parts) {
  var lastEnd = 0;
  for (final match in _bareUrlReg.allMatches(text)) {
    if (match.start > lastEnd) {
      parts.add(_InlineElement(text.substring(lastEnd, match.start), null));
    }
    parts.add(_InlineElement(match.group(0)!, match.group(0)!));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    parts.add(_InlineElement(text.substring(lastEnd), null));
  }
}

/// Chinese/fullwidth punctuation characters that may leak into raw href
/// attributes on the SCU website.  Only used to clean URLs; display text
/// retains its original punctuation.
/// Narrows the Fullwidth Forms block to actual punctuation, excluding
/// fullwidth letters (Ａ-Ｚ, ａ-ｚ) and digits (０-９).
final _chinesePunctReg = RegExp(
  r'[　-〿' // CJK Symbols & Punctuation ( 。、〃 etc.)
  r'！-／' // ！＂＃＄％＆＇（）＊＋，－．／
  r'：-＠' // ：；＜＝＞？＠
  r'［-｀' // ［＼］＾＿｀
  r'｛-～' // ｛｜｝～
  r'‘’“”' // ‘’“”
  r'–—' // –—
  r']',
);

// ── Utility functions ──────────────────────────────────────────────────────────

bool _isExternalUrl(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.host.isNotEmpty && uri.host != 'jwc.scu.edu.cn';
  } catch (_) {
    return false;
  }
}

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
    return Uri.parse(
      baseUrl.replaceAll(_chinesePunctReg, ''),
    ).resolve(url).toString();
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

