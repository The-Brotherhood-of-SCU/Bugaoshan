import 'package:bugaoshan/utils/app_log.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWasm, kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bugaoshan/models/version_info.dart';
import 'package:bugaoshan/providers/environment_info/native.dart';
import 'package:bugaoshan/utils/constants.dart';

class AppInfoProvider {
  static const String _tag = 'AppInfoProvider';

  /// 已知 F-Droid 客户端的包名（原生探测不可用时的兜底）。
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

  /// 判断安装来源是否为 F-Droid 系客户端。
  ///
  /// 先查兜底名单，再让原生侧探测 **installer 包** 是否注册了 F-Droid 的
  /// 「添加软件源」scheme（`fdroidrepo` / `fdroidrepos`），这样新客户端无需加名单。
  /// 探测对象是 installer 而不是「设备上有没有 F-Droid」，从 GitHub 安装的用户不受影响。
  /// 任何失败都按非 F-Droid 处理，避免误关非 F-Droid 用户的自更新。
  static Future<bool> resolveFdroidInstall(String? installerStore) async {
    if (installerStore == null || installerStore.isEmpty) return false;
    if (_fdroidInstallerStores.contains(installerStore)) return true;
    // installer 包概念只存在于 Android，其它平台的 channel 没有这个方法
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final probed = await kUpdateMethodChannel.invokeMethod<bool>(
        'isFdroidInstaller',
        {'installer': installerStore},
      );
      return probed ?? false;
    } catch (error) {
      AppLog.w(_tag, 'F-Droid 渠道探测失败，按非 F-Droid 处理', error: error);
      return false;
    }
  }

  PackageInfo packageInfo;

  /// 是否从 F-Droid 渠道安装。由 [resolveFdroidInstall] 在依赖注入阶段算好，
  /// 这里保持同步 getter ——`UpdateService.supportsInAppUpdate` 就在同步上下文使用。
  final bool isFdroidInstall;

  AppInfoProvider(this.packageInfo, {required this.isFdroidInstall}) {
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
  String get shortCommit =>
      gitCommit.length >= 7 ? gitCommit.substring(0, 7) : gitCommit;

  Future<VersionInfo> getVersionInfo() async {
    return AppLog.guard(_tag, '读取运行环境', () async {
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
    });
  }
}
