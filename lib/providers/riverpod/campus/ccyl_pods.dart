import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/scu_backend/ccyl/ccyl_auth.dart';

part 'ccyl_pods.g.dart';

final ccylAuthNotifierProvider = ccylAuthProvider;

@Riverpod(keepAlive: true)
class CcylAuthNotifier extends _$CcylAuthNotifier {
  @override
  CcylAuthState build() {
    if (getIt.isRegistered<CcylAuth>()) {
      final ccylAuth = ref.watch(ccylAuthBridge);
      void listener() {
        state = CcylAuthState(
          isLoggedIn: ccylAuth.isLoggedIn,
          token: ccylAuth.token,
          currentUser: ccylAuth.currentUser,
        );
      }

      ccylAuth.addListener(listener);
      ref.onDispose(() => ccylAuth.removeListener(listener));

      return CcylAuthState(
        isLoggedIn: ccylAuth.isLoggedIn,
        token: ccylAuth.token,
        currentUser: ccylAuth.currentUser,
      );
    }

    if (getIt.isRegistered<CcylProvider>()) {
      final ccylProvider = getIt<CcylProvider>();
      CcylAuthState buildFromLegacy() {
        String? token;
        try {
          token = ccylProvider.token;
        } catch (_) {}
        CcylUser? user;
        try {
          user = ccylProvider.currentUser;
        } catch (_) {}
        return CcylAuthState(
          isLoggedIn: ccylProvider.isLoggedIn,
          token: token,
          currentUser: user,
        );
      }

      void listener() {
        state = buildFromLegacy();
      }

      ccylProvider.addListener(listener);
      ref.onDispose(() => ccylProvider.removeListener(listener));

      return buildFromLegacy();
    }

    return const CcylAuthState(isLoggedIn: false);
  }

  Future<void> loginWithOAuthCode(String code) async {
    if (getIt.isRegistered<CcylAuth>()) {
      final ccylAuth = ref.read(ccylAuthBridge);
      await ccylAuth.loginWithCode(code);
    } else if (getIt.isRegistered<CcylProvider>()) {
      await getIt<CcylProvider>().loginWithOAuthCode(code);
    }
  }

  Future<void> logout() async {
    if (getIt.isRegistered<CcylAuth>()) {
      final ccylAuth = ref.read(ccylAuthBridge);
      await ccylAuth.logout();
    } else if (getIt.isRegistered<CcylProvider>()) {
      await getIt<CcylProvider>().logout();
    }
  }

  Future<bool> reLogin() async {
    if (getIt.isRegistered<CcylAuth>()) {
      final ccylAuth = ref.read(ccylAuthBridge);
      return ccylAuth.reLogin();
    } else if (getIt.isRegistered<CcylProvider>()) {
      await getIt<CcylProvider>().reLogin();
      return true;
    }
    return false;
  }
}

class CcylAuthState {
  final bool isLoggedIn;
  final String? token;
  final CcylUser? currentUser;

  const CcylAuthState({
    required this.isLoggedIn,
    this.token,
    this.currentUser,
  });
}
