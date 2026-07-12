import 'dart:convert';
import 'dart:io';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/services/update_asset_selector.dart';
import 'package:bugaoshan/services/update_checker.dart';
import 'package:crypto/crypto.dart' as crypto;

import 'package:bugaoshan/models/release_info.dart';
import 'package:flutter/services.dart';
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
  bool get isPrerelease => release?.isPrerelease ?? false;
  String? get releaseNotes => release?.body;
}

class UpdateService {
  static const _pubspecUrl =
      'https://raw.githubusercontent.com/The-Brotherhood-of-SCU/Bugaoshan/main/pubspec.yaml';
  static const _repo = 'The-Brotherhood-of-SCU/Bugaoshan';
  static const _channel = MethodChannel('bugaoshan/update');

  final SharedPreferences _prefs;
  final String _currentVersion;

  UpdateService(this._prefs, this._currentVersion);

  bool get supportsInAppUpdate =>
      !Platform.isLinux || !Platform.environment.containsKey('FLATPAK_ID');

  UpdateAssetPlatform? get _assetPlatform {
    if (Platform.isAndroid) return UpdateAssetPlatform.android;
    if (Platform.isWindows) return UpdateAssetPlatform.windows;
    if (Platform.isLinux) return UpdateAssetPlatform.linux;
    return null;
  }

  Map<String, dynamic>? _selectAsset(List<dynamic> assets) {
    final platform = _assetPlatform;
    if (platform == null) return null;
    return selectUpdateAsset(
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

  Future<String?> getLatestVersion() async {
    try {
      final response = await http.get(Uri.parse(_pubspecUrl));
      if (response.statusCode == 200) {
        final content = response.body;
        final versionMatch = RegExp(
          r'^version:\s*(\S+)',
          multiLine: true,
        ).firstMatch(content);
        if (versionMatch != null) {
          return versionMatch.group(1);
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<ReleaseInfo?> getLatestReleaseFromGitHub() async {
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) {
      throw Exception('GitHub API error: ${response.statusCode}');
    }
    if (response.body.isEmpty) return null;
    final data = jsonDecode(response.body);
    final asset = _selectAsset(data['assets'] as List<dynamic>);
    if (asset == null) return null;
    return ReleaseInfo(
      tagName: data['tag_name'] as String,
      downloadUrl: asset['browser_download_url'] as String,
      checksumSha256: _parseDigest(asset),
      isPrerelease: data['prerelease'] == true,
      body: data['body'] as String?,
    );
  }

  Future<ReleaseInfo> getLatestPrereleaseFromGitHub() async {
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$_repo/releases'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode == 200) {
      if (response.body.isEmpty) return const ReleaseInfo();
      final List<dynamic> releases = jsonDecode(response.body);
      if (releases.isNotEmpty && releases[0]['tag_name'] != null) {
        final tagName = releases[0]['tag_name'] as String;
        final isPrerelease = releases[0]['prerelease'] == true;
        final assets = releases[0]['assets'] as List<dynamic>;
        final asset = _selectAsset(assets);
        return ReleaseInfo(
          tagName: tagName,
          downloadUrl: asset?['browser_download_url'] as String?,
          checksumSha256: asset == null ? null : _parseDigest(asset),
          isPrerelease: isPrerelease,
          body: releases[0]['body'] as String?,
        );
      }
      return const ReleaseInfo();
    }
    throw Exception('GitHub API error: ${response.statusCode}');
  }

  Future<(ReleaseInfo? latestStable, ReleaseInfo? latestPreview)>
  getAllLatestReleases() async {
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$_repo/releases'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) {
      throw Exception('GitHub API error: ${response.statusCode}');
    }
    if (response.body.isEmpty) return (null, null);

    final List<dynamic> releases = jsonDecode(response.body);
    ReleaseInfo? latestStable;
    ReleaseInfo? latestPreview;

    for (final release in releases) {
      if (release['tag_name'] == null) continue;
      final isPrerelease = release['prerelease'] == true;
      final assets = release['assets'] as List<dynamic>;
      final asset = _selectAsset(assets);
      final info = ReleaseInfo(
        tagName: release['tag_name'] as String,
        downloadUrl: asset?['browser_download_url'] as String?,
        checksumSha256: asset == null ? null : _parseDigest(asset),
        isPrerelease: isPrerelease,
        body: release['body'] as String?,
      );
      if (isPrerelease && latestPreview == null) {
        latestPreview = info;
      } else if (!isPrerelease && latestStable == null) {
        latestStable = info;
      }
      if (latestStable != null && latestPreview != null) break;
    }
    // Fallback: 列表中全是 prerelease，用 /releases/latest 单独取 stable
    latestStable ??= await getLatestReleaseFromGitHub();
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
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
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
    } catch (e) {
      return UpdateCheckResult.error(e.toString());
    }
  }

  Future<UpdateCheckResult> checkPreviewUpdate(
    String currentVersion,
    String gitTag,
  ) async {
    try {
      final release = await getLatestPrereleaseFromGitHub();
      if (release.tagName == gitTag) {
        //if tag equal to gitTag, no update
        return UpdateCheckResult.noUpdate();
      }
      if (release.tagName != null && release.downloadUrl != null) {
        return UpdateCheckResult.hasUpdate(release);
      }
      return UpdateCheckResult.noUpdate();
    } catch (e) {
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
  /// When [includePreview] is true, the latest prerelease is checked; otherwise
  /// the latest stable release. Pass [gitTag] only when [includePreview] is true
  /// (used to suppress the "current build is itself the latest preview" case).
  Future<UpdateCheckResult> _checkForUpdate({
    required bool includePreview,
    required String currentVersion,
    String? gitTag,
  }) {
    if (includePreview) {
      return checkPreviewUpdate(currentVersion, gitTag ?? '');
    }
    return checkStableUpdate(currentVersion);
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

    final client = http.Client();
    List<int> chunks;
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      chunks = [];
      int received = 0;

      await for (final chunk in response.stream) {
        if (cancelToken?.isCancelled ?? false) {
          client.close();
          throw UpdateCancelledException();
        }
        chunks.addAll(chunk);
        received += chunk.length;
        onProgress?.call(received, contentLength);
      }
    } finally {
      client.close();
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

  static const releasesUrl =
      'https://github.com/The-Brotherhood-of-SCU/Bugaoshan/releases';
}
