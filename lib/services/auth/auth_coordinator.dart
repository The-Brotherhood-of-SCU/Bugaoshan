import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/auth/subsystem_auth.dart';
import 'package:bugaoshan/utils/app_logger.dart';

/// Coordinates subsystem authentication after SCU unified auth is ready.
///
/// Every module is scheduled immediately, but each one only waits for its own
/// declared dependencies. If a dependency fails, only its downstream modules
/// are skipped.
class AuthCoordinator {
  static const String _tag = 'AuthCoordinator';
  static const Duration _defaultFailedRetryDelay = Duration(seconds: 10);

  final List<SubsystemAuth> _modules;
  final AppLogger _log;

  /// 失败模块补热前的退避时长（测试可注入缩短）。
  final Duration failedRetryDelay;

  Future<void>? _warmUpFuture;

  /// 守卫延迟补热轮：warmUpAll 新一轮或 invalidateAll（登出）都会递增，
  /// 过期的补热直接放弃。
  int _epoch = 0;

  AuthCoordinator(
    Iterable<SubsystemAuth> modules, {
    AppLogger? logger,
    this.failedRetryDelay = _defaultFailedRetryDelay,
  }) : _modules = List.unmodifiable(modules),
       _log = logger ?? getIt<AppLogger>();

  Future<void> warmUpAll() {
    if (_warmUpFuture != null) return _warmUpFuture!;
    _epoch++;
    _log.i(_tag, 'warmUpAll: starting for ${_modules.length} modules');
    final future = _warmUpAll(_epoch);
    _warmUpFuture = future;
    future.whenComplete(() {
      _log.i(_tag, 'warmUpAll: completed');
      // 仅清理仍指向本次的缓存：避免 invalidateAll 后新一轮 warmUpAll 的
      // future 被旧 whenComplete 回调误清。
      if (identical(_warmUpFuture, future)) _warmUpFuture = null;
    });
    return future;
  }

  Future<void> _warmUpAll(int epoch) async {
    final failed = await _ensureRound(_modules);
    if (failed.isEmpty) return;

    _log.w(
      _tag,
      'warmUpAll: ${failed.length} module(s) failed, retrying in '
      '${failedRetryDelay.inSeconds}s: '
      '${failed.map((m) => m.moduleId).join(', ')}',
    );
    await Future<void>.delayed(failedRetryDelay);
    if (epoch != _epoch) {
      _log.d(_tag, 'warmUpAll: stale retry skipped (new round or invalidated)');
      return;
    }
    final stillFailed = await _ensureRound(failed);
    if (stillFailed.isNotEmpty) {
      _log.w(
        _tag,
        'warmUpAll: retry still failed: '
        '${stillFailed.map((m) => m.moduleId).join(', ')}',
      );
    }
  }

  /// 跑一轮 ensure（可传入上一轮失败的模块做定向补热），返回失败的模块。
  /// 依赖失败被跳过的模块同样计入失败，补热时会随依赖一起重试。
  Future<List<SubsystemAuth>> _ensureRound(
    Iterable<SubsystemAuth> targets,
  ) async {
    final futures = <SubsystemAuth, Future<bool>>{};

    Future<bool> ensure(SubsystemAuth auth, Set<SubsystemAuth> path) {
      final existing = futures[auth];
      if (existing != null) return existing;

      final moduleId = auth.moduleId;
      _log.d(_tag, 'ensure: start module=$moduleId');
      final future = () async {
        if (path.contains(auth)) {
          _log.w(_tag, 'ensure: dependency cycle at $moduleId');
          return false;
        }

        final nextPath = {...path, auth};
        final dependencyResults = await Future.wait(
          auth.dependencies.map((dep) => ensure(dep, nextPath)),
        );
        if (dependencyResults.any((ok) => !ok)) {
          _log.w(_tag, 'ensure: skip $moduleId, dependency failed');
          return false;
        }

        try {
          await auth.ensureAuthenticated();
          _log.i(_tag, 'ensure: ok module=$moduleId');
          return true;
        } catch (e) {
          _log.e(_tag, 'ensure: $moduleId auth failed: $e');
          return false;
        }
      }();

      futures[auth] = future;
      return future;
    }

    await Future.wait(targets.map((auth) => ensure(auth, const {})));

    final failed = <SubsystemAuth>[];
    for (final entry in futures.entries) {
      if (!await entry.value) failed.add(entry.key);
    }
    return failed;
  }

  void invalidateAll() {
    _warmUpFuture = null;
    _epoch++;
    _log.d(_tag, 'invalidateAll');
    for (final module in _modules) {
      module.invalidate();
    }
  }
}
