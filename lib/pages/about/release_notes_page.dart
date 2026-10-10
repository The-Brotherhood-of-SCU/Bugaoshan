import 'package:flutter/material.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/widgets/common/markdown_viewer.dart';

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
      body: MarkdownViewer(data: releaseNotes),
    );
  }
}
