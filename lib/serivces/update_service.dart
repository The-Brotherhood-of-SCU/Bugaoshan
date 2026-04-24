import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

class UpdateService {
  static const _pubspecUrl =
      'https://raw.githubusercontent.com/The-Brotherhood-of-SCU/Bugaoshan/main/pubspec.yaml';

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
  }) async {
    onStatus?.call('Downloading update...');

    final response = await http.get(Uri.parse(downloadUrl));
    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    onStatus?.call('Extracting...');

    // Save to temp directory
    final tempDir = await getTemporaryDirectory();
    final extractDir = '${tempDir.path}/bugaoshan_update';

    // Extract the zip
    final archive = ZipDecoder().decodeBytes(response.bodyBytes);
    final extractDirObj = Directory(extractDir);
    if (extractDirObj.existsSync()) {
      extractDirObj.deleteSync(recursive: true);
    }
    extractDirObj.createSync(recursive: true);
    for (final file in archive) {
      final filename = '$extractDir/${file.name}';
      if (file.isFile) {
        final outFile = File(filename);
        outFile.parent.createSync(recursive: true);
        outFile.writeAsBytesSync(file.content as List<int>);
      }
    }

    onStatus?.call('Installing...');

    // Load update script from assets
    final currentExe = Platform.resolvedExecutable;
    final currentExeDir = File(currentExe).parent.path;
    final scriptPath = '$extractDir/update.bat';
    final scriptBytes =
        await rootBundle.load('assets/scripts/update.bat');
    final script = utf8.decode(scriptBytes.buffer.asUint8List())
        .replaceAll('{EXE_DIR}', currentExeDir)
        .replaceAll('{EXE_PATH}', currentExe);
    File(scriptPath).writeAsStringSync(script);

    // Run update script and exit
    await Process.start('cmd.exe', ['/c', 'start', '', '/min', 'update.bat'],
        workingDirectory: extractDir, runInShell: true);
    exit(0);
  }

  static const releasesUrl =
      'https://github.com/The-Brotherhood-of-SCU/Bugaoshan/releases';
}
