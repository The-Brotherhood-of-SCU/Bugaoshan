part of 'campus_notice_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  Content extraction & HTML → Widget rendering (top-level functions)
// ═══════════════════════════════════════════════════════════════════════════════

Future<void> _confirmAndLaunchUrl(BuildContext context, String url) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.campusNoticesOpenInBrowser),
      content: Text(l10n.campusNoticesConfirmOpenLink(url)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.confirm),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

String? _extractContentHtml(String html) {
  final divMatch = _contentContainerReg.firstMatch(html);
  if (divMatch != null) {
    return _extractNestedDivContent(html, divMatch.end);
  }
  final articleMatch = _articleOpenReg.firstMatch(html);
  if (articleMatch != null) {
    const endTag = '</article>';
    final endIdx = html.indexOf(endTag, articleMatch.end);
    if (endIdx != -1) {
      return html.substring(articleMatch.end, endIdx);
    }
  }
  return null;
}

/// Regex matching SCU download links (download.jsp) or links whose text
/// ends with a common document file extension.
final _attachmentLinkReg = RegExp(
  r'<a[^>]+href="([^"]*)"[^>]*>([\s\S]*?)</a>',
  caseSensitive: false,
);

final _attachmentExtReg = RegExp(
  r'\.(docx?|xlsx?|pptx?|pdf|zip|rar|7z|txt|csv|rtf)$',
  caseSensitive: false,
);

/// Extracts attachment links from [contentHtml] and returns them as a list.
/// Removes the attachment paragraphs from [contentHtml] in-place (via return
/// of cleaned HTML) so they don't appear as plain text in the rendered content.
(String, List<_NoticeAttachment>) _extractAttachments(
  String contentHtml, {
  String? baseUrl,
}) {
  final attachments = <_NoticeAttachment>[];
  var html = contentHtml;

  // Match paragraphs that contain attachment links.
  // Pattern: 附件【<a href="...">text</a>】  or similar wrapping.
  final attachmentParaReg = RegExp(
    r'<p[^>]*>\s*附件[【\[]?\s*<a[^>]+href="([^"]*)"[^>]*>([\s\S]*?)</a>\s*[】\]]?\s*</p>',
    caseSensitive: false,
  );

  for (final match in attachmentParaReg.allMatches(html)) {
    final href = match.group(1)!;
    final label = _stripTags(match.group(2)!);
    if (label.isEmpty) continue;
    attachments.add(_NoticeAttachment(
      url: _normalizeNoticeUrl(href, baseUrl: baseUrl),
      text: label.trim(),
      fileName: label.trim(),
      noticeUrl: baseUrl ?? '',
    ));
  }
  // Remove matched attachment paragraphs.
  html = html.replaceAll(attachmentParaReg, '');

  // Also detect standalone <a> tags with download.jsp or file-extension links
  // that weren't caught by the paragraph pattern above.
  for (final match in _attachmentLinkReg.allMatches(html)) {
    final href = match.group(1) ?? '';
    final label = _stripTags(match.group(2)!);
    if (label.isEmpty) continue;
    final normalized = _normalizeNoticeUrl(href, baseUrl: baseUrl);
    // Skip if already collected.
    if (attachments.any((a) => a.url == normalized)) continue;
    final isDownload = href.contains('download.jsp') ||
        href.contains('downloadAttach') ||
        _attachmentExtReg.hasMatch(label);
    if (!isDownload) continue;
    attachments.add(_NoticeAttachment(
      url: normalized,
      text: label.trim(),
      fileName: label.trim(),
      noticeUrl: baseUrl ?? '',
    ));
  }

  return (html, attachments);
}

