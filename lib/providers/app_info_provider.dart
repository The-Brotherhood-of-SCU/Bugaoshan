import 'package:flutter/foundation.dart' show kDebugMode, kIsWasm, kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bugaoshan/models/version_info.dart';
import 'package:bugaoshan/providers/environment_info/native.dart';

class AppInfoProvider {
  /// 已知 F-Droid 客户端的包名。
  ///
  /// 从这些渠道安装的包由 F-Droid 负责更新。由于 F-Droid 版采用可复制构建，
  /// 与 GitHub Release 同签名，技术上自更新也能成功，但 F-Droid 收录政策要求
  /// 应用不得引导用户绕过 F-Droid 渠道更新，因此需要对这类安装隐藏自更新。
  static const _fdroidInstallerStores = {
    'org.fdroid.fdroid', // F-Droid 官方客户端
    'org.fdroid.basic', // F-Droid Basic
    'com.looker.droidify', // Droid-ify
    'com.machiav3lli.fdroid', // Neo Store
  };

  PackageInfo packageInfo;
  AppInfoProvider(this.packageInfo) {
    _version = packageInfo.version;
  }

  late String _version;

  String get currentVersion {
    return _version;
  }

  /// 是否从 F-Droid 渠道安装（官方客户端及常见第三方客户端）。
  bool get isFdroidInstall =>
      _fdroidInstallerStores.contains(packageInfo.installerStore);

  String get gitTag =>
      const String.fromEnvironment('GIT_TAG', defaultValue: 'null');
  String get gitCommit =>
      const String.fromEnvironment('GIT_COMMIT', defaultValue: 'null');
  String get gitCommitDateRaw =>
      const String.fromEnvironment('GIT_COMMIT_DATE', defaultValue: 'null');
  String get shortCommit =>
      gitCommit.length >= 7 ? gitCommit.substring(0, 7) : gitCommit;

  Future<VersionInfo> getVersionInfo() async {
    return VersionInfo(
      app:
          "AppName: ${packageInfo.appName}\n"
          "BuildNumber: ${packageInfo.buildNumber}\n"
          "Version: ${packageInfo.version}\n"
          "Signature: ${packageInfo.buildSignature}\n"
          "Installer: ${packageInfo.installerStore}\n"
          "PackageName: ${packageInfo.packageName}",
      environment: await getEnvironmentInfo(),
      flag:
          "Web: $kIsWeb\n"
          "WASM: $kIsWasm\n"
          "Debug: $kDebugMode",
      build:
          "Tag: $gitTag\n"
          "Commit: $shortCommit\n"
          "CommitDate: $gitCommitDateRaw",
    );
  }
}
