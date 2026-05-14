part of 'campus_notice_page.dart';

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

      final widgets = _buildContentWidgets(contentHtml, baseUrl: widget.entry.url);
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
    // Try div-based containers with proper nested-div handling.
    final divMatch = _contentContainerReg.firstMatch(html);
    if (divMatch != null) {
      return _extractNestedDivContent(html, divMatch.end);
    }
    // Try <article> tag.
    final articleMatch = _articleOpenReg.firstMatch(html);
    if (articleMatch != null) {
      final endTag = '</article>';
      final endIdx = html.indexOf(endTag, articleMatch.end);
      if (endIdx != -1) {
        return html.substring(articleMatch.end, endIdx);
      }
    }
    return null;
  }

  /// Extracts content between a matched opening <div> and its corresponding
  /// closing </div>, properly handling nested divs by counting depth.
  String? _extractNestedDivContent(String html, int start) {
    var depth = 1;
    var i = start;
    final openDiv = RegExp(r'<div[\s>]', caseSensitive: false);
    final closeDiv = '</div>';

    while (i < html.length && depth > 0) {
      final nextOpen = openDiv.firstMatch(html.substring(i));
      final nextClose = html.indexOf(closeDiv, i);

      if (nextClose == -1) return null;

      final openPos = nextOpen != null ? i + nextOpen.start : -1;

      if (openPos != -1 && openPos < nextClose) {
        depth++;
        i = openPos + 1;
      } else {
        depth--;
        if (depth == 0) {
          return html.substring(start, nextClose);
        }
        i = nextClose + closeDiv.length;
      }
    }
    return null;
  }

  List<Widget> _buildContentWidgets(String html, {String? baseUrl}) {
    // Strip JS click-tracking function calls that leak into raw content.
    html = html.replaceAll(_scriptCallReg, '');

    final widgets = <Widget>[];
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    final linkStyle = bodyStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
    );

    // Collect table ranges first so we can exclude inner elements.
    final tableRanges = <_Range>[];
    final tableElements = <_ContentElement>[];
    for (final match in _tableReg.allMatches(html)) {
      tableRanges.add(_Range(match.start, match.end));
      tableElements.add(_ContentElement(match.start, match.group(0)!, _ElementType.table));
    }

    bool insideTable(int offset) =>
        tableRanges.any((r) => offset >= r.start && offset < r.end);

    final elements = <_ContentElement>[];
    for (final match in _paragraphReg.allMatches(html)) {
      if (!insideTable(match.start)) {
        elements.add(_ContentElement(match.start, match.group(0)!, _ElementType.paragraph));
      }
    }
    for (final match in _imgReg.allMatches(html)) {
      if (!insideTable(match.start)) {
        elements.add(_ContentElement(match.start, match.group(0)!, _ElementType.image));
      }
    }
    elements.addAll(tableElements);
    elements.sort((a, b) => a.offset.compareTo(b.offset));

    final seenImages = <String>{};
    for (final element in elements) {
      switch (element.type) {
        case _ElementType.paragraph:
          final textWidgets = _parseParagraphContent(
            element.html,
            bodyStyle,
            linkStyle,
            baseUrl: baseUrl,
          );
          if (textWidgets.isNotEmpty) {
            widgets.addAll(textWidgets);
            widgets.add(const SizedBox(height: 10));
          }
        case _ElementType.image:
          final src = _imgReg.firstMatch(element.html)?.group(1);
          if (src == null || src.startsWith('data:')) continue;
          final imageUrl = _normalizeNoticeUrl(src);
          if (!seenImages.add(imageUrl)) continue;
          widgets.add(_buildNoticeImage(imageUrl));
          widgets.add(const SizedBox(height: 10));
        case _ElementType.table:
          final table = _buildNoticeTable(element.html);
          if (table != null) {
            widgets.add(table);
            widgets.add(const SizedBox(height: 10));
          }
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
    TextStyle? linkStyle, {
    String? baseUrl,
  }) {
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
        var text = _stripTags(innerHtml.substring(lastEnd, match.start));
        text = text.replaceAll(_chinesePunctReg, '');
        if (text.isNotEmpty) parts.add(_InlineElement(text, null));
      }
      final href = _normalizeNoticeUrl(match.group(1)!, baseUrl: baseUrl);
      var label = _stripTags(match.group(2)!);
      label = label.replaceAll(_chinesePunctReg, '');
      parts.add(_InlineElement(label.isNotEmpty ? label : href, href));
      lastEnd = match.end;
    }
    if (lastEnd < innerHtml.length) {
      var text = _stripTags(innerHtml.substring(lastEnd));
      text = text.replaceAll(_chinesePunctReg, '');
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

  Widget? _buildNoticeTable(String tableHtml) {
    final rows = <TableRow>[];
    for (final rowMatch in _tableRowReg.allMatches(tableHtml)) {
      final cells = <Widget>[];
      for (final cellMatch in _tableCellReg.allMatches(rowMatch.group(1)!)) {
        var text = cellMatch.group(1) ?? '';
        text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
        text = _stripTags(text);
        text = _normalizeText(text);
        cells.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        );
      }
      if (cells.isEmpty) continue;

      final isHeader = rowMatch.group(0)!.contains('<th');
      rows.add(
        TableRow(
          decoration: isHeader
              ? BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                )
              : null,
          children: cells.map((cell) {
            if (!isHeader) return cell;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                child: cell,
              ),
            );
          }).toList(),
        ),
      );
    }

    if (rows.isEmpty) return null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.symmetric(
            inside: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
          children: rows,
        ),
      ),
    );
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
