import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/widgets/common/error_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

part 'notice_utils.dart';
part 'notice_http_client.dart';
part 'notice_models.dart';
part 'notice_content_renderer.dart';
part 'notice_image_handler.dart';
part 'notice_attachment_handler.dart';
part 'notice_detail_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  CampusNoticePage — notice list with search and date filters
// ═══════════════════════════════════════════════════════════════════════════════

class CampusNoticePage extends StatefulWidget {
  const CampusNoticePage({super.key});

  @override
  State<CampusNoticePage> createState() => _CampusNoticePageState();
}

class _CampusNoticePageState extends State<CampusNoticePage> {
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  List<_NoticeEntry> _entries = [];
  String? _nextPageUrl = _noticeListUrl;
  final Set<String> _seenUrls = {};
  String _query = '';
  bool _searchMode = false;
  String _searchEncodedKey = '';
  int _searchPage = 0;
  int _searchTotal = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _searchController = TextEditingController();
    _loadNotices();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _scrollLoadThreshold) {
      if (_searchMode) {
        _searchNotices(loadMore: true);
      } else {
        _loadNotices(loadMore: true);
      }
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
      });
      _NoticeHttp.clearCookies();
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
      final entries = _parseNotices(body, pageUrl: url);
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

  Future<void> _searchNotices({bool loadMore = false}) async {
    if (loadMore) {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    } else {
      final raw = _query.trim();
      if (raw.isEmpty) {
        _exitSearchMode();
        return;
      }
      setState(() {
        _loading = true;
        _error = null;
        _entries = [];
        _hasMore = true;
        _searchMode = true;
        _searchPage = 1;
        _searchTotal = 0;
        _seenUrls.clear();
      });
      _NoticeHttp.clearCookies();
      // Encode keyword: UTF-8 → Base64
      _searchEncodedKey = base64Encode(utf8.encode(raw));
    }

    final page = _searchPage;
    // Build URL: page 1 has no pagination params, page 2+ adds currentnum & newskeycode2
    final url = page == 1
        ? _searchUrl
        : '$_searchUrl&currentnum=$page&newskeycode2=$_searchEncodedKey';
    final referer = '$_noticeBase/index.htm';

    try {
      final raw = _query.trim();
      final resp = await _NoticeHttp.post(
        url,
        referer: referer,
        body: {
          'lucenenewssearchkey': _searchEncodedKey,
          '_lucenesearchtype': '1',
          'searchScope': '0',
          'showkeycode': raw,
        },
      );
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final body = _decodeBody(resp.bodyBytes);
      final result = _parseSearchResults(body);

      if (!mounted) return;
      final newEntries =
          result.entries.where((e) => _seenUrls.add(e.url)).toList();
      setState(() {
        _entries.addAll(newEntries);
        _searchTotal = result.total;
        _loading = false;
        _loadingMore = false;
        _searchPage = page + 1;
        _hasMore = newEntries.isNotEmpty && _entries.length < result.total;
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

  ({List<_NoticeEntry> entries, int total}) _parseSearchResults(String html) {
    final entries = <_NoticeEntry>[];
    for (final match in _searchItemReg.allMatches(html)) {
      final url = _normalizeNoticeUrl(match.group(1)!, baseUrl: _searchUrl);
      final title = _stripTags(match.group(2)!);
      final dateStr = match.group(3)!;
      final date = DateTime.tryParse(dateStr);
      if (date == null || title.isEmpty) continue;
      entries.add(_NoticeEntry(title: title, url: url, date: date));
    }
    // Extract total count
    var total = entries.length;
    final totalMatch = _searchTotalReg.firstMatch(html);
    if (totalMatch != null) {
      total = int.tryParse(totalMatch.group(1)!.replaceAll(',', '')) ?? total;
    }
    return (entries: entries, total: total);
  }

  void _exitSearchMode() {
    setState(() {
      _searchMode = false;
      _searchEncodedKey = '';
      _searchPage = 0;
      _searchTotal = 0;
    });
    _loadNotices();
  }

  void _onSearchSubmitted(String value) {
    final q = value.trim();
    if (q.isEmpty) {
      if (_searchMode) _exitSearchMode();
      return;
    }
    _searchNotices();
  }

  List<_NoticeEntry> _parseNotices(String html, {required String pageUrl}) {
    final entries = <_NoticeEntry>[];
    for (final match in _listItemReg.allMatches(html)) {
      final url = _normalizeNoticeUrl(match.group(1)!, baseUrl: pageUrl);
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
    if (_searchMode) return _entries;
    // Normal mode: client-side filter by query terms.
    final rawQuery = _query.trim();
    final terms = rawQuery.isEmpty
        ? <String>[]
        : rawQuery.toLowerCase().split(_filterSpaceReg).where((t) => t.isNotEmpty).toList();
    if (terms.isEmpty) return _entries;
    return _entries.where((entry) {
      return terms.every((t) => entry.normalizedTitle.contains(t));
    }).toList();
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
            onPressed: _loading
                ? null
                : () => _searchMode ? _searchNotices() : _loadNotices(),
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
        onRetry: _searchMode ? _searchNotices : _loadNotices,
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    onSubmitted: _onSearchSubmitted,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.campusNoticesSearchHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                                if (_searchMode) _exitSearchMode();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _onSearchSubmitted(_query),
                  child: Text(l10n.campusNoticesSearch),
                ),
              ],
            ),
            if (_searchMode && _searchTotal > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.campusNoticesSearchResults(_searchTotal),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
      onRefresh: () =>
          _searchMode ? _searchNotices() : _loadNotices(),
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
            title: Text(
              entry.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
