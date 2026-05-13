import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/settings/add_widget/add_widget_page.dart';
import 'package:bugaoshan/widgets/common/third_center.dart';
import 'package:flutter/material.dart';

class WidgetPage extends StatelessWidget {
  const WidgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final body = ListView(
      shrinkWrap: true,
      children: [
        Text(
          l10n.wizardFeatureWidget,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.wizardFeatureWidgetDesc,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const AddWidgetContent(showDescription: false),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ThirdCenter(child: body),
    );
  }
}
