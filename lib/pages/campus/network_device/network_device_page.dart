import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/scu_microservice_auth_service.dart';

class NetworkDevicePage extends StatefulWidget {
  const NetworkDevicePage({super.key});

  @override
  State<NetworkDevicePage> createState() => _NetworkDevicePageState();
}

class _NetworkDevicePageState extends State<NetworkDevicePage> {
  static const _base = 'https://wfw.scu.edu.cn';

  final _authService = ScuMicroserviceAuthService();

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _userInfo;
  List<Map<String, dynamic>> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = getIt<ScuAuthProvider>();
    if (!auth.isLoggedIn) {
      setState(() => _error = 'notLoggedIn');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        setState(() {
          _loading = false;
          _error = 'authFailed';
        });
        return;
      }

      try {
        final userResp = await client.get(
          Uri.parse('$_base/uc/wap/user/get-info'),
          headers: _headers,
        );
        final userJson = _parseJson(userResp.body, 'get-info');
        if (userJson['e'] != 0) {
          throw Exception(userJson['m'] ?? '获取用户信息失败');
        }
        _userInfo = userJson['d']['base'] as Map<String, dynamic>;

        final deviceResp = await client.post(
          Uri.parse('$_base/netclient/wap/default/get-index'),
          headers: _headers,
        );
        final deviceJson = _parseJson(deviceResp.body, 'get-index');
        if (deviceJson['e'] != 0) {
          throw Exception(deviceJson['m'] ?? '获取设备信息失败');
        }
        _devices = (deviceJson['d']['list'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();

        if (mounted) {
          setState(() => _loading = false);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Network device load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'networkError';
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
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        _showSnackBar('认证失败', isError: true);
        return;
      }

      try {
        final resp = await client.post(
          Uri.parse('$_base/netclient/wap/default/offline'),
          headers: {
            ..._headers,
            'Content-Type': 'application/x-www-form-urlencoded', // 覆盖
          },
          body: 'device_id=${device['device_id']}&ip=${device['ip']}',
        );
        final json = _parseJson(resp.body, 'offline');
        if (json['e'] != 0) {
          debugPrint(json.toString());
          throw Exception(json['m'] ?? '操作失败');
        }
        _showSnackBar(l10n.networkDeviceOperationSuccess);
        _loadData();
      } finally {
        client.close();
      }
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
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36 Edg/147.0.0.0',
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      if (_error == 'notLoggedIn') {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.gradesLoginRequired, textAlign: TextAlign.center),
          ),
        );
      }
      return Center(
        child: GestureDetector(
          onTap: _loadData,
          child: SizedBox(
            width: 220,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 8),
                Text(
                  _getErrorMessage(l10n, _error!),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
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
            _infoRow('姓名', user?['realname'] ?? '-'),
            _infoRow('性别', user?['sex'] ?? '-'),
            _infoRow('学号', role?['number'] ?? '-'),
            _infoRow('身份', role?['identity'] ?? '-'),
            _infoRow('邮箱', user?['email'] ?? '-'),
            _infoRow('手机', user?['mobile'] ?? '-'),
            _infoRow('学院', departs?.values.join(', ') ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
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
                    style: TextStyle(
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

  String _getErrorMessage(AppLocalizations l10n, String errorKey) {
    switch (errorKey) {
      case 'networkError':
        return l10n.networkError;
      case 'ccylBindFailed':
        return l10n.ccylBindFailed;
      case 'ccylActivityLoadFailed':
        return l10n.ccylActivityLoadFailed;
      case 'campusNetworkRequired':
        return l10n.campusNetworkRequired;
      default:
        return l10n.loadFailed;
    }
  }
}
