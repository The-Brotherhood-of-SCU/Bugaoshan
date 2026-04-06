import 'package:flutter/material.dart';
import 'package:Bugaoshan/injection/injector.dart';
import 'package:Bugaoshan/l10n/app_localizations.dart';
import 'package:Bugaoshan/models/scu_user_info.dart';
import 'package:Bugaoshan/pages/about_page.dart';
import 'package:Bugaoshan/pages/course_schedule_setting.dart';
import 'package:Bugaoshan/pages/schedule_management_page.dart';
import 'package:Bugaoshan/pages/scu_login_page.dart';
import 'package:Bugaoshan/pages/software_setting_page.dart';
import 'package:Bugaoshan/providers/scu_auth_provider.dart';
import 'package:Bugaoshan/widgets/common/styled_widget.dart';
import 'package:Bugaoshan/widgets/route/router_utils.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = getIt<SCUAuthProvider>();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            spacing: 16,
            children: [
              const SizedBox(height: 16),
              _SCULoginCard(auth: _auth),
              ButtonWithMaxWidth(
                icon: const Icon(Icons.list_alt),
                onPressed: () =>
                    popupOrNavigate(context, const ScheduleManagementPage()),
                child: Text(l10n.scheduleManagement),
              ),
              ButtonWithMaxWidth(
                icon: const Icon(Icons.schedule),
                onPressed: () =>
                    popupOrNavigate(context, CourseScheduleSetting()),
                child: Text(l10n.scheduleSetting),
              ),
              ButtonWithMaxWidth(
                icon: const Icon(Icons.settings),
                onPressed: () =>
                    popupOrNavigate(context, SoftwareSettingPage()),
                child: Text(l10n.softwareSetting),
              ),
              ButtonWithMaxWidth(
                icon: const Icon(Icons.info_outline),
                onPressed: () => popupOrNavigate(context, AboutPage()),
                child: Text(l10n.about),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SCULoginCard extends StatelessWidget {
  final SCUAuthProvider auth;
  const _SCULoginCard({required this.auth});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([auth.status, auth.userInfo]),
      builder: (context, _) {
        final status = auth.status.value;
        final info = auth.userInfo.value;
        if (status == SCULoginStatus.loggedIn && info != null) {
          return _LoggedInCard(info: info, auth: auth);
        }
        return _LoggedOutCard(
          auth: auth,
          expired: status == SCULoginStatus.sessionExpired,
        );
      },
    );
  }
}

class _LoggedInCard extends StatelessWidget {
  final SCUUserInfo info;
  final SCUAuthProvider auth;
  const _LoggedInCard({required this.info, required this.auth});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Row(
              spacing: 12,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(info.photoUrl),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.majorName,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        info.majorCode,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.scuRefresh,
                  onPressed: () => auth.refreshUserInfo(),
                ),
                TextButton(
                  onPressed: () => auth.clearCredentials(),
                  child: Text(
                    l10n.scuLogout,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoggedOutCard extends StatelessWidget {
  final SCUAuthProvider auth;
  final bool expired;
  const _LoggedOutCard({required this.auth, required this.expired});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              spacing: 12,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.person_outline,
                    size: 28,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expired ? l10n.scuSessionExpired : l10n.scuNotLoggedIn,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (expired)
                        Text(
                          l10n.scuSessionExpiredHint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.error),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SCULoginPage())),
              child: Text(expired ? l10n.scuReLogin : l10n.scuLoginButton),
            ),
          ],
        ),
      ),
    );
  }
}
