import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';

enum LoginStatus {
  autoLoggingIn,
  loggedIn,
  sessionExpired,
  notLoggedIn;

  static LoginStatus from(ScuAuthProvider provider) {
    if (provider.isAutoLoggingIn) return LoginStatus.autoLoggingIn;
    if (provider.isLoggedIn) return LoginStatus.loggedIn;
    if (provider.isExpired && provider.accessToken != null) {
      return LoginStatus.sessionExpired;
    }
    return LoginStatus.notLoggedIn;
  }

  String displayText(AppLocalizations l10n) => switch (this) {
    LoginStatus.autoLoggingIn => l10n.autoLoggingIn,
    LoginStatus.loggedIn => l10n.loggedIn,
    LoginStatus.sessionExpired => l10n.loginSessionExpired,
    LoginStatus.notLoggedIn => l10n.notLoggedIn,
  };

  bool get isLoggedIn => this == LoginStatus.loggedIn;
  bool get isSessionExpired => this == LoginStatus.sessionExpired;
  bool get isAutoLoggingIn => this == LoginStatus.autoLoggingIn;
}

class LoginStatusCard extends StatelessWidget {
  final LoginStatus status;
  final String? username;
  final ScuAuthProvider authProvider;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const LoginStatusCard({
    super.key,
    required this.status,
    this.username,
    required this.authProvider,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final primaryColor = theme.colorScheme.primary;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildAvatar(theme, primaryColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.displayText(localizations),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (status.isLoggedIn)
                        Text(
                          '${localizations.scuLogin}${username != null ? ' ($username)' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (status.isSessionExpired)
                        Text(
                          localizations.loginSessionExpiredDesc,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.08)),
          _buildActionButton(theme, localizations, primaryColor),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, Color primaryColor) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: status.isAutoLoggingIn
            ? primaryColor.withValues(alpha: 0.08)
            : status.isLoggedIn
            ? primaryColor.withValues(alpha: 0.1)
            : status.isSessionExpired
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: status.isAutoLoggingIn
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: primaryColor,
              ),
            )
          : Icon(
              status.isLoggedIn
                  ? Icons.person
                  : status.isSessionExpired
                  ? Icons.access_time_filled
                  : Icons.person_outline,
              color: status.isLoggedIn
                  ? primaryColor
                  : status.isSessionExpired
                  ? theme.colorScheme.onTertiaryContainer
                  : theme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
    );
  }

  Widget _buildActionButton(
    ThemeData theme,
    AppLocalizations localizations,
    Color primaryColor,
  ) {
    return InkWell(
      onTap: status.isAutoLoggingIn
          ? null
          : status.isLoggedIn
          ? onLogout
          : onLogin,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            if (status.isAutoLoggingIn)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Icon(
                status.isLoggedIn ? Icons.logout_rounded : Icons.login_rounded,
                color: status.isLoggedIn
                    ? theme.colorScheme.error
                    : primaryColor,
                size: 20,
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                status.isAutoLoggingIn
                    ? localizations.autoLoggingIn
                    : status.isLoggedIn
                    ? localizations.logout
                    : localizations.scuLogin,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: status.isAutoLoggingIn
                      ? theme.colorScheme.onSurfaceVariant
                      : status.isLoggedIn
                      ? theme.colorScheme.error
                      : primaryColor,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
