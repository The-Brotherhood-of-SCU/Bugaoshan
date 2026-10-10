import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:bugaoshan/widgets/adaptive/adaptive_glass_controls.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/auth/scu_login_page.dart';

class LoginRequiredWidget extends StatelessWidget {
  const LoginRequiredWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    void openLogin() {
      // 登录成功回到根导航器，避免平板弹窗误关整个功能页。
      Navigator.of(
        logicRootContext,
      ).push(MaterialPageRoute(builder: (_) => const ScuLoginPage()));
    }

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
            AdaptiveGlassButton(
              label: l10n.goToLogin,
              onPressed: openLogin,
              prominent: true,
              symbol: 'person.crop.circle',
              fallback: ElevatedButton.icon(
                onPressed: openLogin,
                icon: const Icon(Icons.person),
                label: Text(l10n.goToLogin),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
