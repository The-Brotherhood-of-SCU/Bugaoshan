part of 'campus_notice_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  Content extraction & HTML → Widget rendering (top-level functions)
// ═══════════════════════════════════════════════════════════════════════════════

String? _extractContentHtml(String html) {
  String? contentHtml;
  final divMatch = _contentContainerReg.firstMatch(html);
  if (divMatch != null) {
    contentHtml = _extractNestedDivContent(html, divMatch.end);
  } else {
    final articleMatch = _articleOpenReg.firstMatch(html);
    if (articleMatch != null) {
      const endTag = '</article>';
      final endIdx = html.indexOf(endTag, articleMatch.end);
      if (endIdx != -1) {
        contentHtml = html.substring(articleMatch.end, endIdx);
      }
    }
  }

  return contentHtml;
}

String? _extractNestedDivContent(String html, int start) {
  var depth = 1;
  var i = start;
  final openDiv = RegExp(r'<div[\s>]', caseSensitive: false);
  const closeDiv = '</div>';

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

List<Widget> _buildContentWidgets(
  BuildContext context,
  String html, {
  String? baseUrl,
}) {
  // Remove inline script calls and known footer/pagination artifacts that
  // are not part of the article content.
  html = html.replaceAll(_scriptCallReg, '');
  // Remove click-count / view-count blocks such as: 访问量：<span...>...</span>
  html = html.replaceAll(
    RegExp(r'访问量[：:]?[\s\S]*?(</p>|</div>)', caseSensitive: false),
    '',
  );
  // Remove variations like "点击次数：123" or inline blocks that start with 点击次数
  html = html.replaceAll(
    RegExp(r'点击次数[：:]?[\s\S]*?(</p>|</div>)', caseSensitive: false),
    '',
  );
  html = html.replaceAll(RegExp(r'点击次数[：:]?\s*\d+', caseSensitive: false), '');
  // Remove "上一条/下一条/上一篇/下一篇" inline anchors that link to
  // adjacent articles — these are handled externally by the app, so strip
  // them from the rendered content to avoid duplication.
  html = html.replaceAll(
    RegExp(
      r'<a[^>]*>(?:\s|&nbsp;)*(?:上一条|下一条|上一篇|下一篇)(?:\s|&nbsp;)*</a>',
      caseSensitive: false,
    ),
    '',
  );
  // Remove surrounding pagination blocks (common structure on SCU site).
  html = html.replaceAll(
    RegExp(
      r'''<div[^>]+class=['"]?page['"]?[^>]*>[\s\S]*?</div>''',
      caseSensitive: false,
    ),
    '',
  );
  html = html.replaceAll(
    RegExp(r'<p>\s*<span>\s*(?:上一条|下一条)[\s\S]*?</p>', caseSensitive: false),
    '',
  );

  final widgets = <Widget>[];
  final bodyStyle = Theme.of(context).textTheme.bodyMedium;
  final linkStyle = bodyStyle?.copyWith(
    color: Theme.of(context).colorScheme.primary,
  );

  final tableRanges = <_Range>[];
  final tableElements = <_ContentElement>[];
  for (final match in _tableReg.allMatches(html)) {
    tableRanges.add(_Range(match.start, match.end));
    tableElements.add(
      _ContentElement(match.start, match.group(0)!, _ElementType.table),
    );
  }

  bool insideTable(int offset) =>
      tableRanges.any((r) => offset >= r.start && offset < r.end);

  final elements = <_ContentElement>[];
  for (final match in _paragraphReg.allMatches(html)) {
    if (!insideTable(match.start)) {
      elements.add(
        _ContentElement(match.start, match.group(0)!, _ElementType.paragraph),
      );
    }
  }
  for (final match in _imgReg.allMatches(html)) {
    if (!insideTable(match.start)) {
      elements.add(
        _ContentElement(match.start, match.group(0)!, _ElementType.image),
      );
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
        final imageUrl = _normalizeNoticeUrl(src, baseUrl: baseUrl);
        if (!seenImages.add(imageUrl)) continue;
        widgets.add(_buildNoticeImage(context, imageUrl));
        widgets.add(const SizedBox(height: 10));
      case _ElementType.table:
        final table = _buildNoticeTable(
          context,
          element.html,
          baseUrl: baseUrl,
        );
        if (table != null) {
          widgets.add(table);
          widgets.add(const SizedBox(height: 10));
        }
    }
  }

  if (widgets.isNotEmpty && widgets.last is SizedBox) {
    widgets.removeLast();
  }

  // Directly extract attachment links from the original page HTML and
  // append them as clickable rows. This handles cases where the fjxz
  // block or other attachment sections are outside the main content div.
  final attachmentLinks = _extractAttachmentLinks(
    context,
    html,
    baseUrl: baseUrl,
  );
  if (attachmentLinks.isNotEmpty) {
    widgets.add(const SizedBox(height: 12));
    widgets.addAll(attachmentLinks);
  }

  return widgets;
}

/// Scans [html] for `<a>` download links typically found in attachment
/// sections and returns clickable widgets for each one, keyed by label
/// to avoid duplicates.
List<Widget> _extractAttachmentLinks(
  BuildContext context,
  String html, {
  String? baseUrl,
}) {
  final widgets = <Widget>[];
  final seen = <String>{};
  final linkColor = Theme.of(context).colorScheme.primary;
  // Match any <a href="...">...</a> where the URL looks like a download
  // (contains /download/ or ends with a file extension).
  // The regex uses character-class alternatives for quoting to avoid
  // string-literal issues.
  final aReg = RegExp(
    r'''<a\s[^>]*?href=(["'])((?:[^"'/]*(?:/download/|\.(?:xlsx?|docx?|pdf|zip|rar))[^"' ]*))\1[^>]*>([\s\S]*?)</a>''',
    caseSensitive: false,
  );
  for (final match in aReg.allMatches(html)) {
    final rawHref = match.group(2) ?? '';
    if (rawHref.isEmpty) continue;
    final href = _normalizeNoticeUrl(rawHref, baseUrl: baseUrl);
    if (!seen.add(href)) continue;
    var label = _stripTags(match.group(3) ?? '');
    if (label.isEmpty) label = href;
    widgets.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: GestureDetector(
          onTap: () {
            try {
              launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
            } catch (_) {
              debugPrint('Failed to open attachment: $href');
            }
          },
          child: Row(
            children: [
              Icon(Icons.attach_file, size: 16, color: linkColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: linkColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  return widgets;
}

List<Widget> _parseParagraphContent(
  String paragraphHtml,
  TextStyle? bodyStyle,
  TextStyle? linkStyle, {
  String? baseUrl,
}) {
  final pMatch = _paragraphReg.firstMatch(paragraphHtml);
  var innerHtml = pMatch?.group(1) ?? paragraphHtml;

  innerHtml = innerHtml.replaceAll(
    RegExp(r'<br\s*/?>', caseSensitive: false),
    '\n',
  );

  final parts = <_InlineElement>[];
  var lastEnd = 0;
  for (final match in _linkReg.allMatches(innerHtml)) {
    if (match.start > lastEnd) {
      var text = _stripTags(innerHtml.substring(lastEnd, match.start));
      if (text.isNotEmpty) _extractBareUrls(text, parts);
    }
    // href may be captured in group(1) (double-quoted) or group(2) (single-quoted)
    final rawHref = match.group(1) ?? match.group(2) ?? '';
    final href = _normalizeNoticeUrl(rawHref, baseUrl: baseUrl);
    var label = _stripTags(match.group(3) ?? '');
    if (label.isEmpty) {
      parts.add(_InlineElement(href, href));
    } else {
      // SCU's href attributes are often malformed (e.g. punycode + stray
      // chars) while the real URL is embedded in the label text.  Detect
      // bare URLs in the label and prefer them.
      final before = parts.length;
      _extractBareUrls(label, parts);
      // If _extractBareUrls added at least one part with a real href,
      // those bare-URL parts replace the original link.  Otherwise
      // fall back to the href attribute.
      final hasBareUrl = parts
          .getRange(before, parts.length)
          .any((p) => p.href != null);
      if (!hasBareUrl) {
        // Either no new parts were added (before == parts.length) or
        // only plain-text parts were added — use href attribute instead.
        if (before == parts.length) {
          parts.add(_InlineElement(label, href));
        } else {
          // Undo the plain-text-only split and use href attribute.
          parts.length = before;
          parts.add(_InlineElement(label, href));
        }
      }
    }
    lastEnd = match.end;
  }
  if (lastEnd < innerHtml.length) {
    var text = _stripTags(innerHtml.substring(lastEnd));
    if (text.isNotEmpty) _extractBareUrls(text, parts);
  }

  if (parts.isEmpty) {
    var text = _normalizeText(_stripTags(innerHtml));
    if (text.isEmpty) return [];
    _extractBareUrls(text, parts);
    if (parts.isEmpty) return [SelectableText(text, style: bodyStyle)];
  }

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

  return [SelectableText.rich(TextSpan(children: spans, style: bodyStyle))];
}

Widget? _buildNoticeTable(
  BuildContext context,
  String tableHtml, {
  String? baseUrl,
}) {
  final rows = <TableRow>[];
  for (final rowMatch in _tableRowReg.allMatches(tableHtml)) {
    final cells = <Widget>[];
    for (final cellMatch in _tableCellReg.allMatches(rowMatch.group(1)!)) {
      var cellHtml = cellMatch.group(1) ?? '';
      cellHtml = cellHtml.replaceAll(
        RegExp(r'<br\s*/?>', caseSensitive: false),
        '\n',
      );

      // Parse <a> tags so links remain clickable in table cells.
      final parts = <_InlineElement>[];
      var lastEnd = 0;
      for (final linkMatch in _linkReg.allMatches(cellHtml)) {
        if (linkMatch.start > lastEnd) {
          var text = _stripTags(cellHtml.substring(lastEnd, linkMatch.start));
          if (text.isNotEmpty) parts.add(_InlineElement(text, null));
        }
        final rawHref = linkMatch.group(1) ?? linkMatch.group(2) ?? '';
        final href = _normalizeNoticeUrl(rawHref, baseUrl: baseUrl);
        var label = _stripTags(linkMatch.group(3) ?? '');
        if (label.isEmpty) {
          parts.add(_InlineElement(href, href));
        } else {
          final before = parts.length;
          _extractBareUrls(label, parts);
          final hasBareUrl = parts
              .getRange(before, parts.length)
              .any((p) => p.href != null);
          if (!hasBareUrl) {
            if (before == parts.length) {
              parts.add(_InlineElement(label, href));
            } else {
              parts.length = before;
              parts.add(_InlineElement(label, href));
            }
          }
        }
        lastEnd = linkMatch.end;
      }
      if (lastEnd < cellHtml.length) {
        var text = _stripTags(cellHtml.substring(lastEnd));
        if (text.isNotEmpty) _extractBareUrls(text, parts);
      }

      final bodyStyle = Theme.of(context).textTheme.bodySmall;
      final linkStyle = bodyStyle?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      );

      late Widget cellWidget;
      if (parts.isEmpty) {
        // No <a> tags — check for bare URLs
        var text = _stripTags(cellHtml);
        text = _normalizeText(text);
        _extractBareUrls(text, parts);
      }
      if (parts.isNotEmpty) {
        // Has links (from <a> tags or bare URLs) — rich text
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
        cellWidget = SelectableText.rich(
          TextSpan(children: spans, style: bodyStyle),
        );
      } else {
        final plainText = _normalizeText(_stripTags(cellHtml));
        cellWidget = Text(plainText, style: bodyStyle);
      }

      cells.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: cellWidget,
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.bold),
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
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
