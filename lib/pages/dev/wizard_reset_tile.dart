import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

/// TestPage 入口：重置首启引导。
class WizardResetTile extends ConsumerWidget {
  const WizardResetTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.auto_awesome),
      title: Text(l10n.resetWizardTitle),
      subtitle: Text(l10n.resetWizardSubtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        ref
            .read(firstLaunchWizardCompletedSettingProvider.notifier)
            .update(false);
        if (logicRootContext.mounted) {
          Navigator.of(logicRootContext).popUntil((route) => route.isFirst);
        }
      },
    );
  }
}
