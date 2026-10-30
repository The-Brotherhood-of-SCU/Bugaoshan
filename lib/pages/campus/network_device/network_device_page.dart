import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/campus/network_device_pods.dart';
import 'package:bugaoshan/providers/riverpod/campus/user_info_pods.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/widgets/common/info_row.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/utils/system_insets.dart';

class NetworkDevicePage extends ConsumerStatefulWidget {
  const NetworkDevicePage({super.key});

  @override
  ConsumerState<NetworkDevicePage> createState() => _NetworkDevicePageState();
}

class _NetworkDevicePageState extends ConsumerState<NetworkDevicePage> {
  bool _privacyHidden = true;

  LoadErrorType _mapError(Object error) {
    if (error is UnauthenticatedException) {
      return LoadErrorType.sessionExpired;
    }
    return campusNetworkErrorType(LoadErrorType.networkError);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(scuAuthProviderBridge);
    final asyncDevices = ref.watch(networkDevicesProvider);
    final offliningId = ref.watch(offliningDeviceIdProvider);
    final l10n = AppLocalizations.of(context)!;
    final isOfflining = offliningId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.networkDeviceQuery),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isOfflining
                ? null
                : () => ref.read(networkDevicesProvider.notifier).refresh(),
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: _buildBody(l10n, auth, asyncDevices, offliningId),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    dynamic auth,
    AsyncValue<List<Map<String, dynamic>>> asyncDevices,
    String? offliningId,
  ) {
    if (!auth.isLoggedIn) {
      return auth.isAutoLoggingIn
          ? const AutoLoginLoadingWidget()
          : const LoginRequiredWidget();
    }

    final hasDevices = (asyncDevices.value?.isNotEmpty ?? false);
    if (asyncDevices.isLoading && !hasDevices) {
      return const Center(child: CircularProgressIndicator());
    }
    if (asyncDevices.hasError && !hasDevices) {
      return RetryableErrorWidget(
        errorType: _mapError(asyncDevices.error!),
        onRetry: () => ref.read(networkDevicesProvider.notifier).refresh(),
      );
    }

    final devices = asyncDevices.value ?? const [];

    return RefreshIndicator(
      onRefresh: () => ref.read(networkDevicesProvider.notifier).refresh(),
      child: ListView(
        padding: withSystemBottomInset(context, const EdgeInsets.all(16)),
        children: [
          // 已有列表但刷新失败时，保留旧数据并给出可见的错误提示。
          if (asyncDevices.hasError && asyncDevices.error != null) ...[
            _buildRefreshErrorBanner(
              l10n,
              _mapError(asyncDevices.error!),
              () => ref.read(networkDevicesProvider.notifier).refresh(),
            ),
            const SizedBox(height: 16),
          ],
          _buildUserInfoCard(l10n),
          const SizedBox(height: 16),
          _buildDeviceListCard(l10n, devices, offliningId),
        ],
      ),
    );
  }

  Widget _buildRefreshErrorBanner(
    AppLocalizations l10n,
    LoadErrorType error,
    Future<void> Function() onRetry,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final message = refreshFailureMessage(
      error,
      l10n,
      fallback: l10n.loadFailed,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppShapes.small),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
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

  Widget _buildUserInfoCard(AppLocalizations l10n) {
    final userInfo = ref.watch(userInfoProvider);
    final user = userInfo.profile;
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
    List<Map<String, dynamic>> devices,
    String? offliningId,
  ) {
    final cardDuration = ref.watch(cardSizeAnimationDurationSettingProvider);

    return AnimatedSize(
      duration: cardDuration,
      curve: appCurve,
      alignment: Alignment.topCenter,
      child: CardWithTitle(
        title: l10n.networkDeviceOnlineDevices,
        icon: const Icon(Icons.devices_outlined),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (devices.isEmpty)
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
                ...devices.map(
                  (device) =>
                      _buildDeviceItem(device, l10n, offliningId),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceItem(
    Map<String, dynamic> device,
    AppLocalizations l10n,
    String? offliningId,
  ) {
    final deviceId = device['device_id']?.toString();
    final isOfflining = offliningId != null;
    final isThisDevice = isOfflining && offliningId == deviceId;
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
            onPressed: isOfflining
                ? null
                : () => _confirmForceOffline(device, l10n),
            tooltip: l10n.networkDeviceForceOffline,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmForceOffline(
    Map<String, dynamic> device,
    AppLocalizations l10n,
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

    final success = await ref
        .read(networkDevicesProvider.notifier)
        .forceOffline(device);
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
