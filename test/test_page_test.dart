import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bugaoshan/services/update_checker.dart';

/// 构建 GitHub release 下载 URL（仅用于 URL 格式校验，非 app 核心逻辑）。
///
/// 实际 app 中下载地址来自 GitHub API 的 `browser_download_url` 字段，
/// 此函数仅在此处验证 URL pattern 的正确性。
String buildBinaryUrlForPlatform(String version, String platform) {
  return 'https://github.com/The-Brotherhood-of-SCU/Bugaoshan/releases/download/'
      'v$version/bugaoshan_v${version}_${platform}_x64.zip';
}

Matcher _httpError(int code) => throwsA(
  isA<Exception>().having((e) => e.toString(), 'message', contains('$code')),
);

Matcher _parseError(String keyword) => throwsA(
  isA<Exception>().having((e) => e.toString(), 'message', contains(keyword)),
);

void main() {
  group('fetchLatestVersionFromGithub', () {
    MockClient mockClient(String body, [int status = 200]) =>
        MockClient((request) async => http.Response(body, status));

    test('parses version from valid GitHub API response', () async {
      final version = await fetchLatestVersionFromGithub(
        client: mockClient('{"tag_name": "v1.2.3", "name": "Release 1.2.3"}'),
      );
      expect(version, '1.2.3');
    });

    test('parses version without v prefix', () async {
      final version = await fetchLatestVersionFromGithub(
        client: mockClient('{"tag_name": "v0.5.6", "name": "Release 0.5.6"}'),
      );
      expect(version, '0.5.6');
    });

    test('throws on empty response body', () async {
      expect(
        fetchLatestVersionFromGithub(client: mockClient('', 200)),
        _parseError('empty response'),
      );
    });

    test('throws on invalid JSON without tag_name', () async {
      expect(
        fetchLatestVersionFromGithub(
          client: mockClient('{"name": "Release"}', 200),
        ),
        _parseError('Could not parse'),
      );
    });

    test('throws on HTTP error status', () async {
      expect(
        fetchLatestVersionFromGithub(client: mockClient('Not Found', 404)),
        _httpError(404),
      );
    });

    test('throws on rate limit exceeded', () async {
      expect(
        fetchLatestVersionFromGithub(
          client: mockClient('Rate limit exceeded', 403),
        ),
        _httpError(403),
      );
    });
  });

  group('fetchLatestPrereleaseFromGithub', () {
    MockClient mockClient(String body, [int status = 200]) =>
        MockClient((request) async => http.Response(body, status));

    test('parses prerelease version from releases list', () async {
      final version = await fetchLatestPrereleaseFromGithub(
        client: mockClient(
          '[{"tag_name": "v0.5.7", "prerelease": false}, '
          '{"tag_name": "v0.6.0-beta.1", "prerelease": true}]',
        ),
      );
      expect(version, '0.6.0-beta.1');
    });

    test('returns null when no prerelease found', () async {
      final version = await fetchLatestPrereleaseFromGithub(
        client: mockClient(
          '[{"tag_name": "v0.5.6", "prerelease": false}, '
          '{"tag_name": "v0.5.7", "prerelease": false}]',
        ),
      );
      expect(version, isNull);
    });

    test('returns first prerelease when multiple exist', () async {
      final version = await fetchLatestPrereleaseFromGithub(
        client: mockClient(
          '[{"tag_name": "v0.6.0-beta.2", "prerelease": true}, '
          '{"tag_name": "v0.6.0-beta.1", "prerelease": true}]',
        ),
      );
      expect(version, '0.6.0-beta.2');
    });
  });

  group('buildBinaryUrlForPlatform', () {
    test('generates correct URL format', () {
      final urlWindows = buildBinaryUrlForPlatform('1.2.3', 'windows');
      expect(urlWindows, contains('windows'));
      expect(urlWindows, contains('1.2.3'));
      expect(urlWindows, contains('v1.2.3'));

      final urlLinux = buildBinaryUrlForPlatform('0.5.6', 'linux');
      expect(urlLinux, contains('linux'));
      expect(urlLinux, contains('0.5.6'));
    });
  });

  group('checkHasUpdate', () {
    test('detects when update is available', () {
      expect(checkHasUpdate('0.5.6', '0.5.7'), isTrue);
    });

    test('detects when already on latest version', () {
      expect(checkHasUpdate('0.5.6', '0.5.6'), isFalse);
    });

    test('detects major version update', () {
      expect(checkHasUpdate('0.5.6', '1.0.0'), isTrue);
    });

    test('handles v prefix', () {
      expect(checkHasUpdate('v0.5.6', 'v0.5.7'), isTrue);
      expect(checkHasUpdate('v0.5.7', 'v0.5.6'), isFalse);
    });

    test('handles build metadata suffix', () {
      expect(checkHasUpdate('0.5.6', '0.5.7+1'), isTrue);
      expect(checkHasUpdate('0.5.6+100', '0.5.7'), isTrue);
    });

    test('returns false for invalid version strings', () {
      expect(checkHasUpdate('invalid', '0.5.7'), isFalse);
      expect(checkHasUpdate('0.5.6', 'invalid'), isFalse);
      expect(checkHasUpdate('0.5', '0.5.7'), isFalse);
    });
  });
}
