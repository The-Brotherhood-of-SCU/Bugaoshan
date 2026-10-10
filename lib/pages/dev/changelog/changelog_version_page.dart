import 'package:flutter/material.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/widgets/common/markdown_viewer.dart';

class ChangelogVersionPage extends StatelessWidget {
  final String version;
  final String? date;
  final String content;

  const ChangelogVersionPage({
    super.key,
    required this.version,
    this.date,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isUnreleased = version == 'Unreleased';
    final title = isUnreleased ? localizations.unreleased : version;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: MarkdownViewer(data: content),
    );
  }
}
