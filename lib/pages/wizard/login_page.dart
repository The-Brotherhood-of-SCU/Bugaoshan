import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/import_schedule_page.dart';
import 'package:bugaoshan/pages/scu_login_page.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authProvider = getIt<ScuAuthProvider>();
  final _courseProvider = getIt<CourseProvider>();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.wizardLoginTitle,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _ActionCard(
            icon: Icons.login_rounded,
            title: l10n.wizardLoginStep1,
            trailing: ListenableBuilder(
              listenable: _authProvider,
              builder: (context, _) {
                if (_authProvider.isLoggedIn) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(l10n.wizardLoginDone),
                    ],
                  );
                }
                return FilledButton.tonal(
                  onPressed: () async {
                    final result = await popupOrNavigate(
                      context,
                      const ScuLoginPage(),
                    );
                    if (result == true && mounted) {
                      setState(() {});
                    }
                  },
                  child: Text(l10n.wizardLoginButton),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _ActionCard(
            icon: Icons.download_rounded,
            title: l10n.wizardLoginStep2,
            subtitle: l10n.wizardImportHint,
            trailing: FilledButton.tonal(
              onPressed: () {
                popupOrNavigate(
                  context,
                  ImportSchedulePage(
                    courseProvider: _courseProvider,
                    mode: ImportMode.online,
                  ),
                );
              },
              child: Text(l10n.wizardImportButton),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;

  const _ActionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: textTheme.bodyLarge),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
