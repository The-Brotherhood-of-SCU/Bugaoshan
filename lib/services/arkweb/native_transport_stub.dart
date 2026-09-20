bool get isArkWebNativeAvailable => false;

Future<String> invokeArkWebNative(String request) async {
  throw UnsupportedError('ArkWeb native bridge is only available in ArkWeb.');
}
