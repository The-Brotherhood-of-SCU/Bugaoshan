import 'dart:io';
import 'dart:ui';

import 'package:flutter/rendering.dart' show RenderBox;
import 'package:flutter/widgets.dart' show BuildContext, View;
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus, XFile;

/// share_plus 的 Windows 兼容垫片。
///
/// [fluttercommunity/plus_plugins#3619](https://github.com/fluttercommunity/plus_plugins/issues/3619)
/// 报告 `share_plus ^11.0.0` 的新 API `SharePlus.instance.share(...)` 在
/// Windows 10/11 上无法调起分享面板，根因疑似 Windows 原生层对路径分隔符
/// 的处理（`/` vs `\`）。把路径里的 `/` 全部替换成 `\` 后即可正常工作。
///
/// 其他平台（macOS / Linux / Android / iOS）不受影响，路径原样透传。

/// 把 [path] 在 Windows 上规整成反斜杠形式；其他平台直接返回原值。
String normalizeSharePath(String path) =>
    Platform.isWindows ? path.replaceAll('/', '\\') : path;

XFile _toXFile(String path) => XFile(normalizeSharePath(path));

/// 计算分享面板的弹出锚点。iPad 要求该区域非空且位于当前视图坐标内。
Rect sharePositionOriginForContext(BuildContext context, {Rect? preferred}) {
  if (preferred != null && !preferred.isEmpty) return preferred;

  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox &&
      renderObject.hasSize &&
      !renderObject.size.isEmpty) {
    final origin = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    if (!origin.isEmpty) return origin;
  }

  final view = View.of(context);
  final logicalSize = view.physicalSize / view.devicePixelRatio;
  return Rect.fromLTWH(logicalSize.width / 2, logicalSize.height / 2, 1, 1);
}

/// 分享单个文件。封装 `SharePlus.instance.share(...)`，自动处理 Windows
/// 路径分隔符问题。
Future<void> shareSingleFile(
  String path, {
  required BuildContext context,
  String? text,
  Rect? sharePositionOrigin,
}) {
  final file = _toXFile(path);
  return SharePlus.instance.share(
    ShareParams(
      files: [file],
      text: text,
      sharePositionOrigin: sharePositionOriginForContext(
        context,
        preferred: sharePositionOrigin,
      ),
    ),
  );
}

/// 分享多个文件。封装 `SharePlus.instance.share(...)`，自动处理 Windows
/// 路径分隔符问题。
Future<void> shareMultipleFiles(
  List<String> paths, {
  required BuildContext context,
  String? text,
  Rect? sharePositionOrigin,
}) {
  return SharePlus.instance.share(
    ShareParams(
      files: [for (final p in paths) _toXFile(p)],
      text: text,
      sharePositionOrigin: sharePositionOriginForContext(
        context,
        preferred: sharePositionOrigin,
      ),
    ),
  );
}
