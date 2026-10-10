import 'package:flutter/widgets.dart';

/// 浮动 Dock 的内容避让距离。滚动 viewport 仍铺到底部，只有内容末尾留白。
/// 在 Home 以外的详情页默认 0，避免改变共用课表等组件的布局。
class HomeDockInsets extends InheritedWidget {
  const HomeDockInsets({super.key, required this.bottom, required super.child});

  final double bottom;

  static double bottomOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeDockInsets>()?.bottom ?? 0;

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
