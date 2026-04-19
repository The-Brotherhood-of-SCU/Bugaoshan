import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/about_page.dart';
import 'package:bugaoshan/pages/course_schedule_setting.dart';
import 'package:bugaoshan/pages/schedule_management_page.dart';
import 'package:bugaoshan/pages/scu_login_page.dart';
import 'package:bugaoshan/pages/software_setting_page.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/widgets/common/styled_widget.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

const _keyUsername = 'scu_saved_username';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = const FlutterSecureStorage();
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final username = await _storage.read(key: _keyUsername);
    if (mounted) {
      setState(() => _username = username);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = getIt<ScuAuthProvider>();
    final localizations = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: authProvider,
      builder: (context, _) {
        final isLoggedIn = authProvider.isLoggedIn;
        final isExpired = authProvider.isExpired;
        final loginStatusText = isLoggedIn
            ? localizations.loggedIn
            : isExpired
            ? localizations.loginSessionExpired
            : localizations.notLoggedIn;
        final body = Column(
          spacing: 16,
          children: [
            const SizedBox(height: 16),
            // 登录状态卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isLoggedIn
                              ? Theme.of(context).colorScheme.primaryContainer
                              : isExpired
                              ? Theme.of(context).colorScheme.tertiaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            isLoggedIn
                                ? Icons.person
                                : isExpired
                                ? Icons.access_time_filled
                                : Icons.person_outline,
                            color: isLoggedIn
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                : isExpired
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onTertiaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loginStatusText,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if (isLoggedIn)
                                Text(
                                  '${localizations.scuLogin}${_username != null ? ' ($_username)' : ''}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (isExpired)
                                Text(
                                  localizations.loginSessionExpiredDesc,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    isLoggedIn
                        ? TextButton(
                            onPressed: () => _confirmLogout(
                              context,
                              authProvider,
                              localizations,
                            ),
                            child: Text(localizations.logout),
                          )
                        : FilledButton.tonal(
                            onPressed: () => _openLogin(context),
                            child: Text(localizations.scuLogin),
                          ),
                  ],
                ),
              ),
            ),
            ButtonWithMaxWidth(
              icon: const Icon(Icons.list_alt),
              onPressed: () =>
                  popupOrNavigate(context, const ScheduleManagementPage()),
              child: Text(localizations.scheduleManagement),
            ),
            ButtonWithMaxWidth(
              icon: const Icon(Icons.schedule),
              onPressed: () =>
                  popupOrNavigate(context, CourseScheduleSetting()),
              child: Text(localizations.scheduleSetting),
            ),
            ButtonWithMaxWidth(
              icon: const Icon(Icons.settings),
              onPressed: () => popupOrNavigate(context, SoftwareSettingPage()),
              child: Text(localizations.softwareSetting),
            ),
            ButtonWithMaxWidth(
              icon: const Icon(Icons.info_outline),
              onPressed: () => popupOrNavigate(context, AboutPage()),
              child: Text(localizations.about),
            ),
          ],
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: body,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openLogin(BuildContext context) async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ScuLoginPage()));
    if (result == true && context.mounted) {
      _loadUsername();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录成功')));
    }
  }

  Future<void> _confirmLogout(
    BuildContext context,
    ScuAuthProvider provider,
    AppLocalizations localizations,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.confirmMessage),
        content: Text(localizations.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(localizations.logout),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.logout();
    }
  }
}
