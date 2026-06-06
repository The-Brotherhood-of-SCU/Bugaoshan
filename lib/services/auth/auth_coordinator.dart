import 'package:flutter/foundation.dart';
import 'package:bugaoshan/services/auth/subsystem_auth.dart';

/// Coordinates subsystem authentication after SCU unified auth is ready.
///
/// Every module is scheduled immediately, but each one only waits for its own
/// declared dependencies. If a dependency fails, only its downstream modules
/// are skipped.
class AuthCoordinator {
  final List<SubsystemAuth> _modules;
  Future<void>? _warmUpFuture;

  AuthCoordinator(Iterable<SubsystemAuth> modules)
    : _modules = List.unmodifiable(modules);

  Future<void> warmUpAll() {
    if (_warmUpFuture != null) return _warmUpFuture!;
    _warmUpFuture = _warmUpAll();
    _warmUpFuture!.whenComplete(() => _warmUpFuture = null);
    return _warmUpFuture!;
  }

  Future<void> _warmUpAll() async {
    final futures = <SubsystemAuth, Future<bool>>{};

    Future<bool> ensure(SubsystemAuth auth, Set<SubsystemAuth> path) {
      final existing = futures[auth];
      if (existing != null) return existing;

      final future = () async {
        if (path.contains(auth)) {
          debugPrint('AuthCoordinator: dependency cycle at ${auth.moduleId}');
          return false;
        }

        final nextPath = {...path, auth};
        final dependencyResults = await Future.wait(
          auth.dependencies.map((dep) => ensure(dep, nextPath)),
        );
        if (dependencyResults.any((ok) => !ok)) {
          debugPrint(
            'AuthCoordinator: skip ${auth.moduleId}, dependency failed',
          );
          return false;
        }

        try {
          await auth.ensureAuthenticated();
          return true;
        } catch (e) {
          debugPrint('AuthCoordinator: ${auth.moduleId} auth failed: $e');
          return false;
        }
      }();

      futures[auth] = future;
      return future;
    }

    await Future.wait(_modules.map((auth) => ensure(auth, const {})));
  }

  void invalidateAll() {
    for (final module in _modules) {
      module.invalidate();
    }
  }
}
