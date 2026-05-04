import 'dart:convert';
import 'dart:io';

import 'package:bugaoshan/models/release_info.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class UpdateCancelledException implements Exception {}

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

  bool _assetMatchesPlatform(String assetName) {
    final name = assetName.toLowerCase();
    if (Platform.isAndroid) return name.endsWith('.apk');
    if (Platform.isWindows) return name.contains('windows');
    if (Platform.isLinux) return name.contains('linux');
    return false;
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
    if (response.statusCode == 200) {
      if (response.body.isEmpty) return null;
      final data = jsonDecode(response.body);
      final tagName = data['tag_name'] as String;
      final isPrerelease = data['prerelease'] == true;
      final assets = data['assets'] as List<dynamic>;
      for (final asset in assets) {
        final name = asset['name'] as String;
        if (_assetMatchesPlatform(name)) {
          return ReleaseInfo(
            tagName: tagName,
            downloadUrl: asset['browser_download_url'] as String,
            isPrerelease: isPrerelease,
            body: data['body'] as String?,
          );
        }
      }
    }
    throw Exception('GitHub API error: ${response.statusCode}');
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
        String? downloadUrl;
        for (final asset in assets) {
          final name = asset['name'] as String;
          if (_assetMatchesPlatform(name)) {
            downloadUrl = asset['browser_download_url'] as String;
            break;
          }
        }
        return ReleaseInfo(
          tagName: tagName,
          downloadUrl: downloadUrl,
          isPrerelease: isPrerelease,
          body: releases[0]['body'] as String?,
        );
      }
      return const ReleaseInfo();
    }
    throw Exception('GitHub API error: ${response.statusCode}');
  }

  bool hasUpdate(String currentVersion, String latestVersion) {
    final current = _parseVersion(currentVersion);
    final latest = _parseVersion(latestVersion);
    if (current == null || latest == null) return false;

    for (int i = 0; i < 3; i++) {
      if (latest[i] > current[i]) return true;
      if (latest[i] < current[i]) return false;
    }
    return false;
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

  Future<UpdateCheckResult> checkPreviewUpdate(String currentVersion) async {
    try {
      final release = await getLatestPrereleaseFromGitHub();
      if (release.tagName != null &&
          release.downloadUrl != null &&
          release.tagName != currentVersion) {
        return UpdateCheckResult.hasUpdate(release);
      }
      return UpdateCheckResult.noUpdate();
    } catch (e) {
      return UpdateCheckResult.error(e.toString());
    }
  }

  List<int>? _parseVersion(String version) {
    final cleanVersion = version
        .split('+')
        .first
        .replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    final parts = cleanVersion.split('.');
    if (parts.length < 3) return null;
    try {
      return [int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])];
    } catch (e) {
      return null;
    }
  }

  Future<void> downloadAndInstall(
    String version,
    String downloadUrl, {
    CancelToken? cancelToken,
    void Function(String status)? onStatus,
    void Function(int received, int total)? onProgress,
  }) async {
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

    if (Platform.isAndroid) {
      onStatus?.call('Installing...');
      await _installAndroid(chunks);
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
    if (extractDirObj.existsSync()) {
      extractDirObj.deleteSync(recursive: true);
    }
    extractDirObj.createSync(recursive: true);
    for (final file in archive) {
      final sanitizedName = file.name.replaceAll('/', Platform.pathSeparator);
      final filename = p.join(extractDir, sanitizedName);
      if (file.isFile) {
        final outFile = File(filename);
        outFile.parent.createSync(recursive: true);
        outFile.writeAsBytesSync(file.content as List<int>);
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

  Future<void> _installAndroid(List<int> apkBytes) async {
    final tempDir = await getTemporaryDirectory();
    final apkPath = p.join(tempDir.path, 'bugaoshan_update.apk');
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
    File(scriptPath).writeAsStringSync(script);

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
    File(scriptPath).writeAsStringSync(script);

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
