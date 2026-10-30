import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/service_applications_provider.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

part 'service_applications_pods.g.dart';

class ServiceApplicationsState {
  final List<Map<String, dynamic>> items;
  final ServiceApplicationsLoadState loadState;
  final LoadErrorType? error;

  ServiceApplicationsLoadState get state => loadState;

  const ServiceApplicationsState({
    this.items = const [],
    this.loadState = ServiceApplicationsLoadState.idle,
    this.error,
  });

  ServiceApplicationsState copyWith({
    List<Map<String, dynamic>>? items,
    ServiceApplicationsLoadState? loadState,
    LoadErrorType? error,
    bool clearError = false,
  }) {
    return ServiceApplicationsState(
      items: items ?? this.items,
      loadState: loadState ?? this.loadState,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

@Riverpod(keepAlive: true)
class ServiceApplicationsNotifier extends _$ServiceApplicationsNotifier {
  static const String _tag = 'ServiceApplicationsNotifier';
  int _generation = 0;

  @override
  ServiceApplicationsState build() {
    if (getIt.isRegistered<ServiceApplicationsProvider>()) {
      final legacy = getIt<ServiceApplicationsProvider>();
      void listener() {
        state = ServiceApplicationsState(
          items: legacy.items,
          loadState: legacy.state,
          error: legacy.error,
        );
      }

      legacy.addListener(listener);
      ref.onDispose(() => legacy.removeListener(listener));

      return ServiceApplicationsState(
        items: legacy.items,
        loadState: legacy.state,
        error: legacy.error,
      );
    }

    return const ServiceApplicationsState();
  }

  Future<void> ensureLoaded() => _load(force: false);

  Future<void> refresh() => _load(force: true);

  Future<void> _load({required bool force}) async {
    if (getIt.isRegistered<ServiceApplicationsProvider>()) {
      final legacy = getIt<ServiceApplicationsProvider>();
      if (force) {
        await legacy.refresh();
      } else {
        await legacy.ensureLoaded();
      }
      return;
    }

    if (state.loadState == ServiceApplicationsLoadState.loading) return;
    if (!force && state.loadState == ServiceApplicationsLoadState.loaded) return;

    final generation = ++_generation;
    state = state.copyWith(
      loadState: ServiceApplicationsLoadState.loading,
      clearError: true,
    );

    try {
      final api = ref.read(serviceApiServiceBridge);
      final items = await api.fetchMyApplications();
      if (generation != _generation) return;
      state = ServiceApplicationsState(
        items: items,
        loadState: ServiceApplicationsLoadState.loaded,
      );
    } on UnauthenticatedException catch (logError, logStackTrace) {
      AppLog.e(_tag, '_load 失败', error: logError, stackTrace: logStackTrace);
      if (generation != _generation) return;
      state = state.copyWith(
        loadState: ServiceApplicationsLoadState.error,
        error: LoadErrorType.sessionExpired,
      );
    } on ServiceException catch (logError, logStackTrace) {
      AppLog.e(_tag, '_load 失败', error: logError, stackTrace: logStackTrace);
      if (generation != _generation) return;
      state = state.copyWith(
        loadState: ServiceApplicationsLoadState.error,
        error: campusNetworkErrorType(LoadErrorType.loadFailed),
      );
    } catch (logError, logStackTrace) {
      AppLog.e(_tag, '_load 失败', error: logError, stackTrace: logStackTrace);
      if (generation != _generation) return;
      state = state.copyWith(
        loadState: ServiceApplicationsLoadState.error,
        error: campusNetworkErrorType(LoadErrorType.loadFailed),
      );
    }
  }

  void clear() {
    if (getIt.isRegistered<ServiceApplicationsProvider>()) {
      getIt<ServiceApplicationsProvider>().clear();
      return;
    }
    _generation++;
    state = const ServiceApplicationsState();
  }
}