/// Extracts attachment links from the `<div class="fjxz">` (附件下载) section
/// that lives outside `vsb_content` on SCU notice pages.
List<_NoticeAttachment> _extractFjxzAttachments(String html, {String? baseUrl}) {
  final attachments = <_NoticeAttachment>[];
  final fjxzReg = RegExp(
    r"""<div[^>]+class=["']fjxz["'][^>]*>""",
    caseSensitive: false,
  );
  final fjxzMatch = fjxzReg.firstMatch(html);
  if (fjxzMatch == null) return attachments;

  // Extract the fjxz div content (non-greedy — it's a flat container).
  final contentReg = RegExp(
    r"""<div[^>]+class=["']fjxz["'][^>]*>([\s\S]*?)</div>""",
    caseSensitive: false,
  );
  final contentMatch = contentReg.firstMatch(html);
  if (contentMatch == null) return attachments;

  final content = contentMatch.group(1)!;
  for (final match in _attachmentLinkReg.allMatches(content)) {
    final href = match.group(1) ?? '';
    final label = _stripTags(match.group(2)!);
    if (label.isEmpty) continue;
    attachments.add(_NoticeAttachment(
      url: _normalizeNoticeUrl(href, baseUrl: baseUrl),
      text: label.trim(),
      fileName: label.trim(),
      noticeUrl: baseUrl ?? '',
    ));
  }
  return attachments;
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

List<Widget> _buildContentWidgets(BuildContext context, String html,
    {String? baseUrl}) {
  html = html.replaceAll(_clickCountReg, '');
  html = html.replaceAll(_prevNextReg, '');

  final widgets = <Widget>[];
  final bodyStyle = Theme.of(context).textTheme.bodyMedium;
  final linkStyle = bodyStyle?.copyWith(
    color: Theme.of(context).colorScheme.primary,
  );

  final tableRanges = <_Range>[];
  final tableElements = <_ContentElement>[];
  for (final match in _tableReg.allMatches(html)) {
    tableRanges.add(_Range(match.start, match.end));
    tableElements
        .add(_ContentElement(match.start, match.group(0)!, _ElementType.table));
  }

  bool insideTable(int offset) =>
      tableRanges.any((r) => offset >= r.start && offset < r.end);

  final elements = <_ContentElement>[];
  for (final match in _paragraphReg.allMatches(html)) {
    if (!insideTable(match.start)) {
      elements.add(_ContentElement(
          match.start, match.group(0)!, _ElementType.paragraph));
    }
  }
  // Some old pages use <div> instead of <p> for content paragraphs.
  // Only fall back to <div> matching when no <p> tags were found.
  if (elements.isEmpty) {
    final divReg = RegExp(r'<div[^>]*>([\s\S]*?)</div>', caseSensitive: false);
    for (final match in divReg.allMatches(html)) {
      if (!insideTable(match.start)) {
        elements.add(_ContentElement(
            match.start, match.group(0)!, _ElementType.paragraph));
      }
    }
  }
  for (final match in _imgReg.allMatches(html)) {
    if (!insideTable(match.start)) {
      elements
          .add(_ContentElement(match.start, match.group(0)!, _ElementType.image));
    }
  }
  elements.addAll(tableElements);
  elements.sort((a, b) => a.offset.compareTo(b.offset));

  final seenImages = <String>{};
  for (final element in elements) {
    switch (element.type) {
      case _ElementType.paragraph:
        final textWidgets = _parseParagraphContent(
          context,
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
        widgets.add(_buildNoticeImage(context, imageUrl));
        widgets.add(const SizedBox(height: 10));
      case _ElementType.table:
        final table = _buildNoticeTable(context, element.html);
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
  BuildContext context,
  String paragraphHtml,
  TextStyle? bodyStyle,
  TextStyle? linkStyle, {
  String? baseUrl,
}) {
  final pMatch = _paragraphReg.firstMatch(paragraphHtml);
  var innerHtml = pMatch?.group(1);
  // Fall back to <div> content for old pages that use <div> instead of <p>.
  innerHtml ??= RegExp(r'<div[^>]*>([\s\S]*?)</div>', caseSensitive: false)
          .firstMatch(paragraphHtml)
          ?.group(1) ??
      paragraphHtml;

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
    final href = _normalizeNoticeUrl(match.group(1)!, baseUrl: baseUrl);
    var label = _stripTags(match.group(2)!);
    if (label.isEmpty) {
      parts.add(_InlineElement(href, href));
    } else {
      // SCU's href attributes are often malformed (e.g. punycode + stray
      // chars) while the real URL is embedded in the label text.  Detect
      // bare URLs in the label and prefer them.
      final before = parts.length;
      _extractBareUrls(label, parts);
      if (before == parts.length) {
        // No bare URL found in label — use href attribute as fallback.
        parts.add(_InlineElement(label, href));
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
            ..onTap = () => _confirmAndLaunchUrl(context, part.href!),
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

Widget? _buildNoticeTable(BuildContext context, String tableHtml) {
  final rows = <TableRow>[];
  for (final rowMatch in _tableRowReg.allMatches(tableHtml)) {
    final cells = <Widget>[];
    for (final cellMatch in _tableCellReg.allMatches(rowMatch.group(1)!)) {
      var cellHtml = cellMatch.group(1) ?? '';
      cellHtml = cellHtml
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</p>\s*<p[^>]*>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '')
          .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n');

      // Check if the cell contains an image.
      final imgMatch = _imgReg.firstMatch(cellHtml);
      if (imgMatch != null) {
        final src = imgMatch.group(1)!;
        if (!src.startsWith('data:')) {
          final imageUrl = _normalizeNoticeUrl(src);
          cells.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: _buildNoticeImage(context, imageUrl),
            ),
          );
          continue;
        }
      }

      // Parse <a> tags so links remain clickable in table cells.
      final parts = <_InlineElement>[];
      var lastEnd = 0;
      for (final linkMatch in _linkReg.allMatches(cellHtml)) {
        if (linkMatch.start > lastEnd) {
          var text = _stripTags(cellHtml.substring(lastEnd, linkMatch.start));
          if (text.isNotEmpty) parts.add(_InlineElement(text, null));
        }
        final href = _normalizeNoticeUrl(linkMatch.group(1)!);
        var label = _stripTags(linkMatch.group(2)!);
        if (label.isEmpty) {
          parts.add(_InlineElement(href, href));
        } else {
          final before = parts.length;
          _extractBareUrls(label, parts);
          if (before == parts.length) {
            parts.add(_InlineElement(label, href));
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
                  ..onTap = () => _confirmAndLaunchUrl(context, part.href!),
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

  // Pad rows so every row has the same number of cells (Table requires it).
  final maxCells = rows.fold<int>(0, (m, r) => r.children.length > m ? r.children.length : m);
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (row.children.length < maxCells) {
      rows[i] = TableRow(
        decoration: row.decoration,
        children: [
          ...row.children,
          for (var j = row.children.length; j < maxCells; j++)
            const SizedBox.shrink(),
        ],
      );
    }
  }

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
