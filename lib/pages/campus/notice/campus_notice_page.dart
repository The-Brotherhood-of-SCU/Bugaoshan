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

part 'notice_utils.dart';
part 'notice_http_client.dart';
part 'notice_models.dart';
part 'notice_content_renderer.dart';
part 'notice_image_handler.dart';
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
    final rawQuery = _query.trim();
    final terms = rawQuery.isEmpty
        ? <String>[]
        : rawQuery.toLowerCase().split(_filterSpaceReg).where((t) => t.isNotEmpty).toList();
    return _entries.where((entry) {
      final inRange =
          _selectedRange == null ||
          (!entry.date.isBefore(_selectedRange!.start) &&
              !entry.date.isAfter(_selectedRange!.end));
      if (!inRange) return false;
      if (terms.isEmpty) return true;
      // All search terms must appear in the normalized title.
      return terms.every((t) => entry.normalizedTitle.contains(t));
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
