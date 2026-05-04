import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/about/about_page.dart';
import 'package:bugaoshan/pages/course/course_schedule_setting.dart';
import 'package:bugaoshan/pages/course/schedule_management_page.dart';
import 'package:bugaoshan/pages/auth/scu_login_page.dart';
import 'package:bugaoshan/pages/settings/software_setting_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/scu_microservice_auth_service.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

const _keyUsername = 'scu_saved_username';

class _LabelsNotifier extends ChangeNotifier {
  List<Map<String, dynamic>>? _labels;
  bool _loading = false;
  bool _error = false;

  List<Map<String, dynamic>>? get labels => _labels;
  bool get loading => _loading;
  bool get error => _error;
  bool get hasData => _labels != null;

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  set error(bool value) {
    _error = value;
    notifyListeners();
  }

  void setLabels(List<Map<String, dynamic>> labels) {
    _labels = labels;
    _error = false;
    notifyListeners();
  }

  void clear() {
    _labels = null;
    _error = false;
    _loading = false;
    notifyListeners();
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = const FlutterSecureStorage();
  String? _username;

  // Static ValueNotifier survives state rebuilds across tab switches
  static final _labelsNotifier = _LabelsNotifier();

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _labelsNotifier.addListener(_onLabelsChanged);
    if (!_labelsNotifier.hasData && !_labelsNotifier.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryFetchLabels());
    }
  }

  @override
  void dispose() {
    _labelsNotifier.removeListener(_onLabelsChanged);
    super.dispose();
  }

  void _onLabelsChanged() {
    if (mounted) setState(() {});
  }

  void _tryFetchLabels() {
    if (!mounted) return;
    final authProvider = getIt<ScuAuthProvider>();
    if (authProvider.isLoggedIn && !_labelsNotifier.loading) {
      _fetchUserLabels();
    }
  }

  Future<void> _loadUsername() async {
    final username = await _storage.read(key: _keyUsername);
    if (mounted) {
      setState(() => _username = username);
    }
  }

  Future<void> _fetchUserLabels() async {
    _labelsNotifier.loading = true;

    try {
      final authService = ScuMicroserviceAuthService();
      final client = await authService.getAuthenticatedClient();
      if (client == null) {
        _labelsNotifier.loading = false;
        return;
      }

      final resp = await client.get(
        Uri.parse('https://wfw.scu.edu.cn/mashupapp/wap/real/user'),
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': 'https://wfw.scu.edu.cn',
        },
      );

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (json['e'] == 0 && json['d']?['labels'] != null) {
        _labelsNotifier.setLabels(
          (json['d']['labels'] as List)
              .map((e) => e as Map<String, dynamic>)
              .toList(),
        );
      } else {
        _labelsNotifier.error = true;
      }
    } catch (e) {
      _labelsNotifier.error = true;
    }
    _labelsNotifier.loading = false;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = getIt<ScuAuthProvider>();
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: authProvider,
      builder: (context, _) {
        final isLoggedIn = authProvider.isLoggedIn;
        final isExpired = authProvider.isExpired;
        final isAutoLoggingIn = authProvider.isAutoLoggingIn;

        if (isLoggedIn && !_labelsNotifier.hasData && !_labelsNotifier.loading) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _tryFetchLabels());
        }
        final loginStatusText = isAutoLoggingIn
            ? localizations.autoLoggingIn
            : isLoggedIn
            ? localizations.loggedIn
            : isExpired
            ? localizations.loginSessionExpired
            : localizations.notLoggedIn;

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 登录状态卡片
                      _buildLoginStatusCard(
                        context,
                        theme,
                        isLoggedIn,
                        isExpired,
                        isAutoLoggingIn,
                        loginStatusText,
                        localizations,
                        authProvider,
                      ),
                      if (isLoggedIn) ...[
                        const SizedBox(height: 12),
                        _buildUserInfoCard(context, theme, localizations),
                      ],
                      const SizedBox(height: 12),
                      // 功能菜单
                      _buildMenuCard(context, theme, localizations),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoginStatusCard(
    BuildContext context,
    ThemeData theme,
    bool isLoggedIn,
    bool isExpired,
    bool isAutoLoggingIn,
    String loginStatusText,
    AppLocalizations localizations,
    ScuAuthProvider authProvider,
  ) {
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
                Container(
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
                ),
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
                          '${localizations.scuLogin}${_username != null ? ' ($_username)' : ''}',
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
          InkWell(
            onTap: isAutoLoggingIn
                ? null
                : isLoggedIn
                ? () => _confirmLogout(context, authProvider, localizations)
                : () => _openLogin(context),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
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
                      color: isLoggedIn
                          ? theme.colorScheme.error
                          : primaryColor,
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
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations localizations,
  ) {
    final primaryColor = theme.colorScheme.primary;

    Widget buildTile({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Widget? trailing,
    }) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              ?trailing,
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                size: 20,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          buildTile(
            icon: Icons.list_alt_rounded,
            label: localizations.scheduleManagement,
            onTap: () =>
                popupOrNavigate(context, const ScheduleManagementPage()),
          ),
          Divider(
            height: 1,
            indent: 56,
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
          buildTile(
            icon: Icons.schedule_rounded,
            label: localizations.scheduleSetting,
            onTap: () => popupOrNavigate(context, CourseScheduleSetting()),
          ),
          Divider(
            height: 1,
            indent: 56,
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
          buildTile(
            icon: Icons.settings_rounded,
            label: localizations.softwareSetting,
            onTap: () => popupOrNavigate(context, SoftwareSettingPage()),
          ),
          Divider(
            height: 1,
            indent: 56,
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: getIt<AppConfigProvider>().hasUpdateNotification,
            builder: (context, hasUpdate, _) {
              return buildTile(
                icon: Icons.info_outline_rounded,
                label: localizations.about,
                onTap: () => popupOrNavigate(context, AboutPage()),
                trailing: hasUpdate
                    ? Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations localizations,
  ) {
    final primaryColor = theme.colorScheme.primary;

    if (_labelsNotifier.loading) {
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              localizations.userInfoLoading,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_labelsNotifier.error) {
      return InkWell(
        onTap: _fetchUserLabels,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.08),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 20,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  localizations.userInfoLoadFailed,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                localizations.userInfoRetry,
                style: theme.textTheme.bodySmall?.copyWith(color: primaryColor),
              ),
            ],
          ),
        ),
      );
    }

    final labels = _labelsNotifier.labels;
    if (labels == null || labels.isEmpty) {
      return const SizedBox.shrink();
    }

    String localizeLabel(String apiName) {
      return switch (apiName) {
        '图书借阅量' => localizations.labelBookBorrowCount,
        '校园卡余额' => localizations.labelCampusCardBalance,
        '网费余额' => localizations.labelNetworkFeeBalance,
        _ => apiName,
      };
    }

    return InkWell(
      onTap: _fetchUserLabels,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: labels.map((label) {
              final apiName = label['name'] as String? ?? '';
              final name = localizeLabel(apiName);
              final value = label['value'];
              final valueStr = value is num
                  ? value.toString()
                  : value.toString();
              final isLast = label == labels.last;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 12),
                  child: Column(
                    children: [
                      Text(
                        valueStr,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _openLogin(BuildContext context) async {
    final result = await popupOrNavigate(context, const ScuLoginPage());
    if (result == true && context.mounted) {
      _loadUsername();
      _labelsNotifier.clear();
      _fetchUserLabels();
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
      _labelsNotifier.clear();
    }
  }
}
