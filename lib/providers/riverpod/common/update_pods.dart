import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/release_info.dart';
import 'package:bugaoshan/providers/update_provider.dart';
import 'package:bugaoshan/services/update_service.dart';

part 'update_pods.g.dart';

class UpdateState {
  final bool isChecking;
  final UpdateCheckResult? lastCheckResult;
  final UpdateCheckResult stableResult;
  final UpdateCheckResult previewResult;
  final bool isDownloading;
  final String? downloadingVersion;
  final int downloadPercent;
  final String downloadStatus;

  UpdateState({
    this.isChecking = false,
    this.lastCheckResult,
    UpdateCheckResult? stableResult,
    UpdateCheckResult? previewResult,
    this.isDownloading = false,
    this.downloadingVersion,
    this.downloadPercent = 0,
    this.downloadStatus = '',
  })  : stableResult = stableResult ?? UpdateCheckResult.initial(),
        previewResult = previewResult ?? UpdateCheckResult.initial();

  UpdateState copyWith({
    bool? isChecking,
    UpdateCheckResult? Function()? lastCheckResult,
    UpdateCheckResult? stableResult,
    UpdateCheckResult? previewResult,
    bool? isDownloading,
    String? Function()? downloadingVersion,
    int? downloadPercent,
    String? downloadStatus,
  }) {
    return UpdateState(
      isChecking: isChecking ?? this.isChecking,
      lastCheckResult:
          lastCheckResult != null ? lastCheckResult() : this.lastCheckResult,
      stableResult: stableResult ?? this.stableResult,
      previewResult: previewResult ?? this.previewResult,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadingVersion:
          downloadingVersion != null
              ? downloadingVersion()
              : this.downloadingVersion,
      downloadPercent: downloadPercent ?? this.downloadPercent,
      downloadStatus: downloadStatus ?? this.downloadStatus,
    );
  }
}

@Riverpod(keepAlive: true)
class UpdateNotifier extends _$UpdateNotifier {
  @override
  UpdateState build() {
    if (getIt.isRegistered<UpdateProvider>()) {
      final legacy = getIt<UpdateProvider>();
      void listener() {
        state = UpdateState(
          isChecking: legacy.isChecking.value,
          lastCheckResult: legacy.lastCheckResult.value,
          stableResult: legacy.stableResult.value,
          previewResult: legacy.previewResult.value,
          isDownloading: legacy.isDownloading.value,
          downloadingVersion: legacy.downloadingVersion.value,
          downloadPercent: legacy.progressState.percent,
          downloadStatus: legacy.progressState.status,
        );
      }

      final merge = Listenable.merge([
        legacy.isChecking,
        legacy.lastCheckResult,
        legacy.stableResult,
        legacy.previewResult,
        legacy.isDownloading,
        legacy.downloadingVersion,
        legacy.progressState,
      ]);

      merge.addListener(listener);
      ref.onDispose(() => merge.removeListener(listener));

      return UpdateState(
        isChecking: legacy.isChecking.value,
        lastCheckResult: legacy.lastCheckResult.value,
        stableResult: legacy.stableResult.value,
        previewResult: legacy.previewResult.value,
        isDownloading: legacy.isDownloading.value,
        downloadingVersion: legacy.downloadingVersion.value,
        downloadPercent: legacy.progressState.percent,
        downloadStatus: legacy.progressState.status,
      );
    }

    return UpdateState();
  }

  bool get supportsInAppUpdate {
    if (getIt.isRegistered<UpdateProvider>()) {
      return getIt<UpdateProvider>().supportsInAppUpdate;
    }
    return false;
  }

  bool hasUpdate(String currentVersion, String latestVersion) {
    if (getIt.isRegistered<UpdateProvider>()) {
      return getIt<UpdateProvider>().hasUpdate(currentVersion, latestVersion);
    }
    return false;
  }

  Future<UpdateCheckResult> checkForUpdate() async {
    if (getIt.isRegistered<UpdateProvider>()) {
      return getIt<UpdateProvider>().checkForUpdate();
    }
    return UpdateCheckResult.noUpdate();
  }

  Future<(ReleaseInfo?, ReleaseInfo?)> getAllLatestReleases() async {
    if (getIt.isRegistered<UpdateProvider>()) {
      return getIt<UpdateProvider>().getAllLatestReleases();
    }
    return (null, null);
  }

  Future<void> downloadAndInstall({
    required String version,
    required String downloadUrl,
    required String filename,
    String? checksumSha256,
  }) async {
    if (getIt.isRegistered<UpdateProvider>()) {
      return getIt<UpdateProvider>().downloadAndInstall(
        version: version,
        downloadUrl: downloadUrl,
        filename: filename,
        checksumSha256: checksumSha256,
      );
    }
  }

  void cancelDownload() {
    if (getIt.isRegistered<UpdateProvider>()) {
      getIt<UpdateProvider>().cancelDownload();
    }
  }
}
