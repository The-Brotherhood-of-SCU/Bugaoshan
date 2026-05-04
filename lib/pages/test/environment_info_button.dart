import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

class EnvironmentInfoButton extends StatelessWidget {
  final VoidCallback onPressed;
  const EnvironmentInfoButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(AppLocalizations.of(context)!.environmentInfo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onPressed,
      ),
    );
  }
}
