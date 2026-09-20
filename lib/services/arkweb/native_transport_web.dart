import 'dart:js_interop';

@JS('bugaoshanNative')
external _NativeBridge? get _nativeBridge;

extension type _NativeBridge(JSObject _) implements JSObject {
  external JSPromise<JSString> invoke(JSString request);
}

bool get isArkWebNativeAvailable => _nativeBridge != null;

Future<String> invokeArkWebNative(String request) async {
  final bridge = _nativeBridge;
  if (bridge == null) {
    throw StateError('ArkWeb native bridge was not registered before Flutter.');
  }
  return (await bridge.invoke(request.toJS).toDart).toDart;
}
