import 'dart:async';

import 'package:flutter/material.dart';

import 'package:bugaoshan/theme_shape.dart';

/// 左右滑页容器：解决 PageView / TabBarView 自带手势与页内纵向滚动冲突、
/// 滑动不跟手的问题。做法与课表页一致：
///
/// - 禁用 PageView 自带滑动物理，由外层 GestureDetector 接管横向拖动，
///   手动改写 PageController 的 offset，页面严格跟手；
/// - 位移超过阈值后按「横向位移明显大于纵向」判定方向：纵向拖动不认领，
///   手势完整交给页内的 ListView / CustomScrollView；
/// - 松手时按速度或位移决定翻页或回弹。
///
/// 传 [tabController] 时与 TabBar 双向联动（点 Tab 翻页、滑页同步指示器）；
/// [keepPagesAlive] 为 true 时翻页后保留各页 State（表单内容、滚动位置），
/// 适合 Tab 页较少且含可编辑内容的页面；默认 false，与 TabBarView 行为一致。
///
/// 两种构造方式：传 [children]（类似 TabBarView，页数固定），
/// 或传 [itemCount] + [itemBuilder]（类似 PageView.builder，页数较多时）。
class SwipePageView extends StatefulWidget {
  const SwipePageView({
    super.key,
    this.controller,
    this.tabController,
    this.children,
    this.itemCount,
    this.itemBuilder,
    this.onPageChanged,
    this.animationDuration = const Duration(milliseconds: 300),
    this.keepPagesAlive = false,
  }) : assert(
         (children != null) != (itemCount != null && itemBuilder != null),
         'children 与 itemCount + itemBuilder 必须二选一',
       );

  /// 已有的 PageController（如课表页由外部管理周次）。不传则内部自建。
  final PageController? controller;

  /// 联动的 TabBar 控制器；不传则不处理 Tab 联动。
  final TabController? tabController;

  /// 固定页列表（与 [itemBuilder] 二选一）。
  final List<Widget>? children;

  /// 页数（与 [children] 二选一）。
  final int? itemCount;

  /// 页构建器（与 [children] 二选一）。
  final Widget? Function(BuildContext context, int index)? itemBuilder;

  /// 当前页变化回调（手势滑动、点 Tab、程序翻页均会触发）。
  final void Function(int index)? onPageChanged;

  /// 翻页动画时长。
  final Duration animationDuration;

  /// 翻页后是否保留各页 State。
  final bool keepPagesAlive;

  @override
  State<SwipePageView> createState() => _SwipePageViewState();
}

class _SwipePageViewState extends State<SwipePageView> {
  PageController? _internalController;
  PageController get _pageController =>
      widget.controller ?? (_internalController ??= PageController());

  double _dragStartX = 0;
  double _dragStartY = 0;
  bool? _isHorizontalDrag; // null = 未判定
  int _dragStartPage = 0;

  /// 点 Tab 触发的翻页动画期间非空：此时 [onPageChanged] 不回写
  /// TabController，指示器由 TabController 自己的动画驱动，避免互相打断。
  int? _tapAnimTargetPage;

  @override
  void initState() {
    super.initState();
    widget.tabController?.addListener(_handleTabControllerTick);
  }

  @override
  void didUpdateWidget(covariant SwipePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabController != oldWidget.tabController) {
      oldWidget.tabController?.removeListener(_handleTabControllerTick);
      widget.tabController?.addListener(_handleTabControllerTick);
    }
  }

  @override
  void dispose() {
    widget.tabController?.removeListener(_handleTabControllerTick);
    _internalController?.dispose();
    super.dispose();
  }

  int get _pageCount => widget.children?.length ?? widget.itemCount!;

  /// Tab 点击 → 带动画翻页；程序化瞬时跳变（`tc.index = x` 或
  /// `animateTo(Duration.zero)`，indexIsChanging 为 false）→ 直接跳页。
  /// 手势滑动导致的 index 跳变也走瞬时路径，但此时页已在目标位，
  /// index 相等提前返回，不会成环。
  void _handleTabControllerTick() {
    final tabController = widget.tabController!;
    if (!mounted || !_pageController.hasClients) return;
    final currentPage = (_pageController.page ?? 0).round();
    if (tabController.index == currentPage) return;
    if (tabController.indexIsChanging) {
      if (_tapAnimTargetPage != null) return;
      _tapAnimTargetPage = tabController.index;
      unawaited(
        _pageController
            .animateToPage(
              tabController.index,
              duration: widget.animationDuration,
              curve: AppCurves.quick,
            )
            .whenComplete(() => _tapAnimTargetPage = null),
      );
    } else {
      _pageController.jumpToPage(tabController.index);
    }
  }

  void _handlePageChanged(int page) {
    final tabController = widget.tabController;
    // 手势滑动时 TabController.index 还停在旧值，这里瞬时同步（不产生
    // indexIsChanging 动画）；点 Tab 触发的翻页则交给 TabController 动画。
    if (tabController != null &&
        _tapAnimTargetPage == null &&
        tabController.index != page) {
      tabController.index = page;
    }
    widget.onPageChanged?.call(page);
  }

  void _handlePanStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _dragStartY = details.globalPosition.dy;
    _isHorizontalDrag = null;
    _dragStartPage = _pageController.hasClients
        ? (_pageController.page ?? 0).round()
        : 0;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_pageController.hasClients) return;
    if (_isHorizontalDrag == null) {
      final dx = (details.globalPosition.dx - _dragStartX).abs();
      final dy = (details.globalPosition.dy - _dragStartY).abs();
      if (dx > 8 || dy > 8) {
        _isHorizontalDrag = dx > dy * 1.5;
      }
    }
    if (_isHorizontalDrag == true) {
      final newOffset = (_pageController.offset - details.delta.dx).clamp(
        0.0,
        _pageController.position.maxScrollExtent,
      );
      _pageController.jumpTo(newOffset);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_isHorizontalDrag != true) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final dragDelta = details.globalPosition.dx - _dragStartX;
    final lastPage = _pageCount - 1;
    int targetPage;
    // 快甩：有明显横向速度即翻页
    if (velocity < -100) {
      targetPage = (_dragStartPage + 1).clamp(0, lastPage);
    } else if (velocity > 100) {
      targetPage = (_dragStartPage - 1).clamp(0, lastPage);
    } else if (dragDelta < -50) {
      // 慢拖：位移足够但没有明显速度
      targetPage = (_dragStartPage + 1).clamp(0, lastPage);
    } else if (dragDelta > 50) {
      targetPage = (_dragStartPage - 1).clamp(0, lastPage);
    } else {
      // 位移不足，弹回原页
      targetPage = _dragStartPage;
    }
    unawaited(
      _pageController.animateToPage(
        targetPage,
        duration: widget.animationDuration,
        curve: AppCurves.quick,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: PageView.builder(
        physics: const NeverScrollableScrollPhysics(),
        controller: _pageController,
        itemCount: _pageCount,
        onPageChanged: _handlePageChanged,
        itemBuilder: (context, index) {
          Widget page =
              widget.children?[index] ??
              widget.itemBuilder?.call(context, index) ??
              const SizedBox.shrink();
          if (widget.keepPagesAlive) {
            page = _KeepAliveWrapper(child: page);
          }
          return page;
        },
      ),
    );
  }
}

/// 包一层 wantKeepAlive 的子节点，翻页后 State 不会被 PageView 回收。
class _KeepAliveWrapper extends StatefulWidget {
  const _KeepAliveWrapper({required this.child});

  final Widget child;

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
