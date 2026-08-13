import 'package:material_ui/material_ui.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/dev/changelog/changelog_page.dart';

class ChangelogTile extends StatelessWidget {
  const ChangelogTile({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(localizations.viewChangelog),
      subtitle: Text(
        localizations.viewChangelogSubtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChangelogPage())),
    );
  }
}
