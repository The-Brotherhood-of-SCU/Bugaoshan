import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';

class ReleaseNotesPage extends StatelessWidget {
  final String version;
  final String releaseNotes;

  const ReleaseNotesPage({
    super.key,
    required this.version,
    required this.releaseNotes,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text('${localizations.releaseNotes} ($version)')),
      body: Markdown(
        data: releaseNotes,
        selectable: true,
        padding: const EdgeInsets.all(16),
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          blockquoteDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      ),
    );
  }
}
