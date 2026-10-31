import 'package:bugaoshan/services/github_resource_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _directUrl =
    'https://raw.githubusercontent.com/The-Brotherhood-of-SCU/Bugaoshan/main/assets/academic_calendar.json';
const String _mirrorUrlPrefix = 'https://gh-proxy.org/';
const String _okBody = '{"semesters":[]}';

/// 追踪 close() 调用，验证注入的 client 生命周期由注入方管理。
class _TrackingClient extends http.BaseClient {
  _TrackingClient(this._inner);

  final http.Client _inner;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool useGithubProxy;

  /// 构造 service + 请求 URL 记录列表。[respond] 按请求 URL 决定响应；
  /// 返回 null 表示模拟网络异常。
  (GithubResourceService, List<String>) buildService(
    http.Response? Function(Uri url)? respond,
  ) {
    final requestedUrls = <String>[];
    final client = MockClient((request) async {
      requestedUrls.add(request.url.toString());
      final response = respond?.call(request.url);
      if (response == null) throw Exception('network down');
      return response;
    });
    return (
      GithubResourceService(useProxy: () => useGithubProxy, client: client),
      requestedUrls,
    );
  }

  setUp(() {
    useGithubProxy = true;
  });

  group('get · 开启 GitHub 加速', () {
    test('镜像成功时只请求镜像一次', () async {
      final (service, urls) = buildService((_) => http.Response(_okBody, 200));

      final response = await service.get(_directUrl);

      expect(response.statusCode, 200);
      expect(urls, [_mirrorUrlPrefix + _directUrl]);
    });

    test('镜像非 200 时自动回退直连', () async {
      final (service, urls) = buildService((url) {
        if (url.host == 'gh-proxy.org') {
          return http.Response('mirror error', 502);
        }
        return http.Response(_okBody, 200);
      });

      final response = await service.get(_directUrl);

      expect(response.statusCode, 200);
      expect(urls, [_mirrorUrlPrefix + _directUrl, _directUrl]);
    });

    test('镜像网络异常时自动回退直连', () async {
      final (service, urls) = buildService((url) {
        if (url.host == 'gh-proxy.org') return null;
        return http.Response(_okBody, 200);
      });

      final response = await service.get(_directUrl);

      expect(response.body, _okBody);
      expect(urls, [_mirrorUrlPrefix + _directUrl, _directUrl]);
    });

    test('全部候选失败时抛最后一个异常', () async {
      final (service, urls) = buildService((url) {
        if (url.host == 'gh-proxy.org') return http.Response('bad', 502);
        return http.Response('worse', 503);
      });

      await expectLater(
        service.get(_directUrl),
        throwsA(isA<GithubResourceException>()),
      );
      expect(urls, [_mirrorUrlPrefix + _directUrl, _directUrl]);
    });

    test('单次尝试超时各自计时：镜像超时回退直连成功', () async {
      final requestedUrls = <String>[];
      final client = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        if (request.url.host == 'gh-proxy.org') {
          // 超过 timeout 的挂起响应，触发镜像侧超时。
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response(_okBody, 200);
        }
        return http.Response(_okBody, 200);
      });
      final service = GithubResourceService(
        useProxy: () => useGithubProxy,
        client: client,
      );

      final response = await service.get(
        _directUrl,
        timeout: const Duration(milliseconds: 50),
      );

      expect(response.statusCode, 200);
      expect(requestedUrls, [_mirrorUrlPrefix + _directUrl, _directUrl]);
    });
  });

  group('get · 关闭 GitHub 加速', () {
    test('只请求直连，零镜像请求', () async {
      useGithubProxy = false;
      final (service, urls) = buildService((_) => http.Response(_okBody, 200));

      final response = await service.get(_directUrl);

      expect(response.statusCode, 200);
      expect(urls, [_directUrl]);
    });

    test('直连失败直接抛异常，不回退镜像', () async {
      useGithubProxy = false;
      final (service, urls) = buildService(
        (_) => http.Response('direct error', 500),
      );

      await expectLater(
        service.get(_directUrl),
        throwsA(isA<GithubResourceException>()),
      );
      expect(urls, [_directUrl]);
    });
  });

  group('getStreamed', () {
    test('开启：镜像 502 回退直连，返回 200 响应流', () async {
      final (service, urls) = buildService((url) {
        if (url.host == 'gh-proxy.org') return http.Response('bad', 502);
        return http.Response(_okBody, 200);
      });

      final response = await service.getStreamed(_directUrl);

      expect(response.statusCode, 200);
      expect(await response.stream.bytesToString(), _okBody);
      expect(urls, [_mirrorUrlPrefix + _directUrl, _directUrl]);
    });

    test('关闭：只请求直连', () async {
      useGithubProxy = false;
      final (service, urls) = buildService((_) => http.Response(_okBody, 200));

      final response = await service.getStreamed(_directUrl);

      expect(response.statusCode, 200);
      expect(urls, [_directUrl]);
    });
  });

  test('注入的 client 不会被 service 关闭', () async {
    final inner = MockClient((_) async => http.Response(_okBody, 200));
    final tracking = _TrackingClient(inner);
    final service = GithubResourceService(
      useProxy: () => useGithubProxy,
      client: tracking,
    );

    await service.get(_directUrl);

    // 注入的 client 生命周期归注入方（test / injector）管理。
    expect(tracking.closed, isFalse);
  });
}
