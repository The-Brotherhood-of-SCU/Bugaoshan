import 'package:flutter/widgets.dart';

/// 浮动 Dock 的内容避让距离。滚动 viewport 仍铺到底部，只有内容末尾留白。
/// 在 Home 以外的详情页默认 0，避免改变共用课表等组件的布局。
class HomeDockInsets extends InheritedWidget {
  const HomeDockInsets({super.key, required this.bottom, required super.child});

  final double bottom;

  static double bottomOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeDockInsets>()?.bottom ?? 0;

  /// 屏蔽子树里被 `extendBody` 注入的底部 padding。
  ///
  /// Home 的 `extendBody` 会把整个浮动 Dock 的高度写进 body 的
  /// `MediaQuery.padding.bottom`。未逐页适配的入口由 Home 在外层做整页避让，
  /// 页面内部的嵌套 Scaffold / `NavigationBar` 不应再消费同一份 padding：
  /// 否则会被各自的 `SafeArea` 撑高，在内层底栏与 Dock 之间留出空白
  /// （见 #376：第二课堂页）。已适配的三张主页自行读取 [bottomOf]，不受影响。
  static Widget consumed({
    required BuildContext context,
    required Widget child,
  }) => MediaQuery.removePadding(
    context: context,
    removeBottom: true,
    child: child,
  );

  @override
  bool updateShouldNotify(HomeDockInsets oldWidget) =>
      bottom != oldWidget.bottom;
}

/// 在 Scaffold 的 body 内读取 extendBody 注入的底部空间。
class HomeDockBody extends StatelessWidget {
  const HomeDockBody({super.key, required this.extended, required this.child});

  final bool extended;
  final Widget child;

  @override
  Widget build(BuildContext context) => HomeDockInsets(
    bottom: extended ? MediaQuery.paddingOf(context).bottom : 0,
    child: SafeArea(bottom: !extended, child: child),
  );
}
