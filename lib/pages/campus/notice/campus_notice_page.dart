import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/widgets/common/error_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

const _noticeBase = 'https://jwc.scu.edu.cn';
const _noticeListUrl = '$_noticeBase/tzgg.htm';
const _noticeUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
const _scrollLoadThreshold = 160.0;
const _noticePageFirstNum = 200;

/// Shared HTTP client with cookie jar for notice requests.
class _NoticeHttp {
  static final _cookieJar = <String, String>{};
  static http.Client? _client;

  static http.Client _getClient() {
    _client ??= http.Client();
    return _client!;
  }

  static Map<String, String> _buildHeaders([String? referer]) {
    final headers = <String, String>{
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'User-Agent': _noticeUserAgent,
    };
    if (referer != null) {
      headers['Referer'] = referer;
    }
    if (_cookieJar.isNotEmpty) {
      headers['Cookie'] = _cookieJar.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
    }
    return headers;
  }

  static void _collectCookies(http.BaseResponse response) {
    // Use lowercase 'set-cookie' for case-insensitive header lookup.
    // The http package normalizes header keys to lowercase.
    final value = response.headers['set-cookie'];
    if (value == null) {
      return;
    }
    // The http package joins multiple Set-Cookie headers with ', '.
    // Split on ', ' only when it acts as a header separator, not inside
    // cookie attribute values like Expires.
    // RFC 6265 §4.1.1: cookie-name is a token; cookie-value may contain
    // separators but we extract until the first ';'.
    for (final cookie in value.split(RegExp(r', (?=[a-zA-Z0-9_.-]+=)'))) {
      final eq = cookie.indexOf('=');
      final semi = cookie.indexOf(';');
      if (eq <= 0) {
        continue;
      }
      final key = cookie.substring(0, eq).trim();
      final val = semi > eq
          ? cookie.substring(eq + 1, semi).trim()
          : cookie.substring(eq + 1).trim();
      if (key.isNotEmpty && val.isNotEmpty) {
        _cookieJar[key] = val;
      }
    }
  }

  static Future<http.Response> get(String url, {String? referer}) async {
    final client = _getClient();
    final resp = await client.get(
      Uri.parse(url),
      headers: _buildHeaders(referer ?? url),
    );
    _collectCookies(resp);
    return resp;
  }

  static void clearCookies() {
    _cookieJar.clear();
  }
}

/// Decodes response bytes to UTF-8, logging any encoding errors instead of
/// silently replacing malformed data.
String _decodeBody(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException catch (e) {
    debugPrint('Body encoding error: $e, falling back with allowMalformed');
    return utf8.decode(bytes, allowMalformed: true);
  }
}

// ── Shared RegExp constants (compiled once, reused across instances) ──────────
//
// Note: these patterns use [\s\S]*? (non-greedy dot-all) heavily to match
// across HTML elements. This is acceptable for the small (≈50 KB) pages served
// by jwc.scu.edu.cn but may slow down on significantly larger documents.

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

final _contentPatterns = <RegExp>[
  RegExp(
    r'<div[^>]+class="v_news_content"[^>]*>([\s\S]*?)</div>',
    caseSensitive: false,
  ),
  RegExp(
    r'<div[^>]+id="vsb_content"[^>]*>([\s\S]*?)</div>',
    caseSensitive: false,
  ),
  RegExp(
    r'<div[^>]+class="detail-text"[^>]*>([\s\S]*?)</div>',
    caseSensitive: false,
  ),
  RegExp(
    r'<div[^>]+class="art-text"[^>]*>([\s\S]*?)</div>',
    caseSensitive: false,
  ),
  RegExp(r'<div[^>]+class="jxgl"[^>]*>([\s\S]*?)</div>', caseSensitive: false),
  RegExp(
    r'<div[^>]+class="content"[^>]*>([\s\S]*?)</div>',
    caseSensitive: false,
  ),
  RegExp(r'<article[^>]*>([\s\S]*?)</article>', caseSensitive: false),
];

