part of 'campus_notice_page.dart';

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

enum _ElementType { paragraph, image, table }

class _ContentElement {
  final int offset;
  final String html;
  final _ElementType type;

  _ContentElement(this.offset, this.html, this.type);
}

class _InlineElement {
  final String text;
  final String? href;

  _InlineElement(this.text, this.href);
}

class _Range {
  final int start;
  final int end;

  _Range(this.start, this.end);
}
