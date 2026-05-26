part of 'course_page.dart';

/// A PageView wrapper that only triggers page switching when the horizontal
/// displacement is significantly larger than vertical, so vertical scrolling
/// inside the page is not accidentally intercepted.
class _SwipePageView extends StatefulWidget {
  final PageController controller;
  final int itemCount;
  final void Function(int index) onPageChanged;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const _SwipePageView({
    required this.controller,
    required this.itemCount,
    required this.onPageChanged,
    required this.itemBuilder,
  });

  @override
  State<_SwipePageView> createState() => _SwipePageViewState();
}

class _SwipePageViewState extends State<_SwipePageView> {
  double _dragStartX = 0;
  double _dragStartY = 0;
  bool? _isHorizontalDrag; // null = undecided
  int _dragStartPage = 0;

  void _onPanStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _dragStartY = details.globalPosition.dy;
    _isHorizontalDrag = null;
    _dragStartPage = (widget.controller.page ?? 0).round();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isHorizontalDrag == null) {
      final dx = (details.globalPosition.dx - _dragStartX).abs();
      final dy = (details.globalPosition.dy - _dragStartY).abs();
      if (dx > 8 || dy > 8) {
        _isHorizontalDrag = dx > dy * 1.5;
      }
    }
    if (_isHorizontalDrag == true) {
      final newOffset = (widget.controller.offset - details.delta.dx).clamp(
        0.0,
        widget.controller.position.maxScrollExtent,
      );
      widget.controller.jumpTo(newOffset);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isHorizontalDrag != true) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final dragDelta = details.globalPosition.dx - _dragStartX;
    int targetPage;
    // Flick gesture: any noticeable velocity flips the page
    if (velocity < -100) {
      targetPage = (_dragStartPage + 1).clamp(0, widget.itemCount - 1);
    } else if (velocity > 100) {
      targetPage = (_dragStartPage - 1).clamp(0, widget.itemCount - 1);
    } else if (dragDelta < -50) {
      // Dragged left far enough without much velocity
      targetPage = (_dragStartPage + 1).clamp(0, widget.itemCount - 1);
    } else if (dragDelta > 50) {
      // Dragged right far enough without much velocity
      targetPage = (_dragStartPage - 1).clamp(0, widget.itemCount - 1);
    } else {
      // Small drag, snap back
      targetPage = _dragStartPage;
    }
    widget.controller.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: PageView.builder(
        physics: const NeverScrollableScrollPhysics(),
        controller: widget.controller,
        itemCount: widget.itemCount,
        onPageChanged: widget.onPageChanged,
        itemBuilder: widget.itemBuilder,
      ),
    );
  }
}
