import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';

class LoginStatusCard extends StatelessWidget {
  final bool isLoggedIn;
  final bool isExpired;
  final bool isAutoLoggingIn;
  final String loginStatusText;
  final String? username;
  final ScuAuthProvider authProvider;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const LoginStatusCard({
    super.key,
    required this.isLoggedIn,
    required this.isExpired,
    required this.isAutoLoggingIn,
    required this.loginStatusText,
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
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
                        loginStatusText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isLoggedIn)
                        Text(
                          '${localizations.scuLogin}${username != null ? ' ($username)' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (isExpired)
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
        color: isAutoLoggingIn
            ? primaryColor.withValues(alpha: 0.08)
            : isLoggedIn
            ? primaryColor.withValues(alpha: 0.1)
            : isExpired
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: isAutoLoggingIn
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: primaryColor,
              ),
            )
          : Icon(
              isLoggedIn
                  ? Icons.person
                  : isExpired
                  ? Icons.access_time_filled
                  : Icons.person_outline,
              color: isLoggedIn
                  ? primaryColor
                  : isExpired
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
      onTap: isAutoLoggingIn
          ? null
          : isLoggedIn
          ? onLogout
          : onLogin,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            if (isAutoLoggingIn)
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
                isLoggedIn ? Icons.logout_rounded : Icons.login_rounded,
                color: isLoggedIn ? theme.colorScheme.error : primaryColor,
                size: 20,
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isAutoLoggingIn
                    ? localizations.autoLoggingIn
                    : isLoggedIn
                    ? localizations.logout
                    : localizations.scuLogin,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isAutoLoggingIn
                      ? theme.colorScheme.onSurfaceVariant
                      : isLoggedIn
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
