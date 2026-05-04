import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class WizardResetButton extends StatelessWidget {
  const WizardResetButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.auto_awesome),
        title: const Text('Reset Wizard Status'),
        subtitle: const Text('Set firstLaunchWizardCompleted to false'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          getIt<AppConfigProvider>().firstLaunchWizardCompleted.value = false;
          Navigator.of(logicRootContext).popUntil((route) => route.isFirst);
        },
      ),
    );
  }
}
