import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

class LoginRequiredWidget extends StatelessWidget {
  const LoginRequiredWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(l10n.loginRequired, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            GlassButton.custom(
              onTap: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              width: 160,
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    l10n.goToLogin,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