String _normalizeNoticeUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  if (url.startsWith('/')) {
    return '$_noticeBase$url';
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

class CampusNoticePage extends StatefulWidget {
  const CampusNoticePage({super.key});

  @override
  State<CampusNoticePage> createState() => _CampusNoticePageState();
}

class _CampusNoticePageState extends State<CampusNoticePage> {
  late final ScrollController _scrollController;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  List<_NoticeEntry> _entries = [];
  String? _nextPageUrl = _noticeListUrl;
  final Set<String> _seenUrls = {};
  final Set<String> _pinnedUrls = {};
  DateTimeRange? _selectedRange;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadNotices();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _scrollLoadThreshold) {
      _loadNotices(loadMore: true);
    }
  }

  Future<void> _loadNotices({bool loadMore = false}) async {
    if (loadMore) {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
        _entries = [];
        _hasMore = true;
        _nextPageUrl = _noticeListUrl;
        _seenUrls.clear();
        _pinnedUrls.clear();
      });
      _NoticeHttp.clearCookies();
      await _fetchPinnedUrls();
    }

    final url = _nextPageUrl;
    if (url == null) {
      if (loadMore) {
        setState(() => _loadingMore = false);
      } else {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final resp = await _NoticeHttp.get(url, referer: _noticeListUrl);
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final body = _decodeBody(resp.bodyBytes);
      final entries = _parseNotices(body, _pinnedUrls);
      if (!loadMore && entries.isEmpty) {
        throw Exception('No notices found');
      }

      final nextUrl = _computeNextPageUrl(url);
      final newEntries = entries
          .where((entry) => _seenUrls.add(entry.url))
          .toList();

      if (!mounted) return;
      setState(() {
        _entries.addAll(newEntries);
        _loading = false;
        _loadingMore = false;
        _nextPageUrl = nextUrl;
        _hasMore = nextUrl != null;
      });
    } catch (e) {
      if (!mounted) return;
      if (loadMore) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.campusNoticesLoadFailed,
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      setState(() {
        if (!loadMore) {
          _error = e.toString();
          _loading = false;
        }
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _fetchPinnedUrls() async {
    try {
      final resp = await _NoticeHttp.get('$_noticeBase/index.htm');
      if (resp.statusCode != 200) return;
      final body = _decodeBody(resp.bodyBytes);
      for (final match in _pinnedReg.allMatches(body)) {
        _pinnedUrls.add(_normalizeNoticeUrl(match.group(1)!));
      }
    } catch (e) {
      debugPrint('_fetchPinnedUrls error: $e');
    }
  }

  List<_NoticeEntry> _parseNotices(String html, Set<String> pinnedUrls) {
    final entries = <_NoticeEntry>[];
    for (final match in _listItemReg.allMatches(html)) {
      final url = _normalizeNoticeUrl(match.group(1)!);
      final monthDay = match.group(2)!;
      final year = match.group(3)!;
      final title = _stripTags(match.group(4)!);
      final date = _parseDate(year, monthDay);
      if (date == null || title.isEmpty) continue;
      entries.add(
        _NoticeEntry(
          title: title,
          url: url,
          date: date,
          isPinned: pinnedUrls.contains(url),
        ),
      );
    }

    return entries;
  }

  /// Computes the next page URL based on the current URL pattern.
  /// Page 1: tzgg.htm → tzgg/200.htm
  /// Page 2: tzgg/200.htm → tzgg/199.htm
  /// ...
  /// Page 201: tzgg/1.htm → null (last page)
  String? _computeNextPageUrl(String currentUrl) {
    // First page → second page
    if (currentUrl == _noticeListUrl) {
      return '$_noticeBase/tzgg/$_noticePageFirstNum.htm';
    }
    // Extract page number from tzgg/{num}.htm
    final match = _pageNumReg.firstMatch(currentUrl);
    if (match == null) return null;
    final pageNum = int.tryParse(match.group(1)!);
    if (pageNum == null || pageNum <= 1) return null;
    return '$_noticeBase/tzgg/${pageNum - 1}.htm';
  }

  DateTime? _parseDate(String year, String monthDay) {
    final parts = monthDay.split('/');
    if (parts.length != 2) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final y = int.tryParse(year);
    if (month == null || day == null || y == null) return null;
    return DateTime(y, month, day);
  }

  List<_NoticeEntry> get _filteredEntries {
    final query = _query.trim().toLowerCase().replaceAll(_filterSpaceReg, '');
    return _entries.where((entry) {
      final inRange =
          _selectedRange == null ||
          (!entry.date.isBefore(_selectedRange!.start) &&
              !entry.date.isAfter(_selectedRange!.end));
      if (!inRange) return false;
      if (query.isEmpty) return true;
      return entry.normalizedTitle.contains(query);
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _selectedRange,
    );
    if (picked != null && mounted) {
      setState(() => _selectedRange = picked);
    }
  }

  String _rangeLabel(AppLocalizations l10n) {
    if (_selectedRange == null) return l10n.campusNoticesAllDates;
    return '${_formatDate(_selectedRange!.start)} - '
        '${_formatDate(_selectedRange!.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.campusNotices),
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadNotices,
          ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_error != null && _entries.isEmpty) {
      return RetryableErrorWidget(
        message: l10n.loadFailed,
        onRetry: _loadNotices,
      );
    }

    return Column(
      children: [
        _buildFilters(l10n),
        Expanded(child: _buildList(l10n)),
      ],
    );
  }

  Widget _buildFilters(AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.campusNoticesSearchHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(_rangeLabel(l10n)),
                  ),
                ),
                if (_selectedRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l10n.campusNoticesClearDate,
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _selectedRange = null),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(AppLocalizations l10n) {
    if (_loading && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final entries = _filteredEntries;
    if (entries.isEmpty) {
      return Center(
        child: Text(
          l10n.noData,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final showFooter = _loadingMore || _hasMore;

    return RefreshIndicator(
      onRefresh: () => _loadNotices(),
      child: ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: entries.length + (showFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= entries.length) {
          if (_loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return const SizedBox(height: 24);
        }
        final entry = entries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _buildDateBadge(context, entry),
            title: Row(
              children: [
                if (entry.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.campusNoticesPinned,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onError,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Text(_formatDate(entry.date)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CampusNoticeDetailPage(entry: entry),
              ),
            ),
          ),
        );
      },
    ),
    );
  }

  Widget _buildDateBadge(BuildContext context, _NoticeEntry entry) {
    final month = entry.date.month.toString().padLeft(2, '0');
    final day = entry.date.day.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$month/$day',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          Text(
            entry.date.year.toString(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class CampusNoticeDetailPage extends StatefulWidget {
  const CampusNoticeDetailPage({super.key, required this.entry});

  final _NoticeEntry entry;

  @override
  State<CampusNoticeDetailPage> createState() => _CampusNoticeDetailPageState();
}

class _CampusNoticeDetailPageState extends State<CampusNoticeDetailPage> {
  bool _loading = true;
  String? _error;
  List<Widget>? _contentWidgets;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await _NoticeHttp.get(widget.entry.url);
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final body = _decodeBody(resp.bodyBytes);

      if (!body.contains('v_news_content') &&
          !body.contains('vsb_content') &&
          !body.contains('ArticleTitle') &&
          !body.contains('detail-tit')) {
        throw Exception(
          'Invalid notice page format: missing expected content markers',
        );
      }

      final contentHtml = _extractContentHtml(body);
      if (contentHtml == null) {
        throw Exception('No content container found');
      }

      final widgets = _buildContentWidgets(contentHtml);
      if (widgets.isEmpty) {
        throw Exception('No content found');
      }

      if (!mounted) return;
      setState(() {
        _contentWidgets = widgets;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Notice detail error: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String? _extractContentHtml(String html) {
    for (final reg in _contentPatterns) {
      final match = reg.firstMatch(html);
      if (match != null) {
        return match.group(1) ?? '';
      }
    }
    return null;
  }

  List<Widget> _buildContentWidgets(String html) {
    final widgets = <Widget>[];
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    final linkStyle = bodyStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
    );

    // Collect all content elements with their positions for ordered rendering.
    final elements = <_ContentElement>[];

    for (final match in _paragraphReg.allMatches(html)) {
      elements.add(_ContentElement(match.start, match.group(0)!, true));
    }
    for (final match in _imgReg.allMatches(html)) {
      elements.add(_ContentElement(match.start, match.group(0)!, false));
    }
    elements.sort((a, b) => a.offset.compareTo(b.offset));

    final seenImages = <String>{};
    for (final element in elements) {
      if (element.isParagraph) {
        final textWidgets = _parseParagraphContent(
          element.html,
          bodyStyle,
          linkStyle,
        );
        if (textWidgets.isNotEmpty) {
          widgets.addAll(textWidgets);
          widgets.add(const SizedBox(height: 10));
        }
      } else {
        final src = _imgReg.firstMatch(element.html)?.group(1);
        if (src == null || src.startsWith('data:')) continue;
        final imageUrl = _normalizeNoticeUrl(src);
        if (!seenImages.add(imageUrl)) continue;
        widgets.add(_buildNoticeImage(imageUrl));
        widgets.add(const SizedBox(height: 10));
      }
    }

    if (widgets.isNotEmpty && widgets.last is SizedBox) {
      widgets.removeLast();
    }

    return widgets;
  }

  List<Widget> _parseParagraphContent(
    String paragraphHtml,
    TextStyle? bodyStyle,
    TextStyle? linkStyle,
  ) {
    // Extract paragraph inner HTML.
    final pMatch = _paragraphReg.firstMatch(paragraphHtml);
    var innerHtml = pMatch?.group(1) ?? paragraphHtml;

    // Strip <br> tags.
    innerHtml = innerHtml.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );

    // Split by links to create mixed text/link spans.
    final parts = <_InlineElement>[];
    var lastEnd = 0;
    for (final match in _linkReg.allMatches(innerHtml)) {
      if (match.start > lastEnd) {
        final text = _stripTags(innerHtml.substring(lastEnd, match.start));
        if (text.isNotEmpty) parts.add(_InlineElement(text, null));
      }
      final href = _normalizeNoticeUrl(match.group(1)!);
      final label = _stripTags(match.group(2)!);
      parts.add(_InlineElement(label.isNotEmpty ? label : href, href));
      lastEnd = match.end;
    }
    if (lastEnd < innerHtml.length) {
      final text = _stripTags(innerHtml.substring(lastEnd));
      if (text.isNotEmpty) parts.add(_InlineElement(text, null));
    }

    // If no links found, just strip all tags.
    if (parts.isEmpty) {
      final text = _normalizeText(_stripTags(innerHtml));
      if (text.isEmpty) return [];
      return [SelectableText(text, style: bodyStyle)];
    }

    // Build a RichText with mixed text and link spans.
    final spans = <InlineSpan>[];
    for (final part in parts) {
      if (part.href != null) {
        spans.add(
          TextSpan(
            text: part.text,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchUrl(
                Uri.parse(part.href!),
                mode: LaunchMode.externalApplication,
              ),
          ),
        );
      } else {
        spans.add(TextSpan(text: part.text, style: bodyStyle));
      }
    }

    final text = parts.map((p) => p.text).join();
    if (text.trim().isEmpty) return [];

    return [
      SelectableText.rich(
        TextSpan(children: spans, style: bodyStyle),
      ),
    ];
  }

  Widget _buildNoticeImage(String imageUrl) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(context, imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.fitWidth,
          headers: _NoticeHttp._buildHeaders(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 200,
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 200,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.loadFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    final l10n = AppLocalizations.of(context)!;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: GestureDetector(
                  onLongPress: () => _showImageActions(context, imageUrl, l10n),
                  child: PhotoView(
                    imageProvider: NetworkImage(
                      imageUrl,
                      headers: _NoticeHttp._buildHeaders(),
                    ),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.black,
                    ),
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 64,
                          color: Colors.white54,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () =>
                      _showImageActions(context, imageUrl, l10n),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageActions(
    BuildContext context,
    String imageUrl,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: Text(l10n.saveImageToGallery),
              onTap: () {
                Navigator.pop(ctx);
                _saveImageToGallery(context, imageUrl, l10n);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(l10n.share),
              onTap: () {
                Navigator.pop(ctx);
                _shareImage(context, imageUrl, l10n);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveImageToGallery(
    BuildContext context,
    String imageUrl,
    AppLocalizations l10n,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: _NoticeHttp._buildHeaders(),
      );
      if (response.statusCode != 200) throw Exception('Download failed');
      await Gal.putImageBytes(response.bodyBytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.imageSavedToGallery)),
        );
      }
    } catch (e) {
      debugPrint('Save image error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.imageSaveFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareImage(
    BuildContext context,
    String imageUrl,
    AppLocalizations l10n,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: _NoticeHttp._buildHeaders(),
      );
      if (response.statusCode != 200) throw Exception('Download failed');
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/notice_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(response.bodyBytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      debugPrint('Share image error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.imageSaveFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openOriginal() {
    launchUrl(
      Uri.parse(widget.entry.url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: l10n.campusNoticesOpenOriginal,
            onPressed: _openOriginal,
          ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_error != null && _contentWidgets == null) {
      return RetryableErrorWidget(
        message: '${l10n.loadFailed}\n$_error',
        onRetry: _loadDetail,
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_contentWidgets == null || _contentWidgets!.isEmpty) {
      return Center(child: Text(l10n.noData));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(widget.entry.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.calendar_month,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              _formatDate(widget.entry.date),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(height: 12),
        ..._contentWidgets!,
      ],
    );
  }
}

class _NoticeEntry {
  final String title;
  final String url;
  final DateTime date;
  final bool isPinned;
  final String normalizedTitle;

  _NoticeEntry({
    required this.title,
    required this.url,
    required this.date,
    this.isPinned = false,
  }) : normalizedTitle = title.toLowerCase().replaceAll(_filterSpaceReg, '');
}

class _ContentElement {
  final int offset;
  final String html;
  final bool isParagraph;

  _ContentElement(this.offset, this.html, this.isParagraph);
}

class _InlineElement {
  final String text;
  final String? href;

  _InlineElement(this.text, this.href);
}
