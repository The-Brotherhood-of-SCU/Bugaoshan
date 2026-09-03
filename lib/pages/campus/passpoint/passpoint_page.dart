import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/passpoint.dart';
import 'package:bugaoshan/providers/passpoint_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/widgets/common/info_row.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

/// 校园网无感认证（无感设备管理）入口页。
///
/// 对接后勤 newservice 平台的 passpoint 服务：查看/添加/取消无感设备，
/// 绑定设备 MAC 后接入校园网自动通过认证。认证依赖 [NewServiceAuth]
/// （独立于办事大厅的会话）。
class PasspointPage extends StatefulWidget {
  const PasspointPage({super.key});

  @override
  State<PasspointPage> createState() => _PasspointPageState();
}

class _PasspointPageState extends State<PasspointPage> {
  @override
  Widget build(BuildContext context) {
    final auth = getIt<ScuAuthProvider>();
    final provider = getIt<PasspointProvider>();

    return ListenableBuilder(
      listenable: Listenable.merge([auth, provider]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.passpointTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: provider.state == PasspointLoadState.loading
                    ? null
                    : provider.refresh,
                tooltip: l10n.refresh,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'passpoint_add',
            onPressed: _canInteract(auth, provider)
                ? () => _showAddSheet(context, provider, l10n)
                : null,
            icon: const Icon(Icons.add),
            label: Text(l10n.passpointAddDevice),
          ),
          body: _buildBody(l10n, auth, provider),
        );
      },
    );
  }

  bool _canInteract(ScuAuthProvider auth, PasspointProvider provider) =>
      auth.isLoggedIn &&
      provider.state == PasspointLoadState.loaded &&
      !provider.isAdding;

  Widget _buildBody(
    AppLocalizations l10n,
    ScuAuthProvider auth,
    PasspointProvider provider,
  ) {
    if (!auth.isLoggedIn) {
      return auth.isAutoLoggingIn
          ? const AutoLoginLoadingWidget()
          : const LoginRequiredWidget();
    }

    final hasDevices = provider.devices.isNotEmpty;
    if (provider.state == PasspointLoadState.idle ||
        (provider.state == PasspointLoadState.loading && !hasDevices)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.state == PasspointLoadState.error && !hasDevices) {
      return RetryableErrorWidget(
        errorType: provider.error ?? LoadErrorType.networkError,
        onRetry: provider.refresh,
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (provider.state == PasspointLoadState.error &&
              provider.error != null) ...[
            _buildRefreshErrorBanner(l10n, provider.error!, provider.refresh),
            const SizedBox(height: 16),
          ],
          if (provider.userInfo != null) ...[
            _buildUserInfoCard(l10n, provider.userInfo!),
            const SizedBox(height: 16),
          ],
          _buildDeviceListCard(l10n, provider),
          const SizedBox(height: 72), // 给 FAB 留出空间
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
    final message = error == LoadErrorType.sessionExpired
        ? l10n.sessionExpired
        : l10n.loadFailed;
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

  Widget _buildUserInfoCard(AppLocalizations l10n, PasspointUserInfo user) {
    return CardWithTitle(
      title: l10n.passpointUserInfo,
      icon: const Icon(Icons.person_outline),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow(label: l10n.nameLabel, value: user.userName),
            InfoRow(label: l10n.studentIdLabel, value: user.userId),
            if (user.userGroupName.isNotEmpty)
              InfoRow(
                label: l10n.passpointUserGroup,
                value: user.userGroupName,
              ),
            InfoRow(
              label: l10n.passpointAccountState,
              value: user.isOnline
                  ? l10n.passpointOnline
                  : l10n.passpointOffline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceListCard(
    AppLocalizations l10n,
    PasspointProvider provider,
  ) {
    return CardWithTitle(
      title: l10n.passpointMyDevices,
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
    PasspointDevice device,
    AppLocalizations l10n,
    PasspointProvider provider,
  ) {
    final isThisDevice =
        provider.isCancelling && provider.cancellingMac == device.userMac;
    final exitLabel = PasspointExit.all
        .where((e) => e.value == device.defaultServiceName)
        .map((e) => e.label)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.laptop_mac_outlined, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: device.isOnline
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        device.userMac,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.isOnline ? l10n.passpointOnline : l10n.passpointOffline}'
                  ' · ${l10n.passpointExpireTime}: '
                  '${_formatExpireTime(l10n, device.macExpireTime)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (exitLabel != null && exitLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.passpointExit}: $exitLabel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
            onPressed: provider.isCancelling
                ? null
                : () => _confirmCancel(device, l10n, provider),
            tooltip: l10n.passpointCancelAuth,
          ),
        ],
      ),
    );
  }

  /// 格式化设备到期时间。
  ///
  /// 服务端 `macExpireTime` 返回到期日期（`YYYY-MM-DD`）；
  /// `null`（无法解析，典型为"最长有效期 6 年"）时显示 [l10n.passpointExpireLongest]。
  String _formatExpireTime(AppLocalizations l10n, DateTime? expireTime) {
    if (expireTime == null) return l10n.passpointExpireLongest;
    return DateFormat('yyyy-MM-dd').format(expireTime);
  }

  Future<void> _confirmCancel(
    PasspointDevice device,
    AppLocalizations l10n,
    PasspointProvider provider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.passpointCancelAuth),
        content: Text(
          '${l10n.passpointCancelAuthConfirm}\n'
          '${l10n.passpointMac}: ${device.userMac}',
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

    final success = await provider.cancelDevice(device);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? l10n.passpointOperationSuccess
              : (provider.cancelErrorMessage ?? l10n.operationFailed),
        ),
        backgroundColor: success
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showAddSheet(
    BuildContext context,
    PasspointProvider provider,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AddDeviceSheet(provider: provider),
    );
  }
}

