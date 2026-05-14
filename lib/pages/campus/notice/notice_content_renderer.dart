part of 'campus_notice_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  Content extraction & HTML → Widget rendering (top-level functions)
// ═══════════════════════════════════════════════════════════════════════════════

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
  html = html.replaceAll(_scriptCallReg, '');

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

  if (parts.isEmpty) {
    final text = _normalizeText(_stripTags(innerHtml));
    if (text.isEmpty) return [];
    return [SelectableText(text, style: bodyStyle)];
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
