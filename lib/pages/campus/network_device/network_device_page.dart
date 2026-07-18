import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/api_request.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/wfw_auth.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/info_row.dart';

class NetworkDevicePage extends StatefulWidget {
  const NetworkDevicePage({super.key});

  @override
  State<NetworkDevicePage> createState() => _NetworkDevicePageState();
}

class _NetworkDevicePageState extends State<NetworkDevicePage> {
  static const _base = 'https://wfw.scu.edu.cn';

  bool _loading = false;
  LoadErrorType? _error;
  Map<String, dynamic>? _userInfo;
  List<Map<String, dynamic>> _devices = [];
  bool _privacyHidden = true;

  @override
  void initState() {
    super.initState();
    getIt<ScuAuthProvider>().addListener(_onAuthChanged);
    getIt<WfwAuth>().addListener(_onWfwAuthChanged);
    _loadData();
  }

  @override
  void dispose() {
    getIt<ScuAuthProvider>().removeListener(_onAuthChanged);
    getIt<WfwAuth>().removeListener(_onWfwAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = getIt<ScuAuthProvider>();
    if (auth.isLoggedIn && mounted) {
      _loadData();
    } else if (mounted) {
      setState(() {});
    }
  }

  void _onWfwAuthChanged() {
    if (getIt<WfwAuth>().isReady && mounted) {
      _loadData();
    }
  }

  /// 通过 WfwAuth 发送带自动重试的请求。
  ///
  /// 自动处理两种认证失败：
  /// - [UnauthenticatedException]：SCU token 过期（由 auth 层抛出，
  ///   getClient 内部触发续期）
  /// - 微服务 session 过期（业务响应 e == 10013，见 [_throwIfSessionExpired]）：
  ///   invalidate 后重新预热 wfw session 并重试一次
  Future<T> _wfwRequest<T>(Future<T> Function(CookieClient client) fn) {
    final wfwAuth = getIt<WfwAuth>();
    return retryOnUnauthenticated(
      wfwAuth.getClient,
      fn,
      invalidate: wfwAuth.invalidate,
    );
  }

  /// 微服务 session 失效（e == 10013）时抛 [UnauthenticatedException]，
  /// 交给 [_wfwRequest] 触发重新认证 + 重试。
  void _throwIfSessionExpired(Map<String, dynamic> json) {
    if (json['e'] == 10013 || json['e']?.toString() == '10013') {
      throw const UnauthenticatedException('微服务登录已失效');
    }
  }

  Future<void> _loadData() async {
    final auth = getIt<ScuAuthProvider>();
    if (!auth.isLoggedIn) {
      if (auth.isAutoLoggingIn) return;
      setState(() => _error = LoadErrorType.notLoggedIn);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // _wfwRequest 内部通过 WfwAuth.getClient 确保 wfw session 已预热，
      // session 过期时自动重新认证并重试一次，无需在此等待 isReady。
      await _wfwRequest((client) async {
        final userResp = await client.get(
          Uri.parse('$_base/uc/wap/user/get-info'),
          headers: _headers,
        );
        final userJson = _parseJson(userResp.body, 'get-info');
        _throwIfSessionExpired(userJson);
        if (userJson['e'] != 0) {
          throw Exception(userJson['m'] ?? '获取用户信息失败');
        }
        _userInfo = userJson['d']['base'] as Map<String, dynamic>;

        final deviceResp = await client.post(
          Uri.parse('$_base/netclient/wap/default/get-index'),
          headers: _headers,
        );
        final deviceJson = _parseJson(deviceResp.body, 'get-index');
        _throwIfSessionExpired(deviceJson);
        if (deviceJson['e'] != 0) {
          throw Exception(deviceJson['m'] ?? '获取设备信息失败');
        }
        _devices = (deviceJson['d']['list'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      });
      if (mounted) {
        setState(() => _loading = false);
      }
    } on UnauthenticatedException catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = LoadErrorType.notLoggedIn;
        });
      }
    } catch (e) {
      debugPrint('Network device load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = LoadErrorType.networkError;
        });
      }
    }
  }

  Future<void> _forceOffline(Map<String, dynamic> device) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.networkDeviceForceOffline),
        content: Text(
          '${AppLocalizations.of(context)!.networkDeviceConfirmOffline}\n'
          'ID: ${device['device_id']}\n'
          'IP: ${device['ip']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _wfwRequest((client) async {
        final resp = await client.post(
          Uri.parse('$_base/netclient/wap/default/offline'),
          headers: {
            ..._headers,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: 'device_id=${device['device_id']}&ip=${device['ip']}',
        );
        final json = _parseJson(resp.body, 'offline');
        _throwIfSessionExpired(json);
        if (json['e'] != 0) {
          debugPrint(json.toString());
          throw Exception(json['m'] ?? '操作失败');
        }
      });
      _showSnackBar(l10n.networkDeviceOperationSuccess);
      _loadData();
    } on UnauthenticatedException catch (_) {
      _showSnackBar(l10n.networkOfflineFailed, isError: true);
    } catch (e) {
      debugPrint('Force offline error: $e');
      _showSnackBar(l10n.networkOfflineFailed, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json, text/plain, */*',
    'Accept-Encoding': 'gzip, deflate, br, zstd',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Content-Type': 'application/json; charset=UTF-8',
    'Origin': 'https://wfw.scu.edu.cn',
    'Pragma': 'no-cache',
    'Referer': _base,
    'User-Agent': kDefaultUserAgent,
    'X-Requested-With': 'XMLHttpRequest',
    'sec-ch-ua':
        '"Microsoft Edge";v="147", "Not.A/Brand";v="8", "Chromium";v="147"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
  };

  Map<String, dynamic> _parseJson(String body, String api) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('[$api] JSON 解析失败: $body');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.networkDeviceQuery),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final auth = getIt<ScuAuthProvider>();
    if (!auth.isLoggedIn && auth.isAutoLoggingIn) {
      return const AutoLoginLoadingWidget();
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      if (_error == LoadErrorType.notLoggedIn) {
        if (getIt<ScuAuthProvider>().isAutoLoggingIn) {
          return const AutoLoginLoadingWidget();
        }
        return const LoginRequiredWidget();
      }
      return RetryableErrorWidget(errorType: _error!, onRetry: _loadData);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUserInfoCard(l10n),
          const SizedBox(height: 16),
          _buildDeviceListCard(l10n),
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
    final user = _userInfo;
    final role = user?['role'] as Map<String, dynamic>?;
    final departs = user?['departs'] as Map<String, dynamic>?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.networkDeviceUserInfo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildPrivacyRow('姓名', user?['realname'] ?? '-'),
            _infoRow('性别', user?['sex'] ?? '-'),
            _buildPrivacyRow(
              '学号',
              role?['number'] ?? '-',
              visibleStart: 2,
              visibleEnd: 2,
            ),
            _infoRow('身份', role?['identity'] ?? '-'),
            _buildPrivacyRow('邮箱', user?['email'] ?? '-'),
            _buildPrivacyRow(
              '手机',
              user?['mobile'] ?? '-',
              visibleStart: 3,
              visibleEnd: 2,
            ),
            _infoRow('学院', departs?.values.join(', ') ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Widget? trailing}) {
    return InfoRow(label: label, value: value, trailing: trailing);
  }

  Widget _buildDeviceListCard(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.devices_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.networkDeviceOnlineDevices,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_devices.isEmpty)
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
              ...(_devices.map((device) => _buildDeviceItem(device, l10n))),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceItem(Map<String, dynamic> device, AppLocalizations l10n) {
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
                  '${l10n.networkDeviceDeviceId}: ${device['device_id'] ?? '-'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.networkDeviceIp}: ${device['ip'] ?? '-'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new_outlined),
            onPressed: () => _forceOffline(device),
            tooltip: l10n.networkDeviceForceOffline,
          ),
        ],
      ),
    );
  }
}
