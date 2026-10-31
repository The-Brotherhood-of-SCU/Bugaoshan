import 'dart:async';

import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:http/http.dart' as http;

const String _tag = 'GithubResourceService';

/// service 内请求失败的统一异常（含状态码），供消费方展示 / 记日志。
class GithubResourceException implements Exception {
  final int statusCode;
  final String url;

  const GithubResourceException(this.statusCode, this.url);

  @override
  String toString() =>
      'GitHub resource request failed: HTTP $statusCode ($url)';
}

/// GitHub 资源统一访问服务。
///
/// 按「网络代理」设置（[AppConfigProvider.useGithubProxy]）自动选择访问路径：
/// - 开启：先走 gh-proxy 镜像，请求失败 / 非 200 时自动回退直连；
/// - 关闭：严格直连，不使用镜像。
///
/// 消费方只提供原始 GitHub URL，不感知镜像与回退细节。fallback 只发生在
/// 请求 / 响应头阶段；一旦开始向消费方返回字节流，进度与取消由消费方处理，
/// 不再回退（因此与下载取消等消费方语义天然无交互）。
///
/// client 生命周期：注入的 client 由注入方管理，service 不关闭；未注入时
/// 惰性自建一个长生命周期 client——本服务以单例注册、与 app 同寿（与
/// CookieClient 的持有策略一致），也避免流式响应返回后无法安全 close。
class GithubResourceService {
  final bool Function() _useProxy;

  /// 测试注入 MockClient 用。
  final http.Client? _client;
  http.Client? _ownedClient;

  GithubResourceService({bool Function()? useProxy, http.Client? client})
      : _useProxy = useProxy ?? (() => true),
        _client = client;

  http.Client get _inner => _client ?? (_ownedClient ??= http.Client());

  /// 候选 URL 列表：开启 → [镜像, 直连]；关闭 → [直连]。
  List<Uri> _candidates(String url) {
    final direct = Uri.parse(url);
    if (!_useProxy()) return [direct];
    return [Uri.parse('$kGithubProxyPrefix$url'), direct];
  }

  /// GET 小资源（JSON 等）。逐候选尝试：网络异常 / 非 200 → 回退下一个候选。
  ///
  /// [timeout] 为**单次尝试**的超时（镜像与直连各自计时），供校历等短超时
  /// 场景。全部候选失败 → 抛最后一个异常。
  Future<http.Response> get(String url, {Duration? timeout}) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (final candidate in _candidates(url)) {
      try {
        var future = _inner.get(candidate);
        if (timeout != null) future = future.timeout(timeout);
        final response = await future;
        if (response.statusCode == 200) return response;
        lastError = GithubResourceException(response.statusCode, url);
        lastStackTrace = StackTrace.current;
      } catch (e, stackTrace) {
        lastError = e;
        lastStackTrace = stackTrace;
      }
      _logFallback(candidate, lastError);
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  /// 流式 GET（大文件下载）。响应头阶段做与 [get] 相同的候选回退；
  /// 非 200 → 抛 [GithubResourceException]。
  ///
  /// 返回后字节流交给消费方消费，进度与取消由消费方负责，service 不再回退。
  Future<http.StreamedResponse> getStreamed(String url) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (final candidate in _candidates(url)) {
      try {
        final response = await _inner.send(http.Request('GET', candidate));
        if (response.statusCode == 200) return response;
        // 非 200：主动排空错误响应体，释放底层连接供复用；排空失败忽略。
        unawaited(response.stream.drain<void>().then((_) {}, onError: (_) {}));
        lastError = GithubResourceException(response.statusCode, url);
        lastStackTrace = StackTrace.current;
      } catch (e, stackTrace) {
        lastError = e;
        lastStackTrace = stackTrace;
      }
      _logFallback(candidate, lastError);
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  void _logFallback(Uri failedCandidate, Object error) {
    AppLog.w(_tag, 'GitHub 资源请求失败，尝试下一候选 ${failedCandidate.host}: $error');
  }
}
