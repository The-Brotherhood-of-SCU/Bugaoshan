import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/utils/storage_keys.dart';

part 'user_info_pods.g.dart';

class UserInfoState {
  final List<Map<String, dynamic>>? labels;
  final Map<String, dynamic>? profile;
  final String? userRealname;
  final String? userNumber;

  const UserInfoState({
    this.labels,
    this.profile,
    this.userRealname,
    this.userNumber,
  });

  bool get hasData => labels != null || profile != null;
}

@Riverpod(keepAlive: true)
class UserInfoNotifier extends _$UserInfoNotifier {
  @override
  FutureOr<UserInfoState> build() async {
    final wfwAuth = ref.watch(wfwAuthBridge);
    if (!wfwAuth.isReady) {
      if (wfwAuth.state == AuthState.unknown) {
        unawaited(_persistUserInfo(null, null));
      }
      return const UserInfoState();
    }

    final api = ref.watch(wfwApiServiceBridge);
    final results = await Future.wait([
      api.fetchUserProfile(),
      api.fetchProfileLabels(),
    ]);

    final profile = results[0] as Map<String, dynamic>?;
    final labels = results[1] as List<Map<String, dynamic>>?;
    final realname = profile?['realname']?.toString();
    final role = profile?['role'];
    final number = role is Map ? role['number']?.toString() : null;

    if (getIt.isRegistered<ScuAuthProvider>()) {
      getIt<ScuAuthProvider>().setUserInfo(realname, number);
    }
    await _persistUserInfo(realname, number);

    return UserInfoState(
      profile: profile,
      labels: labels,
      userRealname: realname,
      userNumber: number,
    );
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
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
