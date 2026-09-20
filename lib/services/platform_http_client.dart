import 'package:http/http.dart' as http;

import 'arkweb/arkweb_http_client.dart';
import 'arkweb/native_bridge.dart';

/// 显式选择客户端，不依赖 Flutter 回调可能离开的 Zone。
http.Client createPlatformHttpClient() =>
    isArkWebNativeAvailable ? ArkWebHttpClient() : http.Client();

/// 一次性请求的客户端生命周期，与 http.get 等快捷函数一致。
Future<T> withPlatformHttpClient<T>(
  Future<T> Function(http.Client client) action,
) async {
  final client = createPlatformHttpClient();
  try {
    return await action(client);
  } finally {
    client.close();
  }
}
