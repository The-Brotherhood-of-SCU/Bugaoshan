import 'dart:math';

import 'package:flutter/widgets.dart';

/// 给滚动容器的显式 `padding` 补上系统底部 inset。
///
/// 系统栏（三键 / 手势导航条、iPhone Home indicator）的避让在 Flutter 里是
/// 「环境 `MediaQuery.padding` + 由滚动组件自己消费」的协作：`BoxScrollView`
/// 只有在 `padding == null` 时才把环境 padding 转成自己的 `SliverPadding`
/// （见 `scroll_view.dart` → `buildSlivers`）。页面一旦给滚动容器写死
/// `padding`，这份避让就整个消失，系统栏会压住最后一行内容 —— Android 15+
/// 强制 edge-to-edge 后，三键导航条尤其明显（#379）。
///
/// 因此凡是自己写死 `padding` 的滚动容器，都要用它把系统栏的避让补回底边：
///
/// ```dart
/// padding: withSystemBottomInset(context, const EdgeInsets.all(16)),
/// ```
///
/// 补的是「至少留出系统栏那么高」，即底边取 `max(原 padding, 系统 inset)`
/// **而非相加**：系统栏的高度是内容与屏幕底边之间必须留出的下限，原 padding
/// 已经比它大时（例如 `EdgeInsets.only(bottom: 96)`）再加一条只会多出一段死白。
///
/// 取 `padding` 而非 `viewPadding`：键盘弹起时 `padding` 归零，底部空间正好
/// 由 `Scaffold.resizeToAvoidBottomInset` 接管，不会多留一段空白。
EdgeInsets withSystemBottomInset(BuildContext context, EdgeInsets padding) {
  final bottom = MediaQuery.paddingOf(context).bottom;
  if (bottom == 0) return padding;
  return padding.copyWith(bottom: max(padding.bottom, bottom));
}
