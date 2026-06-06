/// Authentication contract for services that sit behind SCU unified auth.
///
/// Each subsystem owns its own SSO/token handshake and declares only the
/// subsystem auths it truly depends on. Independent dependencies run in
/// parallel; the current subsystem runs after all dependencies are ready.
abstract interface class SubsystemAuth {
  String get moduleId;

  List<SubsystemAuth> get dependencies;

  Future<void> ensureAuthenticated();

  void invalidate();
}

Future<void> ensureAuthDependencies(Iterable<SubsystemAuth> dependencies) {
  return Future.wait(dependencies.map((auth) => auth.ensureAuthenticated()));
}