/// 添加无感设备弹窗。
///
/// 输入 MAC 地址（大写十六进制，如 `B8782EBDCE85`）、绑定有效期
/// （0-365 天，0 表示最长 6 年）与出口（默认校园网）。
class _AddDeviceSheet extends StatefulWidget {
  const _AddDeviceSheet({required this.provider});

  final PasspointProvider provider;

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _macController = TextEditingController();
  final _expireController = TextEditingController(text: '0');
  String _exitValue = '';
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _macController.dispose();
    _expireController.dispose();
    super.dispose();
  }

  String? _validateMac(String? value) {
    final mac = (value ?? '').trim().toUpperCase();
    if (mac.isEmpty) return _l10n.passpointMacRequired;
    // 12 位十六进制（无分隔符），如 B8782EBDCE85
    final valid = RegExp(r'^[0-9A-F]{12}$').hasMatch(mac);
    if (!valid) return _l10n.passpointMacInvalid;
    return null;
  }

  String? _validateExpire(String? value) {
    final expire = int.tryParse((value ?? '').trim());
    if (expire == null) return _l10n.passpointExpireRequired;
    if (expire < 0 || expire > 365) return _l10n.passpointExpireInvalid;
    return null;
  }

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // 在 async gap 之前捕获 navigator / messenger / l10n，
    // 避免 await 后使用 State.context 触发 use_build_context_synchronously。
    final l10n = _l10n;
    final navigator = Navigator.of(context);
    final rootMessenger = ScaffoldMessenger.of(logicRootContext);
    setState(() => _submitting = true);
    final success = await widget.provider.addDevice(
      userMac: _macController.text.trim().toUpperCase(),
      macExpireTime: int.parse(_expireController.text.trim()),
      defaultServiceName: _exitValue,
    );
    if (!mounted) return;
    if (success) {
      navigator.pop();
      rootMessenger.showSnackBar(
        SnackBar(content: Text(l10n.passpointOperationSuccess)),
      );
    } else {
      setState(() {
        _submitting = false;
        // 优先展示服务端返回的具体错误文案（如「MAC 已绑定」），
        // 让用户明白失败原因；无具体文案时退化为通用失败提示。
        _errorText = widget.provider.addErrorMessage ?? l10n.operationFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.passpointAddDevice,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _macController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                    LengthLimitingTextInputFormatter(12),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.passpointMac,
                    hintText: 'B8782EBDCE85',
                    border: const OutlineInputBorder(),
                  ),
                  validator: _validateMac,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _expireController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.passpointExpireTime,
                    helperText: l10n.passpointExpireHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: _validateExpire,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _exitValue,
                  decoration: InputDecoration(
                    labelText: l10n.passpointExit,
                    border: const OutlineInputBorder(),
                  ),
                  items: PasspointExit.all
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.value,
                          child: Text(e.label, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _exitValue = value ?? ''),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.passpointAddWarning,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppShapes.small),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorText!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.confirm),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
