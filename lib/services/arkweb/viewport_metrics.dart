import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/json_utils.dart';

import 'native_bridge.dart';

final arkWebViewportMetrics = ValueNotifier<ArkWebViewportMetrics?>(null);

@immutable
class ArkWebViewportMetrics {
  const ArkWebViewportMetrics({
    required this.physicalPadding,
    required this.keyboardVisible,
  });

  factory ArkWebViewportMetrics.fromMap(Map<Object?, Object?> value) {
    final padding = value['padding'];
    if (padding is! Map) {
      throw const FormatException('Invalid ArkWeb viewport padding.');
    }
    return ArkWebViewportMetrics(
      physicalPadding: EdgeInsets.fromLTRB(
        _inset(padding['left']),
        _inset(padding['top']),
        _inset(padding['right']),
        _inset(padding['bottom']),
      ),
      keyboardVisible: safeBool(value['keyboardVisible']),
    );
  }

  final EdgeInsets physicalPadding;
  final bool keyboardVisible;

  static double _inset(Object? value) {
    final number = safeDouble(value);
    return number.isFinite ? math.max(0.0, number) : 0.0;
  }

  MediaQueryData applyTo(MediaQueryData data) {
    final nativePadding = physicalPadding / data.devicePixelRatio;
    final viewPadding = EdgeInsets.fromLTRB(
      math.max(data.viewPadding.left, nativePadding.left),
      math.max(data.viewPadding.top, nativePadding.top),
      math.max(data.viewPadding.right, nativePadding.right),
      math.max(data.viewPadding.bottom, nativePadding.bottom),
    );
    return data.copyWith(
      viewPadding: viewPadding,
      padding: EdgeInsets.fromLTRB(
        math.max(0.0, viewPadding.left - data.viewInsets.left),
        math.max(0.0, viewPadding.top - data.viewInsets.top),
        math.max(0.0, viewPadding.right - data.viewInsets.right),
        keyboardVisible
            ? 0.0
            : math.max(0.0, viewPadding.bottom - data.viewInsets.bottom),
      ),
      // 键盘由 ArkWeb 缩小内容区，保留 Flutter 已计算的 viewInsets，避免重复避让。
    );
  }
}

Future<void> setArkWebSystemBarBrightness(Brightness brightness) async {
  if (arkWebViewportMetrics.value == null) return;
  try {
    await invokeArkWeb('window.setSystemBarStyle', {
      'dark': brightness == Brightness.dark,
    }).timeout(const Duration(seconds: 5));
  } catch (error) {
    AppLog.w('ArkWebViewport', '设置系统栏颜色失败: $error');
  }
}
