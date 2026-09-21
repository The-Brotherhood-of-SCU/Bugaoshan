import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:bugaoshan/utils/app_log.dart';

import 'native_bridge.dart';

const _family = 'BugaoshanNotoSansSC';
const _fontFiles = [
  'NotoSansSC-Regular.woff2',
  'NotoSansSC-Medium.woff2',
  'NotoSansSC-SemiBold.woff2',
  'NotoSansSC-Bold.woff2',
];
bool _loaded = false;

/// 仅在鸿蒙本地字体加载完成后提供字体族，其他平台沿用原有主题。
String? get arkWebFontFamily => _loaded ? _family : null;

Future<void> initializeArkWebFonts(Uri documentBaseUri) async {
  if (_loaded || !kIsWeb || !isArkWebNativeAvailable) return;

  // web/fonts 随 Web 构建复制，不属于 rootBundle 的 assets。
  // 这里走浏览器请求，由鸿蒙本地资源拦截响应，不走校园网 HTTP 代理。
  final client = http.Client();
  try {
    final loader = FontLoader(_family);
    for (final file in _fontFiles) {
      final response = await client
          .get(documentBaseUri.resolve('fonts/$file'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw StateError(
          'Cannot load bundled font $file (HTTP ${response.statusCode}). '
          'Rebuild Flutter Web and copy the complete build/web directory.',
        );
      }
      loader.addFont(Future.value(ByteData.sublistView(response.bodyBytes)));
    }
    await loader.load();
    _loaded = true;
    AppLog.i('ArkWebFonts', '本地 Noto Sans SC 字体已加载');
  } catch (error) {
    AppLog.e('ArkWebFonts', '加载本地 Noto Sans SC 字体失败: $error');
    rethrow;
  } finally {
    client.close();
  }
}
