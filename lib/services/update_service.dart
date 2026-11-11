import 'dart:convert';
import 'dart:io';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/services/github_resource_service.dart';
import 'package:bugaoshan/services/update_asset_selector.dart';
import 'package:bugaoshan/services/update_checker.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/constants.dart';

import 'package:bugaoshan/models/release_info.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class UpdateCancelledException implements Exception {}

class HashMismatchException implements Exception {
  final String actual;
  final String expected;
  HashMismatchException(this.actual, this.expected);

  @override
  String toString() =>
      'Checksum verification failed (expected $expected, got $actual)';
}

enum UpdateCheckStatus { initial, checking, noUpdate, hasUpdate, error }

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final ReleaseInfo? release;
  final String? error;

  const UpdateCheckResult._(this.status, {this.release, this.error});

  factory UpdateCheckResult.initial() =>
      const UpdateCheckResult._(UpdateCheckStatus.initial);
  factory UpdateCheckResult.checking() =>
      const UpdateCheckResult._(UpdateCheckStatus.checking);
  factory UpdateCheckResult.noUpdate() =>
      const UpdateCheckResult._(UpdateCheckStatus.noUpdate);
  factory UpdateCheckResult.hasUpdate(ReleaseInfo release) =>
      UpdateCheckResult._(UpdateCheckStatus.hasUpdate, release: release);
  factory UpdateCheckResult.error(String error) =>
      UpdateCheckResult._(UpdateCheckStatus.error, error: error);

  bool get hasUpdate => status == UpdateCheckStatus.hasUpdate;
  bool get checking => status == UpdateCheckStatus.checking;
  bool get noUpdate => status == UpdateCheckStatus.noUpdate;
  String? get version => release?.tagName;
  String? get downloadUrl => release?.downloadUrl;
  String? get filename => release?.filename;
  bool get isPrerelease => release?.isPrerelease ?? false;
  String? get releaseNotes => release?.body;
}

class UpdateService {
  static const String _tag = 'UpdateService';

  static const _channel = kUpdateMethodChannel;

  final SharedPreferences _prefs;
  final String _currentVersion;

  /// GitHub 资源访问入口：更新包下载的镜像/直连选择与回退内聚于此。
  final GithubResourceService _resource;

  UpdateService(this._prefs, this._currentVersion, this._resource);

  bool get supportsInAppUpdate =>
      // F-Droid 渠道安装的包由 F-Droid 负责更新，应用内自更新对其隐藏。
      // 用运行时安装来源判断而非构建时开关，以保持 F-Droid 可复制构建
      // 与 CI 产物逐字节一致。
      !getIt<AppInfoProvider>().isFdroidInstall &&
      ((Platform.isLinux && !Platform.environment.containsKey('FLATPAK_ID')) ||
          Platform.isAndroid ||
          Platform.isWindows);

  UpdateAssetPlatform? get _assetPlatform {
    if (Platform.isAndroid) return UpdateAssetPlatform.android;
    if (Platform.isWindows) return UpdateAssetPlatform.windows;
    if (Platform.isLinux) return UpdateAssetPlatform.linux;
    return null;
  }

  Future<Map<String, dynamic>?> _selectAsset(List<dynamic> assets) async {
    final platform = _assetPlatform;
    if (platform == null) return null;
    return selectUpdateAssetAsync(
      assets.whereType<Map<String, dynamic>>(),
      platform,
    );
  }

  /// Parse the `digest` field from a GitHub release asset.
  /// GitHub returns `"sha256:<hex>"` — extract the hex part.
  /// Returns `null` if the field is missing or unexpected format.
  String? _parseDigest(Map<String, dynamic> asset) {
    final digest = asset['digest'] as String?;
    if (digest == null) return null;
    const prefix = 'sha256:';
    if (digest.startsWith(prefix)) return digest.substring(prefix.length);
    return null;
  }

