import 'package:bugaoshan/utils/compatibility.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/theme_shape.dart';

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
      body: Markdown(
        data: content,
        selectable: true,
        padding: const EdgeInsets.all(16),
        styleSheet: MarkdownStyleSheet.fromTheme(getLegacyThemeData(context))
            .copyWith(
              blockquoteDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppShapes.small),
              ),
            ),
      ),
    );
  }
}
