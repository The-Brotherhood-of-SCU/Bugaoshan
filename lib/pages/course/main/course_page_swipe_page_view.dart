import 'package:flutter/material.dart';

import 'package:bugaoshan/widgets/common/swipe_page_view.dart';

/// 课表周次滑动容器。
///
/// 实现已抽到通用组件 [SwipePageView]（与成绩、体测、在线报修、校历等
/// 左右 + 上下双滑页面共用），本类仅保留课表页调用点的原有命名与参数。
class CourseSwipePageView extends StatelessWidget {
  final PageController controller;
  final int itemCount;
  final Duration animationDuration;
  final void Function(int index) onPageChanged;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const CourseSwipePageView({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.animationDuration,
    required this.onPageChanged,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SwipePageView(
      controller: controller,
      itemCount: itemCount,
      animationDuration: animationDuration,
      onPageChanged: onPageChanged,
      itemBuilder: itemBuilder,
    );
  }
}
