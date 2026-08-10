import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/network_device_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/user_info_provider.dart';
import 'package:bugaoshan/widgets/common/info_row.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';

class NetworkDevicePage extends StatefulWidget {
  const NetworkDevicePage({super.key});

  @override
  State<NetworkDevicePage> createState() => _NetworkDevicePageState();
}

class _NetworkDevicePageState extends State<NetworkDevicePage> {
  bool _privacyHidden = true;

  @override
  void initState() {
    super.initState();
    // Provider 会在 WFW SSO 就绪后自动补拉；这里覆盖页面首次打开时
    // 已有 WFW 会话的场景，不持有任何远端数据。
    Future.microtask(() => getIt<NetworkDeviceProvider>().ensureDevices());
  }

  @override
  Widget build(BuildContext context) {
    final auth = getIt<ScuAuthProvider>();
    final userInfo = getIt<UserInfoProvider>();
    final devices = getIt<NetworkDeviceProvider>();
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: Listenable.merge([auth, userInfo, devices]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(l10n.networkDeviceQuery),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: devices.isOfflining ? null : devices.refresh,
              tooltip: l10n.refresh,
            ),
          ],
        ),
        body: _buildBody(l10n, auth, userInfo, devices),
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    ScuAuthProvider auth,
    UserInfoProvider userInfo,
    NetworkDeviceProvider devices,
  ) {
    if (!auth.isLoggedIn) {
      return auth.isAutoLoggingIn
          ? const AutoLoginLoadingWidget()
          : const LoginRequiredWidget();
    }

    final hasDevices = devices.devices.isNotEmpty;
    if (devices.state == NetworkDeviceLoadState.idle ||
        (devices.state == NetworkDeviceLoadState.loading && !hasDevices)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (devices.state == NetworkDeviceLoadState.error && !hasDevices) {
      return RetryableErrorWidget(
        errorType: devices.error ?? LoadErrorType.networkError,
        onRetry: devices.refresh,
      );
    }

    return RefreshIndicator(
      onRefresh: devices.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUserInfoCard(l10n, userInfo.profile),
          const SizedBox(height: 16),
          _buildDeviceListCard(l10n, devices),
        ],
      ),
    );
  }

  String _maskText(String text, {int visibleStart = 1, int visibleEnd = 0}) {
    if (text.length <= visibleStart + visibleEnd) return '*' * text.length;
    final start = text.substring(0, visibleStart);
    final end = visibleEnd > 0 ? text.substring(text.length - visibleEnd) : '';
    final masked = '*' * (text.length - visibleStart - visibleEnd);
    return '$start$masked$end';
  }

  Widget _buildPrivacyRow(
    String label,
    String value, {
    int visibleStart = 1,
    int visibleEnd = 0,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _privacyHidden = !_privacyHidden),
      child: _infoRow(
        label,
        _privacyHidden
            ? _maskText(
                value,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
              )
            : value,
        trailing: Icon(
          _privacyHidden
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(AppLocalizations l10n, Map<String, dynamic>? user) {
    final role = user?['role'] as Map<String, dynamic>?;
    final departs = user?['departs'] as Map<String, dynamic>?;

    return CardWithTitle(
      title: l10n.networkDeviceUserInfo,
      icon: const Icon(Icons.person_outline),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPrivacyRow(l10n.nameLabel, _valueOf(user?['realname'])),
            _infoRow(l10n.sexLabel, _valueOf(user?['sex'])),
            _buildPrivacyRow(
              l10n.studentIdLabel,
              _valueOf(role?['number']),
              visibleStart: 2,
              visibleEnd: 2,
            ),
            _infoRow(l10n.identityLabel, _valueOf(role?['identity'])),
            _buildPrivacyRow(l10n.emailLabel, _valueOf(user?['email'])),
            _buildPrivacyRow(
              l10n.phoneLabel,
              _valueOf(user?['mobile']),
              visibleStart: 3,
              visibleEnd: 2,
            ),
            _infoRow(
              l10n.collegeLabel,
              departs == null ? '-' : departs.values.join(', '),
            ),
          ],
        ),
      ),
    );
  }

  String _valueOf(Object? value) => value?.toString() ?? '-';

  Widget _infoRow(String label, String value, {Widget? trailing}) {
    return InfoRow(label: label, value: value, trailing: trailing);
  }

  Widget _buildDeviceListCard(
    AppLocalizations l10n,
    NetworkDeviceProvider provider,
  ) {
    return CardWithTitle(
      title: l10n.networkDeviceOnlineDevices,
      icon: const Icon(Icons.devices_outlined),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (provider.devices.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.noData,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...provider.devices.map(
                (device) => _buildDeviceItem(device, l10n, provider),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceItem(
    Map<String, dynamic> device,
    AppLocalizations l10n,
    NetworkDeviceProvider provider,
  ) {
    final deviceId = device['device_id']?.toString();
    final isThisDevice =
        provider.isOfflining && provider.offliningDeviceId == deviceId;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.router_outlined, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.networkDeviceDeviceId}: ${_valueOf(deviceId)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.networkDeviceIp}: ${_valueOf(device['ip'])}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: isThisDevice
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.power_settings_new_outlined),
            onPressed: provider.isOfflining
                ? null
                : () => _confirmForceOffline(device, l10n, provider),
            tooltip: l10n.networkDeviceForceOffline,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmForceOffline(
    Map<String, dynamic> device,
    AppLocalizations l10n,
    NetworkDeviceProvider provider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.networkDeviceForceOffline),
        content: Text(
          '${l10n.networkDeviceConfirmOffline}\n'
          'ID: ${_valueOf(device['device_id'])}\n'
          'IP: ${_valueOf(device['ip'])}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final success = await provider.forceOffline(device);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? l10n.networkDeviceOperationSuccess
              : l10n.networkOfflineFailed,
        ),
        backgroundColor: success
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
      ),
    );
  }
}
