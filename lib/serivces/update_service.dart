import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'package:bugaoshan/models/release_info.dart';

class UpdateService {
  static const _pubspecUrl =
      'https://raw.githubusercontent.com/The-Brotherhood-of-SCU/Bugaoshan/main/pubspec.yaml';
  static const _repo = 'The-Brotherhood-of-SCU/Bugaoshan';

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

  Future<(String, String)?> getLatestReleaseFromGitHub() async {
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode == 200) {
      if (response.body.isEmpty) return null;
      final data = jsonDecode(response.body);
      final tagName = (data['tag_name'] as String);
      final assets = data['assets'] as List<dynamic>;
      final platform = Platform.isWindows ? 'windows' : 'linux';
      for (final asset in assets) {
        final name = asset['name'] as String;
        if (name.toLowerCase().contains(platform)) {
          return (
            tagName.replaceFirst('v', ''),
            asset['browser_download_url'] as String,
          );
        }
      }
    }
    throw Exception('GitHub API error: ${response.statusCode}');
  }

  Future<(String?, String?, bool)> getLatestPrereleaseFromGitHub() async {
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$_repo/releases'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode == 200) {
      if (response.body.isEmpty) return (null, null, false);
      final List<dynamic> releases = jsonDecode(response.body);
      if (releases.isNotEmpty && releases[0]['tag_name'] != null) {
        final tagName = (releases[0]['tag_name'] as String).replaceFirst(
          'v',
          '',
        );
        final isPrerelease = releases[0]['prerelease'] == true;
        final assets = releases[0]['assets'] as List<dynamic>;
        final platform = Platform.isWindows ? 'windows' : 'linux';
        String? downloadUrl;
        for (final asset in assets) {
          final name = asset['name'] as String;
          if (name.toLowerCase().contains(platform)) {
            downloadUrl = asset['browser_download_url'] as String;
            break;
          }
        }
        return (tagName, downloadUrl, isPrerelease);
      }
      return (null, null, false);
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

  List<int>? _parseVersion(String version) {
    final cleanVersion = version.split('+').first;
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
        chunks.addAll(chunk);
        received += chunk.length;
        onProgress?.call(received, contentLength);
      }
    } finally {
      client.close();
    }

    onStatus?.call('Extracting...');

    // Save to temp directory
    final tempDir = await getTemporaryDirectory();
    final extractDir = p.join(tempDir.path, 'bugaoshan_update');

    // Extract the zip
    final archive = ZipDecoder().decodeBytes(chunks);
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
      await _installLinux(extractDir, currentExeDir);
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    exit(0);
  }

  Future<void> _installWindows(String extractDir, String exeDir, String exePath) async {
    final scriptPath = p.join(extractDir, 'update.bat');
    final scriptBytes = await rootBundle.load('assets/scripts/update.bat');
    final script = utf8.decode(scriptBytes.buffer.asUint8List())
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

  Future<void> _installLinux(String extractDir, String exeDir) async {
    final scriptPath = p.join(extractDir, 'update.sh');
    final scriptBytes = await rootBundle.load('assets/scripts/update.sh');
    final script = utf8.decode(scriptBytes.buffer.asUint8List())
        .replaceAll('{EXE_DIR}', exeDir);
    File(scriptPath).writeAsStringSync(script);

    await Process.start(
      'bash',
      [scriptPath, extractDir, exeDir],
      mode: ProcessStartMode.detached,
    );
  }

  static const releasesUrl =
      'https://github.com/The-Brotherhood-of-SCU/Bugaoshan/releases';
}
