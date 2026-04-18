import 'package:http/http.dart' as http;

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
}

const releasesUrl =
    'https://github.com/The-Brotherhood-of-SCU/Bugaoshan/releases';