  /// 从 GitHub /releases/latest API 获取最新正式版的更新信息。
  ///
  /// 渠道按 tag 语义判断，不将误标为正式版的预发布标签作为正式版更新。
  /// 如果没有有效的正式版或当前平台可用的安装包，返回 `null`。
  Future<ReleaseInfo?> getLatestReleaseFromGitHub() async {
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$kGithubRepo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) {
      throw Exception('GitHub API error: ${response.statusCode}');
    }
    if (response.body.isEmpty) return null;
    final data = jsonDecode(response.body);
    final release = selectLatestGithubRelease([data], prerelease: false);
    if (release == null) return null;
    return _releaseInfo(release);
  }

  /// 从 GitHub 获取候选范围内最新的预发布版更新信息。
  ///
  /// 在第一页最多 100 条记录中按完整版本号选择，并匹配当前平台的安装包。
  /// 如果没有有效的预发布版或当前平台可用的安装包，返回空的 [ReleaseInfo]。
  Future<ReleaseInfo> getLatestPrereleaseFromGitHub() async {
    final releases = await fetchRecentGithubReleases();
    final release = selectLatestGithubRelease(releases, prerelease: true);
    final info = release == null ? null : await _releaseInfo(release);
    return info ?? const ReleaseInfo();
  }

  /// 将 [release] 转换为当前平台的更新信息。
  ///
  /// 保留版本标签、更新说明和匹配安装包的下载地址及校验值。
  /// 如果没有匹配的安装包或有效下载地址，记录警告并返回 `null`。
  /// 最新候选缺包表示当前平台暂无可安装更新，不继续选择同渠道的旧版本。
  Future<ReleaseInfo?> _releaseInfo(Map<String, dynamic> release) async {
    final asset = await _selectAsset(release['assets'] as List<dynamic>);
    if (asset == null) {
      AppLog.w(
        _tag,
        'Release 没有当前平台可用的安装包，已跳过更新：'
        'tag=${release['tag_name']} platform=${Platform.operatingSystem}',
      );
      return null;
    }
    final downloadUrl = asset['browser_download_url'];
    if (downloadUrl is! String || downloadUrl.isEmpty) {
      AppLog.w(
        _tag,
        'Release 安装包没有有效下载地址，已跳过更新：'
        'tag=${release['tag_name']} asset=${asset['name']}',
      );
      return null;
    }
    return ReleaseInfo(
      tagName: release['tag_name'] as String,
      downloadUrl: downloadUrl,
      filename: asset['name'] as String?,
      checksumSha256: _parseDigest(asset),
      isPrerelease: release['prerelease'] == true,
      body: release['body'] as String?,
    );
  }

  /// 获取候选范围内最新的正式版和预发布版更新信息。
  ///
  /// 在第一页最多 100 条记录中分别按完整版本号选择两个渠道的候选。
  /// 如果第一页没有有效的正式版，则通过 /releases/latest 单独获取。
  /// 如果没有有效候选或当前平台可用的安装包，对应渠道的结果为 `null`。
  ///
  /// 最新候选缺包不触发 /latest 回退，也不改选同渠道的旧版本，
  /// 以免将已过时的安装包作为“最新版”推荐给用户。
  Future<(ReleaseInfo? latestStable, ReleaseInfo? latestPreview)>
  getAllLatestReleases() async {
    final releases = await fetchRecentGithubReleases();
    final stable = selectLatestGithubRelease(releases, prerelease: false);
    final preview = selectLatestGithubRelease(releases, prerelease: true);
    final latestStable = stable == null
        ? await getLatestReleaseFromGitHub()
        : await _releaseInfo(stable);
    final latestPreview = preview == null ? null : await _releaseInfo(preview);
    return (latestStable, latestPreview);
  }

  /// 比较两个语义版本号，判断 [latestVersion] 是否比 [currentVersion] 新。
  ///
  /// 委托给 [checkHasUpdate] 以保证与 update_checker 单元测试共享同一套逻辑。
  bool hasUpdate(String currentVersion, String latestVersion) {
    return checkHasUpdate(currentVersion, latestVersion);
  }

  static const _keyLastInstalledVersion = 'last_installed_version';

  /// 清理临时目录中旧版本的安装包，仅在版本变化时执行一次。
  Future<void> cleanupOldPackages() async {
    if (!Platform.isAndroid) return;
    final lastVersion = _prefs.getString(_keyLastInstalledVersion);
    if (lastVersion == _currentVersion) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory(tempDir.path);
      if (await dir.exists()) {
        await for (final ent in dir.list(recursive: false)) {
          if (ent is File) {
            final name = p.basename(ent.path).toLowerCase();
            if (name.endsWith('.apk') &&
                (name.startsWith('bugaoshan_v') ||
                    name.startsWith('bugaoshan_update'))) {
              try {
                await ent.delete();
              } catch (e, logStackTrace) {
                AppLog.e(
                  _tag,
                  'cleanupOldPackages 失败',
                  error: e,
                  stackTrace: logStackTrace,
                );
              }
            }
          }
        }
      }
    } catch (e, logStackTrace) {
      AppLog.e(
        _tag,
        'cleanupOldPackages 失败',
        error: e,
        stackTrace: logStackTrace,
      );
    }
    await _prefs.setString(_keyLastInstalledVersion, _currentVersion);
  }

  Future<UpdateCheckResult> checkStableUpdate(String currentVersion) async {
    try {
      final latest = await getLatestReleaseFromGitHub();
      if (latest != null &&
          latest.tagName != null &&
          hasUpdate(currentVersion, latest.tagName!)) {
        return UpdateCheckResult.hasUpdate(latest);
      }
      return UpdateCheckResult.noUpdate();
    } catch (e, logStackTrace) {
      AppLog.e(
        _tag,
        'checkStableUpdate 失败',
        error: e,
        stackTrace: logStackTrace,
      );
      return UpdateCheckResult.error(e.toString());
    }
  }

  Future<UpdateCheckResult> checkPreviewUpdate(
    String currentVersion,
    String gitTag,
  ) async {
    try {
      final release = await getLatestPrereleaseFromGitHub();
      if (release.tagName != null &&
          release.downloadUrl != null &&
          isNewerPrerelease(release.tagName, currentVersion, gitTag)) {
        return UpdateCheckResult.hasUpdate(release);
      }
      return UpdateCheckResult.noUpdate();
    } catch (e, logStackTrace) {
      AppLog.e(
        _tag,
        'checkPreviewUpdate 失败',
        error: e,
        stackTrace: logStackTrace,
      );
      return UpdateCheckResult.error(e.toString());
    }
  }

  Future<UpdateCheckResult> checkForUpdate() {
    if (!supportsInAppUpdate) return Future.value(UpdateCheckResult.noUpdate());
    final includePreview =
        getIt<AppConfigProvider>().usePreviewUpdateSource.value;
    final versionProvider = getIt<AppInfoProvider>();
    final currentVersion = versionProvider.currentVersion;
    final gitTag = includePreview ? versionProvider.gitTag : null;
    return _checkForUpdate(
      includePreview: includePreview,
      currentVersion: currentVersion,
      gitTag: gitTag,
    );
  }

  /// Unified update check used by production callers (home / about pages).
  ///
  /// When [includePreview] is true, the latest prerelease is checked first;
  /// if there is no newer prerelease (e.g. the current build is already the
  /// latest preview, or its stable release has shipped), it falls back to the
  /// stable channel so preview users still receive stable update notifications.
  /// Pass [gitTag] only when [includePreview] is true (used to suppress the
  /// "current build is itself the latest preview" case).
  Future<UpdateCheckResult> _checkForUpdate({
    required bool includePreview,
    required String currentVersion,
    String? gitTag,
  }) async {
    if (!includePreview) {
      return checkStableUpdate(currentVersion);
    }
    final previewResult = await checkPreviewUpdate(
      currentVersion,
      gitTag ?? '',
    );
    if (previewResult.hasUpdate) return previewResult;
    if (previewResult.noUpdate) return checkStableUpdate(currentVersion);
    // 预览检查出错时保留错误状态，避免把错误误报为"无更新"。
    return previewResult;
  }

  Future<void> downloadAndInstall(
    String version,
    String downloadUrl, {
    String? checksumSha256,
    CancelToken? cancelToken,
    void Function(String status)? onStatus,
    void Function(int received, int total)? onProgress,
  }) async {
    if (!supportsInAppUpdate) {
      throw UnsupportedError('Updates are managed by Flatpak');
    }
    onStatus?.call('Downloading update...');

    // 镜像/直连选择与回退由 GithubResourceService 内聚处理；拿到响应后
    // 字节流的进度上报与取消检查仍在本地完成。
    final response = await _resource.getStreamed(downloadUrl);
    final contentLength = response.contentLength ?? 0;
    final chunks = <int>[];
    int received = 0;

    await for (final chunk in response.stream) {
      if (cancelToken?.isCancelled ?? false) {
        throw UpdateCancelledException();
      }
      chunks.addAll(chunk);
      received += chunk.length;
      onProgress?.call(received, contentLength);
    }

    if (cancelToken?.isCancelled ?? false) {
      throw UpdateCancelledException();
    }

    if (checksumSha256 != null) {
      onStatus?.call('Verifying checksum...');
      final digest = crypto.sha256.convert(chunks);
      final actualHash = digest.toString();
      if (actualHash != checksumSha256) {
        throw HashMismatchException(actualHash, checksumSha256);
      }
    }

    if (Platform.isAndroid) {
      onStatus?.call('Installing...');
      await _installAndroid(chunks, version);
      return;
    }

    onStatus?.call('Extracting...');

    // Save to temp directory
    final tempDir = await getTemporaryDirectory();
    final extractDir = p.join(tempDir.path, 'bugaoshan_update');

    // Extract the zip or tar.gz
    final archive = downloadUrl.endsWith('.tar.gz')
        ? TarDecoder().decodeBytes(GZipDecoder().decodeBytes(chunks))
        : ZipDecoder().decodeBytes(chunks);
    final extractDirObj = Directory(extractDir);
    if (await extractDirObj.exists()) {
      await extractDirObj.delete(recursive: true);
    }
    await extractDirObj.create(recursive: true);
    final extractRoot = await extractDirObj.resolveSymbolicLinks();
    for (final file in archive) {
      final filename = _safeArchivePath(extractRoot, file.name);
      if (file.isFile) {
        final outFile = File(filename);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }

    onStatus?.call('Installing...');

    final currentExe = Platform.resolvedExecutable;
    final currentExeDir = File(currentExe).parent.path;

    if (Platform.isWindows) {
      await _installWindows(extractDir, currentExeDir, currentExe);
    } else if (Platform.isLinux) {
      await _installLinux(extractDir, currentExeDir, currentExe);
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    exit(0);
  }

  String _safeArchivePath(String extractRoot, String entryName) {
    final normalizedName = entryName.replaceAll('\\', '/');
    if (normalizedName.split('/').any((part) => part == '..')) {
      throw FormatException('Unsafe archive entry: $entryName');
    }
    final relativePath = p.fromUri(Uri(path: normalizedName));
    if (p.isAbsolute(relativePath)) {
      throw FormatException('Unsafe archive entry: $entryName');
    }
    final fullPath = p.normalize(p.join(extractRoot, relativePath));
    final rootWithSeparator = extractRoot.endsWith(Platform.pathSeparator)
        ? extractRoot
        : '$extractRoot${Platform.pathSeparator}';
    if (fullPath != extractRoot && !fullPath.startsWith(rootWithSeparator)) {
      throw FormatException('Unsafe archive entry: $entryName');
    }
    return fullPath;
  }

  Future<void> _installAndroid(List<int> apkBytes, String version) async {
    final tempDir = await getTemporaryDirectory();
    // Compute short sha256 for uniqueness
    final digest = crypto.sha256.convert(apkBytes);
    final hashShort = digest.toString().substring(0, 8);
    final safeVersion = version.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final filename = 'Bugaoshan_v${safeVersion}_$hashShort.apk';
    final apkPath = p.join(tempDir.path, filename);
    final apkFile = File(apkPath);
    await apkFile.writeAsBytes(apkBytes);
    await _channel.invokeMethod('installApk', {'path': apkPath});
  }

  Future<void> _installWindows(
    String extractDir,
    String exeDir,
    String exePath,
  ) async {
    final scriptPath = p.join(extractDir, 'update.bat');
    final scriptBytes = await rootBundle.load('assets/scripts/update.bat');
    final script = utf8
        .decode(scriptBytes.buffer.asUint8List())
        .replaceAll('{EXE_DIR}', exeDir)
        .replaceAll('{EXE_PATH}', exePath);
    await File(scriptPath).writeAsString(script);

    await Process.start(
      'cmd.exe',
      ['/c', 'call', scriptPath],
      workingDirectory: extractDir,
      mode: ProcessStartMode.detached,
    );
  }

  Future<void> _installLinux(
    String extractDir,
    String exeDir,
    String exePath,
  ) async {
    final scriptPath = p.join(extractDir, 'update.sh');
    final scriptBytes = await rootBundle.load('assets/scripts/update.sh');
    final script = utf8
        .decode(scriptBytes.buffer.asUint8List())
        .replaceAll('{EXE_DIR}', exeDir)
        .replaceAll('{EXE_PATH}', exePath);
    await File(scriptPath).writeAsString(script);

    await Process.run('chmod', ['+x', scriptPath]);

    await Process.start('bash', [
      scriptPath,
      extractDir,
      exeDir,
    ], mode: ProcessStartMode.detached);
  }
}
