import 'dart:convert';

import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/auth/scu_login_page.dart';
import 'package:bugaoshan/pages/profile/login_status_card.dart';
import 'package:bugaoshan/pages/profile/profile_labels_notifier.dart';
import 'package:bugaoshan/pages/profile/profile_menu_card.dart';
import 'package:bugaoshan/pages/profile/user_info_card.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/scu_microservice_auth_service.dart';
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

  // Static ValueNotifier survives state rebuilds across tab switches
  static final _labelsNotifier = ProfileLabelsNotifier();

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

  @override
  Widget build(BuildContext context) {
    final authProvider = getIt<ScuAuthProvider>();
    final localizations = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: authProvider,
      builder: (context, _) {
        final isLoggedIn = authProvider.isLoggedIn;
        final isExpired = authProvider.isExpired;
        final isAutoLoggingIn = authProvider.isAutoLoggingIn;

        if (isLoggedIn &&
            !_labelsNotifier.hasData &&
            !_labelsNotifier.loading) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _tryFetchLabels(),
          );
        }
        final loginStatusText = isAutoLoggingIn
            ? localizations.autoLoggingIn
            : isLoggedIn
            ? localizations.loggedIn
            : isExpired
            ? localizations.loginSessionExpired
            : localizations.notLoggedIn;

        final loginStatusCard = LoginStatusCard(
          isLoggedIn: isLoggedIn,
          isExpired: isExpired,
          isAutoLoggingIn: isAutoLoggingIn,
          loginStatusText: loginStatusText,
          username: _username,
          authProvider: authProvider,
          onLogin: () => _openLogin(context),
          onLogout: () => _confirmLogout(context, authProvider, localizations),
        );

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
                      loginStatusCard,

                      const SizedBox(height: 12),
                      AnimatedSize(
                        duration:
                            appConfigService.cardSizeAnimationDuration.value,
                        curve: appCurve,
                        child: UserInfoCard(
                          isLoggedIn: isLoggedIn,
                          labelsNotifier: _labelsNotifier,
                          onRetry: _fetchUserLabels,
                        ),
                      ),

                      const SizedBox(height: 12),
                      const ProfileMenuCard(),
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
}
