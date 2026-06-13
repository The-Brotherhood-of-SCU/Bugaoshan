import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/auth/subsystem_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';

/// Coordinates subsystem authentication after SCU unified auth is ready.
///
/// Every module is scheduled immediately, but each one only waits for its own
/// declared dependencies. If a dependency fails, only its downstream modules
/// are skipped.
class AuthCoordinator {
  static const String _tag = 'AuthCoordinator';

  final List<SubsystemAuth> _modules;
  final AuthLogger _log;
  Future<void>? _warmUpFuture;

  AuthCoordinator(Iterable<SubsystemAuth> modules, {AuthLogger? logger})
    : _modules = List.unmodifiable(modules),
      _log = logger ?? getIt<AuthLogger>();

  Future<void> warmUpAll() {
    if (_warmUpFuture != null) return _warmUpFuture!;
    _log.i(_tag, 'warmUpAll: starting for ${_modules.length} modules');
    _warmUpFuture = _warmUpAll();
    _warmUpFuture!.whenComplete(() {
      _log.i(_tag, 'warmUpAll: completed');
      _warmUpFuture = null;
    });
    return _warmUpFuture!;
  }

  Future<void> _warmUpAll() async {
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

    await Future.wait(_modules.map((auth) => ensure(auth, const {})));
  }

  void invalidateAll() {
    _warmUpFuture = null;
    _log.d(_tag, 'invalidateAll');
    for (final module in _modules) {
      module.invalidate();
    }
  }
}
