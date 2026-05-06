import 'package:flutter/foundation.dart' show kDebugMode, kIsWasm, kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bugaoshan/providers/environment_info/native.dart'
    if (dart.library.js_interop) 'package:bugaoshan/providers/environment_info/web.dart';

class AppInfoProvider {
  PackageInfo packageInfo;
  AppInfoProvider(this.packageInfo) {
    _version = packageInfo.version;
  }

  late String _version;

  String get currentVersion {
    return _version;
  }

  String get gitTag =>
      const String.fromEnvironment('GIT_TAG', defaultValue: 'null');
  String get gitCommit =>
      const String.fromEnvironment('GIT_COMMIT', defaultValue: 'null');
  String get gitCommitDateRaw =>
      const String.fromEnvironment('GIT_COMMIT_DATE', defaultValue: 'null');
  String get buildTime =>
      const String.fromEnvironment('BUILD_TIME', defaultValue: 'null');
  String get shortCommit =>
      gitCommit.length >= 7 ? gitCommit.substring(0, 7) : gitCommit;

  Future<String> getVersionInfo() async {
    var appName = packageInfo.appName;
    var buildNumber = packageInfo.buildNumber;
    var version = packageInfo.version;
    var signature = packageInfo.buildSignature;
    var installerStore = packageInfo.installerStore;
    var packageName = packageInfo.packageName;

    var environmentText = "---Environment---\n${await getEnvironmentInfo()}";

    String content =
        "---APP---\n"
        "AppName: $appName\n"
        "BuildNumber: $buildNumber\n"
        "Version: $version\n"
        "Signature: $signature\n"
        "Installer: $installerStore\n"
        "PackageName: $packageName\n"
        "$environmentText"
        "---FLAG---\n"
        "Web: $kIsWeb\n"
        "WASM: $kIsWasm\n"
        "Debug: $kDebugMode\n"
        "---BUILD---\n"
        "Tag: $gitTag\n"
        "Commit: $shortCommit\n"
        "CommitDate: $gitCommitDateRaw\n"
        "BuildTime: $buildTime";
    return content;
  }
}
