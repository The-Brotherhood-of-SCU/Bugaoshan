import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/auth/scu_login_page.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/utils/app_shapes.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

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
  const LoginStatusCard({super.key});

  @override
  State<LoginStatusCard> createState() => _LoginStatusCardState();
}

class _LoginStatusCardState extends State<LoginStatusCard> {
  static const _keyUsername = 'scu_saved_username';
  static const _storage = FlutterSecureStorage();

  final _authProvider = getIt<ScuAuthProvider>();
  String? _username;
  bool _privacyHidden = true;

  @override
  void initState() {
    super.initState();
    _authProvider.addListener(_onChanged);
    _loadUsername();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final username = await _storage.read(key: _keyUsername);
    if (mounted && username != _username) {
      setState(() => _username = username);
    }
  }

  Future<void> _onLogin() async {
    final result = await popupOrNavigate(context, const ScuLoginPage());
    if (!mounted) return;
    if (result == true) {
      _loadUsername();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录成功')));
    }
  }

  Future<void> _onLogout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmMessage),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _authProvider.logout();
    }
  }

  String _maskUsername(String username) {
    if (username.length <= 4) return '*' * username.length;
    return '${username.substring(0, 2)}${'*' * (username.length - 4)}${username.substring(username.length - 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final primaryColor = theme.colorScheme.primary;
    final status = LoginStatus.from(_authProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildAvatar(theme, primaryColor, status),
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
                        GestureDetector(
                          onTap: () =>
                              setState(() => _privacyHidden = !_privacyHidden),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${localizations.scuLogin}${_username != null ? ' (${_privacyHidden ? _maskUsername(_username!) : _username})' : ''}',
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
          _buildActionButton(theme, localizations, primaryColor, status),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, Color primaryColor, LoginStatus status) {
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
        borderRadius: BorderRadius.circular(AppShapes.medium),
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
    LoginStatus status,
  ) {
    return InkWell(
      onTap: status.isAutoLoggingIn
          ? null
          : status.isLoggedIn
          ? _onLogout
          : _onLogin,
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppShapes.largeIncreased),
      ),
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
