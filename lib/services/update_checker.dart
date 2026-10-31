import 'dart:convert';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/release_version.dart';

import 'package:http/http.dart' as http;

const String _tag = 'UpdateChecker';

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

/// 从 GitHub /releases API 获取第一页的 Release 列表。
///
/// 每次请求最多 100 条记录，只读取第一页，不继续请求后续分页。
/// 如果响应为空，返回空列表。
/// 如果传入了 [client]，则使用该 client（方便测试注入 MockClient）；
/// 否则内部创建默认 [http.Client]，并在请求结束后关闭。
Future<List<dynamic>> fetchRecentGithubReleases({http.Client? client}) async {
  final effectiveClient = client ?? http.Client();
  try {
    final uri = Uri.parse(
      _releasesUrl,
    ).replace(queryParameters: {'per_page': '100'});
    final response = await effectiveClient.get(uri, headers: _apiHeaders);
    if (response.statusCode != 200) {
      throw Exception('GitHub API error: ${response.statusCode}');
    }
    if (response.body.isEmpty) return <dynamic>[];
    return jsonDecode(response.body) as List<dynamic>;
  } finally {
    if (client == null) effectiveClient.close();
  }
}

/// 从 [releases] 中选择指定渠道版本号最高的 Release。
///
/// [prerelease] 为 `true` 时选择预发布版，为 `false` 时选择正式版。
/// 只比较传入列表中的有效版本，不依赖条目的排列顺序。
/// 草稿和无效标签会被跳过，渠道以 tag 语义为准。
/// 如果 API 标记与 tag 语义不一致，记录 info 日志并修正返回条目的渠道标记。
/// 此差异可自动纠正，使用 info 级别避免反复检查时重复写入警告文件。
/// 如果没有符合条件的版本，返回 `null`。
Map<String, dynamic>? selectLatestGithubRelease(
  Iterable<dynamic> releases, {
  required bool prerelease,
}) {
  Map<String, dynamic>? latest;
  ReleaseVersion? latestVersion;
  for (final release in releases) {
    if (release is! Map<String, dynamic> || release['draft'] == true) {
      continue;
    }
    final tag = release['tag_name'];
    if (tag is! String) continue;
    final version = ReleaseVersion.tryParse(tag);
    if (version == null) continue;
    if ((release['prerelease'] == true) != version.isPrerelease) {
      AppLog.i(
        _tag,
        'Release 渠道标记与 tag 不一致，已按 tag 语义处理：'
        'tag=$tag prerelease=${release['prerelease']} '
        'tagPrerelease=${version.isPrerelease}',
      );
    }
    if (version.isPrerelease != prerelease) continue;
    if (latestVersion == null || version.compareTo(latestVersion) > 0) {
      latest = {...release, 'prerelease': version.isPrerelease};
      latestVersion = version;
    }
  }
  return latest;
}

/// 从 GitHub /releases API 获取最新预发布版的 tag 名称（不含 `v` 前缀）。
///
/// 仅在第一页最多 100 条记录中按完整版本号选择，不依赖页内顺序。
/// 如果没有符合条件的预发布版，返回 `null`。
/// 如果传入了 [client]，则使用该 client（方便测试注入 MockClient）；
/// 否则内部创建默认 [http.Client]，并在请求结束后关闭。
Future<String?> fetchLatestPrereleaseFromGithub({http.Client? client}) async {
  final releases = await fetchRecentGithubReleases(client: client);
  final release = selectLatestGithubRelease(releases, prerelease: true);
  return (release?['tag_name'] as String?)?.replaceFirst(RegExp(r'^[vV]'), '');
}

/// 比较两个语义版本号，判断 `latestVersion` 是否比 `currentVersion` 新。
///
/// 支持 `v` 前缀、预发布后缀和 `+` 构建元数据（如 `v1.2.3-preview.12+4`）。
/// 主、次、修订版本号及纯数字预发布字段按数值比较，构建元数据不参与排序。
/// 如果任一版本无法解析，返回 `false`。
bool checkHasUpdate(String currentVersion, String latestVersion) {
  final current = _parseVersion(currentVersion);
  final latest = _parseVersion(latestVersion);
  if (current == null || latest == null) return false;
  return latest.compareTo(current) > 0;
}

/// 判断预发布 tag（如 `v2.5.4-preview.12`）是否比当前构建更新。
///
/// 预发布构建的安装包版本仍可能是上一个正式版（如 `2.5.3`），
/// 而 [gitTag] 记录实际的预发布版本，因此同时与两者比较。
/// 如果 [gitTag] 无法解析，则只使用 [currentVersion] 作为比较基准。
///
/// 返回 `false` 的情况：
/// - [prereleaseTag] 为 `null`、无法解析或不是预发布版；
/// - [currentVersion] 无法解析；
/// - 候选版本不高于 [currentVersion]；
/// - [gitTag] 有效，且候选版本不高于该构建 tag。
bool isNewerPrerelease(
  String? prereleaseTag,
  String currentVersion,
  String gitTag,
) {
  if (prereleaseTag == null) return false;
  final candidate = _parseVersion(prereleaseTag);
  final installed = _parseVersion(currentVersion);
  if (candidate == null ||
      !candidate.isPrerelease ||
      installed == null ||
      candidate.compareTo(installed) <= 0) {
    return false;
  }
  final currentTag = ReleaseVersion.tryParse(gitTag);
  return currentTag == null || candidate.compareTo(currentTag) > 0;
}

/// 将版本号字符串解析为用于更新比较的 [ReleaseVersion]。
///
/// 支持 `v1.2.3`、`1.2.3+4` 和 `1.2.3-preview.12` 等格式。
/// 无法解析时记录错误并返回 `null`。
ReleaseVersion? _parseVersion(String version) {
  final parsed = ReleaseVersion.tryParse(version);
  if (parsed == null) {
    AppLog.e(_tag, '无法比较更新版本：版本号格式错误 version=$version');
  }
  return parsed;
}
