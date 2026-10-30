import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/user_info_provider.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/storage_keys.dart';

part 'user_info_pods.g.dart';

class UserInfoState {
  final List<Map<String, dynamic>>? labels;
  final Map<String, dynamic>? profile;
  final bool loading;
  final bool error;
  final String? userRealname;
  final String? userNumber;

  const UserInfoState({
    this.labels,
    this.profile,
    this.loading = false,
    this.error = false,
    this.userRealname,
    this.userNumber,
  });

  bool get hasData => labels != null;

  UserInfoState copyWith({
    List<Map<String, dynamic>>? labels,
    Map<String, dynamic>? profile,
    bool? loading,
    bool? error,
    String? userRealname,
    String? userNumber,
    bool clearLabels = false,
    bool clearProfile = false,
    bool clearRealname = false,
    bool clearNumber = false,
  }) {
    return UserInfoState(
      labels: clearLabels ? null : (labels ?? this.labels),
      profile: clearProfile ? null : (profile ?? this.profile),
      loading: loading ?? this.loading,
      error: error ?? this.error,
      userRealname: clearRealname ? null : (userRealname ?? this.userRealname),
      userNumber: clearNumber ? null : (userNumber ?? this.userNumber),
    );
  }
}

@Riverpod(keepAlive: true)
class UserInfoNotifier extends _$UserInfoNotifier {
  static const String _tag = 'UserInfoNotifier';

  int _generation = 0;
  AuthState _lastAuthState = AuthState.unknown;

  @override
  UserInfoState build() {
    if (getIt.isRegistered<UserInfoProvider>()) {
      final legacy = getIt<UserInfoProvider>();
      void listener() {
        state = UserInfoState(
          labels: legacy.labels,
          profile: legacy.profile,
          loading: legacy.loading,
          error: legacy.error,
          userRealname: legacy.userRealname,
          userNumber: legacy.userNumber,
        );
      }

      legacy.addListener(listener);
      ref.onDispose(() => legacy.removeListener(listener));

      return UserInfoState(
        labels: legacy.labels,
        profile: legacy.profile,
        loading: legacy.loading,
        error: legacy.error,
        userRealname: legacy.userRealname,
        userNumber: legacy.userNumber,
      );
    }

    final wfwAuth = ref.watch(wfwAuthBridge);
    _lastAuthState = wfwAuth.state;

    void onAuthChanged() {
      final current = wfwAuth.state;
      final becameReady =
          current == AuthState.ready && _lastAuthState != AuthState.ready;
      _lastAuthState = current;
      if (becameReady) {
        Future.delayed(
          const Duration(milliseconds: 300),
          () => _fetchAll(++_generation),
        );
      } else if (current == AuthState.unknown) {
        clear();
      }
    }

    wfwAuth.addListener(onAuthChanged);
    ref.onDispose(() => wfwAuth.removeListener(onAuthChanged));

    if (wfwAuth.isReady) {
      Future.microtask(() => _fetchAll(++_generation));
    }

    return const UserInfoState();
  }

  Future<void> fetchLabels() async {
    if (getIt.isRegistered<UserInfoProvider>()) {
      return getIt<UserInfoProvider>().fetchLabels();
    }

    final wfwAuth = ref.read(wfwAuthBridge);
    if (state.loading || !wfwAuth.isReady) return;

    final generation = ++_generation;
    state = state.copyWith(loading: true, error: false);

    try {
      final api = ref.read(wfwApiServiceBridge);
      final labels = await api.fetchProfileLabels();
      if (generation != _generation) return;
      state = state.copyWith(labels: labels, loading: false, error: false);
    } catch (e, logStackTrace) {
      AppLog.e(_tag, 'fetchLabels 失败', error: e, stackTrace: logStackTrace);
      if (generation != _generation) return;
      state = state.copyWith(loading: false, error: true);
    }
  }

  void retry() {
    if (getIt.isRegistered<UserInfoProvider>()) {
      getIt<UserInfoProvider>().retry();
      return;
    }

    state = state.copyWith(error: false);
    final wfwAuth = ref.read(wfwAuthBridge);
    if (wfwAuth.isReady) {
      _fetchAll(++_generation);
    } else {
      unawaited(
        wfwAuth
            .ensureAuthenticated()
            .then((_) {
              if (wfwAuth.isReady) {
                _fetchAll(++_generation);
              }
            })
            .catchError((Object error, StackTrace stackTrace) {
              AppLog.e(
                _tag,
                '后台获取用户信息失败',
                error: error,
                stackTrace: stackTrace,
              );
            }),
      );
    }
  }

  void clear() {
    if (getIt.isRegistered<UserInfoProvider>()) {
      getIt<UserInfoProvider>().clear();
      return;
    }

    _generation++;
    state = const UserInfoState();
    unawaited(_persistUserInfo(null, null));
  }

  Future<void> _fetchAll(int generation) async {
    if (generation != _generation) return;
    state = state.copyWith(loading: true, error: false);

    try {
      final api = ref.read(wfwApiServiceBridge);
      final results = await Future.wait([
        api.fetchUserProfile(),
        api.fetchProfileLabels(),
      ]);

      if (generation != _generation) return;

      final profile = results[0] as Map<String, dynamic>?;
      final labels = results[1] as List<Map<String, dynamic>>?;
      final realname = profile?['realname']?.toString();
      final role = profile?['role'];
      final number = role is Map ? role['number']?.toString() : null;

      if (getIt.isRegistered<ScuAuthProvider>()) {
        getIt<ScuAuthProvider>().setUserInfo(realname, number);
      }
      await _persistUserInfo(realname, number);

      state = UserInfoState(
        profile: profile,
        labels: labels,
        userRealname: realname,
        userNumber: number,
        loading: false,
        error: false,
      );
    } catch (e, logStackTrace) {
      AppLog.e(_tag, '_fetchAll 失败', error: e, stackTrace: logStackTrace);
      if (generation != _generation) return;
      state = state.copyWith(loading: false, error: true);
    }
  }

  Future<void> _persistUserInfo(String? realname, String? number) async {
    final prefs = ref.read(sharedPreferencesBridge);
    if (realname == null) {
      await prefs.remove(kScuUserRealname);
    } else {
      await prefs.setString(kScuUserRealname, realname);
    }
    if (number == null) {
      await prefs.remove(kScuUserNumber);
    } else {
      await prefs.setString(kScuUserNumber, number);
    }
  }
}
