import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/services/auth/auth_coordinator.dart';
import 'package:bugaoshan/services/auth/subsystem_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';

class _FakeModule implements SubsystemAuth {
  @override
  final String moduleId;

  @override
  final List<SubsystemAuth> dependencies;

  /// 第 n 次 ensureAuthenticated 调用（1-based）应当失败。
  Set<int> failures;

  int ensureCount = 0;
  int invalidateCount = 0;

  _FakeModule(
    this.moduleId, {
    this.dependencies = const [],
    this.failures = const {},
  });

  @override
  Future<void> ensureAuthenticated() async {
    ensureCount++;
    if (failures.contains(ensureCount)) {
      throw Exception('$moduleId ensure failed (call $ensureCount)');
    }
  }

  @override
  void invalidate() {
    invalidateCount++;
  }
}

AuthCoordinator _coordinator(
  List<SubsystemAuth> modules, {
  Duration retryDelay = const Duration(milliseconds: 10),
}) {
  return AuthCoordinator(
    modules,
    logger: AuthLogger(),
    failedRetryDelay: retryDelay,
  );
}

void main() {
  group('AuthCoordinator.warmUpAll', () {
    test('全部模块一次成功时不安排补热', () async {
      final a = _FakeModule('a');
      final b = _FakeModule('b');
      await _coordinator([a, b]).warmUpAll();
      expect(a.ensureCount, 1);
      expect(b.ensureCount, 1);
    });

    test('失败模块与被连带跳过的下游在退避后补热恢复', () async {
      final wfw = _FakeModule('wfw', failures: {1});
      final payapp = _FakeModule('payapp', dependencies: [wfw]);
      await _coordinator([wfw, payapp]).warmUpAll();

      // 首轮 wfw 失败、payapp 被跳过；补热轮 wfw 重试成功后 payapp 恢复
      expect(wfw.ensureCount, 2);
      expect(payapp.ensureCount, 1);
    });

    test('补热仅进行一轮，仍失败则放弃', () async {
      final wfw = _FakeModule('wfw', failures: {1, 2});
      await _coordinator([wfw]).warmUpAll();
      expect(wfw.ensureCount, 2);
    });

    test('退避期间 invalidateAll 会取消过期补热', () async {
      final wfw = _FakeModule('wfw', failures: {1});
      final coordinator = _coordinator([
        wfw,
      ], retryDelay: const Duration(milliseconds: 200));
      final future = coordinator.warmUpAll();
      coordinator.invalidateAll();
      await future;

      expect(wfw.ensureCount, 1);
      expect(wfw.invalidateCount, 1);
    });
  });
}
