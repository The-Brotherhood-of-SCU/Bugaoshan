import 'dart:convert';
import 'dart:js_interop';

import 'package:bugaoshan/utils/app_log.dart';

import 'native_bridge.dart';
import 'viewport_metrics.dart';

@JS('bugaoshanViewportChanged')
external set _viewportChanged(JSFunction callback);

@JS('document.querySelector')
external _ViewportMeta? _queryViewportMeta(JSString selector);

extension type _ViewportMeta(JSObject _) implements JSObject {
  external JSString get content;
  external set content(JSString value);
}

void _updateMetrics(Object? value) {
  if (value is Map<String, dynamic>) {
    arkWebViewportMetrics.value = ArkWebViewportMetrics.fromMap(value);
  }
}

Future<void> initializeArkWebViewport() async {
  // Flutter 引擎会替换 HTML 中的 viewport 标签，因此在引擎初始化后补上 cover。
  final meta = _queryViewportMeta('meta[name="viewport"]'.toJS);
  if (meta != null) {
    final settings = meta.content.toDart
        .split(',')
        .where((setting) => !setting.trim().startsWith('viewport-fit='));
    meta.content = '${settings.join(', ')}, viewport-fit=cover'.toJS;
  }
  // 先订阅再读取，首次布局和后续旋转、系统栏及键盘变化使用同一份数据。
  _viewportChanged = ((JSString serialized) {
    try {
      _updateMetrics(jsonDecode(serialized.toDart));
    } catch (error) {
      AppLog.w('ArkWebViewport', '解析窗口安全区失败: $error');
    }
  }).toJS;
  try {
    _updateMetrics(
      await invokeArkWeb(
        'window.getMetrics',
      ).timeout(const Duration(seconds: 5)),
    );
  } catch (error) {
    AppLog.w('ArkWebViewport', '读取初始窗口安全区失败: $error');
  }
}
