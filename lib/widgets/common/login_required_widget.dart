import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/auth/scu_login_page.dart';

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
            ElevatedButton.icon(
              onPressed: () {
                // 统一在根导航器打开登录页，与登录成功后 pop 根导航器语义对齐，
                // 避免平板/横屏弹窗场景下误关整个功能弹窗。
                Navigator.of(
                  logicRootContext,
                ).push(MaterialPageRoute(builder: (_) => const ScuLoginPage()));
              },
              icon: const Icon(Icons.person),
              label: Text(l10n.goToLogin),
            ),
          ],
        ),
      ),
    );
  }
}
