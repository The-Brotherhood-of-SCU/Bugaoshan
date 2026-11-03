import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bugaoshan/models/cloud_print.dart';
import 'package:bugaoshan/scu_backend/core/cookie_client.dart';
import 'package:bugaoshan/scu_backend/core/scu_auth.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/scu_backend/core/subsystem_auth.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/constants.dart';

const cloudPrintBaseUrl = 'http://202.115.54.240';
const cloudPrintPagePath = '/client/new/cprintPc/cprint.html';
const cloudPrintJobsPath = '/client/new/cprintPc/printDoc.html';

Map<String, dynamic> checkCloudPrintResponse(http.Response response) {
  if ([301, 302, 303, 401, 403].contains(response.statusCode)) {
    throw const UnauthenticatedException();
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ServiceException('云打印请求失败', statusCode: response.statusCode);
  }
  final Map<String, dynamic> body;
  try {
    body = decodeCloudPrintJson(response.body);
  } catch (_) {
    throw const ServiceException('云打印响应格式错误');
  }
  final code = body['code']?.toString();
  if (code == '4') throw const UnauthenticatedException();
  if (code != '0') throw const ServiceException('云打印服务未返回成功结果');
  return body;
}

/// 同一 cookie jar 完成 SSoPage JSON → libic/CAS → Auth/Check，不转发 SCU Bearer。
/// 懒加载，不加入登录后的全站预热，以免打印站故障影响其他校园功能。
class CloudPrintAuth extends ChangeNotifier implements SubsystemAuth {
  CloudPrintAuth(this._scu, {Uri? base})
    : base = base ?? Uri.parse(cloudPrintBaseUrl) {
    _scu.addListener(_onRootChanged);
  }
  static const _tag = 'CloudPrintAuth';
  final ScuAuth _scu;
  final Uri base;
  CookieClient? _cached, _last;
  String? _principal;
  Future<CookieClient>? _loginFuture;
  int _generation = 0;
  @override
  String get moduleId => 'cloudprint';
  @override
  List<SubsystemAuth> get dependencies => const [];
  bool isCurrent(CookieClient client) =>
      identical(client, _cached) &&
      _scu.isReady &&
      _principal == _scu.principal;
  void _onRootChanged() {
    if (!_scu.isReady || _principal != _scu.principal) invalidate();
  }

  @override
  void invalidate() {
    _generation++;
    _cached = null;
    _last = null;
    _loginFuture = null;
  }

  @override
  Future<void> ensureAuthenticated() async {
    await getClient();
  }

  Future<CookieClient> getClient() async {
    final client = await _scu.getClient();
    if (!identical(client, _last) || _principal != _scu.principal) {
      invalidate();
      _last = client;
      _principal = _scu.principal;
    }
    if (_cached != null) return _cached!;
    if (_loginFuture case final existing?) return existing;
    final generation = _generation;
    final task = _login(client, generation);
    _loginFuture = task;
    try {
      return await task;
    } finally {
      if (identical(_loginFuture, task)) _loginFuture = null;
    }
  }

  Future<http.Response> read(
    CookieClient client,
    String method,
    Uri uri,
  ) async {
    try {
      final stream = await client.sendOnce(
        http.Request(method, uri)
          ..headers.addAll({
            'User-Agent': kDefaultUserAgent,
            // SSO 跳转按网页导航协商响应，打印站 API 才请求 JSON。
            'Accept': uri.origin == base.origin && uri.path.startsWith('/api/')
                ? 'application/json'
                : 'text/html,application/xhtml+xml,*/*',
          }),
      );
      final response = await http.Response.fromStream(
        stream,
      ).timeout(kHttpTimeout);
      // 仅记录源站、路径和状态码；SSO 查询参数可能包含 CAS 票据。
      AppLog.d(
        _tag,
        '$method ${uri.host}${uri.path} -> ${response.statusCode}',
      );
      return response;
    } catch (_, stack) {
      AppLog.e(
        _tag,
        '云打印认证请求失败',
        error: const ServiceException('认证网络请求失败'),
        stackTrace: stack,
      );
      throw const ServiceException('云打印认证网络请求失败');
    }
  }

  Future<void> check(CookieClient client) async {
    final result = checkCloudPrintResponse(
      await read(client, 'POST', base.resolve('/api/client/Auth/Check')),
    );
    if (result['SessionId'] is! String ||
        (result['SessionId'] as String).isEmpty) {
      throw const UnauthenticatedException();
    }
  }

  bool _allowed(Uri uri) =>
      {'http', 'https'}.contains(uri.scheme) &&
      uri.hasAuthority &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      (uri.origin == base.origin ||
          (uri.scheme == 'https' &&
              uri.port == 443 &&
              {'libic.scu.edu.cn', 'id.scu.edu.cn'}.contains(uri.host)));

  Future<CookieClient> _login(CookieClient client, int generation) async {
    try {
      try {
        await check(client);
      } on UnauthenticatedException {
        final link = checkCloudPrintResponse(
          await read(
            client,
            'GET',
            base
                .resolve('/api/client/Auth/SSoPage')
                .replace(
                  queryParameters: {
                    'backurl': base.resolve(cloudPrintPagePath).toString(),
                  },
                ),
          ),
        );
        if (link['result'] is! String) {
          throw const ServiceException('云打印缺少登录链接');
        }
        Uri current;
        try {
          current = Uri.parse(link['result'] as String);
        } catch (_) {
          throw const ServiceException('云打印登录链接无效');
        }
        var complete = false;
        for (var hop = 0; hop < 12; hop++) {
          if (!_allowed(current)) throw const ServiceException('云打印认证跳转目标不受信任');
          final response = await read(client, 'GET', current);
          if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
            final location = response.headers['location'];
            if (location == null) throw const ServiceException('云打印认证跳转缺少地址');
            try {
              current = current.resolve(location);
            } catch (_) {
              throw const ServiceException('云打印认证跳转无效');
            }
          } else {
            if (response.statusCode != 200) {
              throw const ServiceException('云打印认证回跳失败');
            }
            complete = true;
            break;
          }
        }
        if (!complete) throw const ServiceException('云打印认证跳转过多');
        await check(client);
      }
      if (_generation != generation ||
          !_scu.isReady ||
          _principal != _scu.principal) {
        throw const UnauthenticatedException();
      }
      _cached = client;
      return client;
    } catch (_, stack) {
      AppLog.e(
        _tag,
        '云打印会话建立失败',
        error: const ServiceException('会话建立失败'),
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _scu.removeListener(_onRootChanged);
    super.dispose();
  }
}
