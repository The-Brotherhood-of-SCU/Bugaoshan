import 'package:flutter/material.dart';
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

class LoginStatusCard extends StatefulWidget {
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
  State<LoginStatusCard> createState() => _LoginStatusCardState();
}

class _LoginStatusCardState extends State<LoginStatusCard> {
  bool _privacyHidden = true;

  String _maskUsername(String username) {
    if (username.length <= 4) return '*' * username.length;
    return '${username.substring(0, 2)}${'*' * (username.length - 4)}${username.substring(username.length - 2)}';
  }

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
                        widget.status.displayText(localizations),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.status.isLoggedIn)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _privacyHidden = !_privacyHidden),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${localizations.scuLogin}${widget.username != null ? ' (${_privacyHidden ? _maskUsername(widget.username!) : widget.username})' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _privacyHidden
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      if (widget.status.isSessionExpired)
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
        color: widget.status.isAutoLoggingIn
            ? primaryColor.withValues(alpha: 0.08)
            : widget.status.isLoggedIn
            ? primaryColor.withValues(alpha: 0.1)
            : widget.status.isSessionExpired
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: widget.status.isAutoLoggingIn
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: primaryColor,
              ),
            )
          : Icon(
              widget.status.isLoggedIn
                  ? Icons.person
                  : widget.status.isSessionExpired
                  ? Icons.access_time_filled
                  : Icons.person_outline,
              color: widget.status.isLoggedIn
                  ? primaryColor
                  : widget.status.isSessionExpired
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
      onTap: widget.status.isAutoLoggingIn
          ? null
          : widget.status.isLoggedIn
          ? widget.onLogout
          : widget.onLogin,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            if (widget.status.isAutoLoggingIn)
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
                widget.status.isLoggedIn
                    ? Icons.logout_rounded
                    : Icons.login_rounded,
                color: widget.status.isLoggedIn
                    ? theme.colorScheme.error
                    : primaryColor,
                size: 20,
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.status.isAutoLoggingIn
                    ? localizations.autoLoggingIn
                    : widget.status.isLoggedIn
                    ? localizations.logout
                    : localizations.scuLogin,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: widget.status.isAutoLoggingIn
                      ? theme.colorScheme.onSurfaceVariant
                      : widget.status.isLoggedIn
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
