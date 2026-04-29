import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pub_semver/pub_semver.dart';

Future<String> getLatestVersionFromGitHub(http.Client client) async {
  const repo = 'The-Brotherhood-of-SCU/Bugaoshan';
  final response = await client.get(
    Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
    headers: {'Accept': 'application/vnd.github+json'},
  );
  if (response.statusCode == 200) {
    if (response.body.isEmpty) {
      throw Exception('GitHub API returned empty response');
    }
    final tagName = RegExp(
      r'"tag_name":\s*"([^"]+)"',
    ).firstMatch(response.body)?.group(1);
    if (tagName != null) {
      return tagName.replaceFirst('v', '');
    }
    throw Exception('Could not parse release tag from response');
  }
  throw Exception('GitHub API error: ${response.statusCode}');
}

String buildBinaryUrlForPlatform(String version, String platform) {
  return 'https://github.com/The-Brotherhood-of-SCU/Bugaoshan/releases/download/v$version/bugaoshan_v${version}_${platform}_x64.zip';
}

Future<String?> getLatestPrereleaseFromGitHub(http.Client client) async {
  const repo = 'The-Brotherhood-of-SCU/Bugaoshan';
  final response = await client.get(
    Uri.parse('https://api.github.com/repos/$repo/releases'),
    headers: {'Accept': 'application/vnd.github+json'},
  );
  if (response.statusCode == 200) {
    if (response.body.isEmpty) return null;
    final List<dynamic> releases = jsonDecode(response.body);
    for (final release in releases) {
      if (release['prerelease'] == true && release['tag_name'] != null) {
        return (release['tag_name'] as String).replaceFirst('v', '');
      }
    }
    return null;
  }
  throw Exception('GitHub API error: ${response.statusCode}');
}

Matcher _httpError(int code) => throwsA(
  isA<Exception>().having((e) => e.toString(), 'message', contains('$code')),
);

Matcher _parseError(String keyword) => throwsA(
  isA<Exception>().having((e) => e.toString(), 'message', contains(keyword)),
);

void main() {
  group('getLatestVersionFromGitHub', () {
    MockClient mockClient(String body, [int status = 200]) =>
        MockClient((request) async => http.Response(body, status));

    test('parses version from valid GitHub API response', () async {
      final version = await getLatestVersionFromGitHub(
        mockClient('{"tag_name": "v1.2.3", "name": "Release 1.2.3"}'),
      );
      expect(version, '1.2.3');
    });

    test('parses version without v prefix', () async {
      final version = await getLatestVersionFromGitHub(
        mockClient('{"tag_name": "v0.5.6", "name": "Release 0.5.6"}'),
      );
      expect(version, '0.5.6');
    });

    test('throws on empty response body', () async {
      expect(
        getLatestVersionFromGitHub(mockClient('', 200)),
        _parseError('empty response'),
      );
    });

    test('throws on invalid JSON without tag_name', () async {
      expect(
        getLatestVersionFromGitHub(mockClient('{"name": "Release"}', 200)),
        _parseError('Could not parse'),
      );
    });

    test('throws on HTTP error status', () async {
      expect(
        getLatestVersionFromGitHub(mockClient('Not Found', 404)),
        _httpError(404),
      );
    });

    test('throws on rate limit exceeded', () async {
      expect(
        getLatestVersionFromGitHub(mockClient('Rate limit exceeded', 403)),
        _httpError(403),
      );
    });
  });

  group('getLatestPrereleaseFromGitHub', () {
    MockClient mockClient(String body, [int status = 200]) =>
        MockClient((request) async => http.Response(body, status));

    test('parses prerelease version from releases list', () async {
      final version = await getLatestPrereleaseFromGitHub(
        mockClient(
          '[{"tag_name": "v0.5.7", "prerelease": false}, {"tag_name": "v0.6.0-beta.1", "prerelease": true}]',
        ),
      );
      expect(version, '0.6.0-beta.1');
    });

    test('returns null when no prerelease found', () async {
      final version = await getLatestPrereleaseFromGitHub(
        mockClient(
          '[{"tag_name": "v0.5.6", "prerelease": false}, {"tag_name": "v0.5.7", "prerelease": false}]',
        ),
      );
      expect(version, isNull);
    });

    test('returns first prerelease when multiple exist', () async {
      final version = await getLatestPrereleaseFromGitHub(
        mockClient(
          '[{"tag_name": "v0.6.0-beta.2", "prerelease": true}, {"tag_name": "v0.6.0-beta.1", "prerelease": true}]',
        ),
      );
      expect(version, '0.6.0-beta.2');
    });
  });

  group('buildBinaryUrl', () {
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

  group('version comparison', () {
    test('detects when update is available', () {
      final current = Version.parse('0.5.6');
      final latest = Version.parse('0.5.7');
      expect(latest > current, isTrue);
    });

    test('detects when already on latest version', () {
      final current = Version.parse('0.5.6');
      final latest = Version.parse('0.5.6');
      expect(latest > current, isFalse);
    });

    test('detects major version update', () {
      final current = Version.parse('0.5.6');
      final latest = Version.parse('1.0.0');
      expect(latest > current, isTrue);
    });
  });
}
