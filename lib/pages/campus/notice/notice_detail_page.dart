part of 'campus_notice_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  CampusNoticeDetailPage — notice detail with state management only
// ═══════════════════════════════════════════════════════════════════════════════

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

      final widgets =
          _buildContentWidgets(context, contentHtml, baseUrl: widget.entry.url);
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
        Text(widget.entry.title,
            style: Theme.of(context).textTheme.titleLarge),
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
