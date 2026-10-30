import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/version_info.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';

part 'app_info_pods.g.dart';

class AppInfoState {
  final String currentVersion;
  final String gitTag;
  final String gitCommit;
  final String gitCommitDateRaw;
  final String shortCommit;
  final bool isFdroidInstall;

  const AppInfoState({
    required this.currentVersion,
    required this.gitTag,
    required this.gitCommit,
    required this.gitCommitDateRaw,
    required this.shortCommit,
    required this.isFdroidInstall,
  });
}

@Riverpod(keepAlive: true)
class AppInfoNotifier extends _$AppInfoNotifier {
  @override
  AppInfoState build() {
    final legacy = _getProvider();
    return AppInfoState(
      currentVersion: legacy.currentVersion,
      gitTag: legacy.gitTag,
      gitCommit: legacy.gitCommit,
      gitCommitDateRaw: legacy.gitCommitDateRaw,
      shortCommit: legacy.shortCommit,
      isFdroidInstall: legacy.isFdroidInstall,
    );
  }

  AppInfoProvider _getProvider() {
    return getIt.isRegistered<AppInfoProvider>()
        ? getIt<AppInfoProvider>()
        : ref.watch(appInfoProviderBridge);
  }

  Future<VersionInfo> getVersionInfo() async {
    final legacy =
        getIt.isRegistered<AppInfoProvider>()
            ? getIt<AppInfoProvider>()
            : ref.read(appInfoProviderBridge);
    return legacy.getVersionInfo();
  }
}
