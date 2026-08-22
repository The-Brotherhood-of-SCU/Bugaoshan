import 'dart:convert';

import 'package:http/http.dart' as http;

/// Bugaoshan GitHub 仓库标识。
const String kGithubRepo = 'The-Brotherhood-of-SCU/Bugaoshan';

const String _latestReleaseUrl =
    'https://api.github.com/repos/$kGithubRepo/releases/latest';
const String _releasesUrl =
    'https://api.github.com/repos/$kGithubRepo/releases';

Map<String, String> get _apiHeaders => {
  'Accept': 'application/vnd.github+json',
};

/// 从 GitHub /releases/latest API 获取最新稳定版的 tag 名称（不含 `v` 前缀）。
///
/// 如果传入了 [client]，则使用该 client（方便测试注入 MockClient）；
/// 否则内部创建默认 [http.Client]。
Future<String> fetchLatestVersionFromGithub({http.Client? client}) async {
  final http.Client effectiveClient = client ?? http.Client();
  try {
    final response = await effectiveClient.get(
      Uri.parse(_latestReleaseUrl),
      headers: _apiHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception('GitHub API error: ${response.statusCode}');
    }
    if (response.body.isEmpty) {
      throw Exception('GitHub API returned empty response');
    }
    final dynamic data = jsonDecode(response.body);
    final tagName = (data is Map ? data['tag_name'] : null) as String?;
    if (tagName == null) {
      throw Exception('Could not parse release tag from response');
    }
    return tagName.replaceFirst('v', '');
  } finally {
    if (client == null) {
      effectiveClient.close();
    }
  }
}

/// 从 GitHub /releases API 获取最新预发布版的 tag 名称（不含 `v` 前缀）。
///
/// 如果没有预发布版，返回 `null`。
/// 如果传入了 [client]，则使用该 client（方便测试注入 MockClient）；
/// 否则内部创建默认 [http.Client]。
Future<String?> fetchLatestPrereleaseFromGithub({http.Client? client}) async {
  final http.Client effectiveClient = client ?? http.Client();
  try {
    final response = await effectiveClient.get(
      Uri.parse(_releasesUrl),
      headers: _apiHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception('GitHub API error: ${response.statusCode}');
    }
    if (response.body.isEmpty) return null;
    final List<dynamic> releases = jsonDecode(response.body) as List<dynamic>;
    for (final release in releases) {
      if (release is Map &&
          release['prerelease'] == true &&
          release['tag_name'] != null) {
        return (release['tag_name'] as String).replaceFirst('v', '');
      }
    }
    return null;
  } finally {
    if (client == null) {
      effectiveClient.close();
    }
  }
}

/// 比较两个语义版本号，判断 `latestVersion` 是否比 `currentVersion` 新。
///
/// 支持 `v` 前缀（如 `v1.2.3`）和 `+` 后缀（如 `1.2.3+4`）。
bool checkHasUpdate(String currentVersion, String latestVersion) {
  final current = _parseVersion(currentVersion);
  final latest = _parseVersion(latestVersion);
  if (current == null || latest == null) return false;
  for (int i = 0; i < 3; i++) {
    if (latest[i] > current[i]) return true;
    if (latest[i] < current[i]) return false;
  }
  return false;
}

/// 判断预发布 tag（如 `v2.3.0-pre7`）是否比当前构建更新。
///
/// 预发布构建的 pubspec 版本仍是上一个正式版的版本号（例如当前软件版本
/// `2.2.0`、git tag `v2.3.0-pre7`），因此不能直接比较完整 tag 字符串；
/// 这里提取 tag 中 `-` 之前的基础版本号（`v2.3.0-pre7` → `2.3.0`），
/// 再与当前软件版本做语义比较。
///
/// 返回 `false` 的情况：
/// - [prereleaseTag] 为 `null` 或与 [gitTag] 相同（当前构建就是该预发布版）；
/// - tag 无法解析出基础版本号（保守处理，不提示更新）；
/// - 基础版本号不高于当前软件版本（避免把同版本/旧版本预发布当作更新）。
bool isNewerPrerelease(
  String? prereleaseTag,
  String currentVersion,
  String gitTag,
) {
  if (prereleaseTag == null || prereleaseTag == gitTag) return false;
  final baseVersion = _prereleaseBaseVersion(prereleaseTag);
  if (baseVersion == null) return false;
  return checkHasUpdate(currentVersion, baseVersion);
}

/// 提取预发布 tag 的基础版本号（`v2.3.0-pre7` → `2.3.0`）。
///
/// 无法解析时返回 `null`。
String? _prereleaseBaseVersion(String tag) {
  final clean = tag
      .replaceFirst(RegExp(r'^v', caseSensitive: false), '')
      .split('-')
      .first;
  return _parseVersion(clean) == null ? null : clean;
}

/// 解析语义版本号字符串为 `[major, minor, patch]`。
///
/// 支持格式：`1.2.3`、`v1.2.3`、`1.2.3+4`。
List<int>? _parseVersion(String version) {
  final clean = version
      .split('+')
      .first
      .replaceFirst(RegExp(r'^v', caseSensitive: false), '');
  final parts = clean.split('.');
  if (parts.length < 3) return null;
  try {
    return [int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])];
  } catch (_) {
    return null;
  }
}
