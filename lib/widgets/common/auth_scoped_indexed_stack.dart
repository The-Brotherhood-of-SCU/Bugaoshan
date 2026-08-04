import 'package:flutter/material.dart';

/// 按认证会话隔离页面状态的懒加载 [IndexedStack]。
///
/// 登录状态跨越边界时会销毁全部缓存页面。即使新旧页面的 Widget 类型和位置
/// 相同，代际 key 也会强制 Flutter 丢弃旧 State，避免前一账号的本地字段或
/// 未完成请求在新账号会话中继续生效。
class AuthScopedIndexedStack extends StatefulWidget {
  const AuthScopedIndexedStack({
    super.key,
    required this.authListenable,
    required this.isAuthenticated,
    required this.visibleIds,
    required this.selectedIndex,
    required this.pageBuilder,
    this.duration = const Duration(milliseconds: 300),
    this.enableAnimation = true,
    this.axis = Axis.horizontal,
  });

  final Listenable authListenable;
  final bool Function() isAuthenticated;
  final List<String> visibleIds;
  final int selectedIndex;
  final Widget Function(String id) pageBuilder;
  final Duration duration;
  final bool enableAnimation;
  final Axis axis;

  @override
  State<AuthScopedIndexedStack> createState() => _AuthScopedIndexedStackState();
}

class _AuthScopedIndexedStackState extends State<AuthScopedIndexedStack>
    with SingleTickerProviderStateMixin {
  final Map<String, Widget> _pageCache = {};
  late bool _wasAuthenticated;
  int _authGeneration = 0;

  int? _previousIndex;
  late AnimationController _animController;
  late CurvedAnimation _animationCurve;
  late Animation<double> _fadeAnimIn;
  late Animation<double> _fadeAnimOut;
  late Animation<Offset> _slideAnimIn;
  late Animation<Offset> _slideAnimOut;
  bool _isMovingRight = true;

  @override
  void initState() {
    super.initState();
    _wasAuthenticated = widget.isAuthenticated();
    widget.authListenable.addListener(_handleAuthChanged);

    _animController = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted && _previousIndex != null) {
          setState(() {
            _previousIndex = null;
          });
        }
      }
    });

    _animationCurve = CurvedAnimation(
      parent: _animController,
      curve: Curves.fastOutSlowIn,
    );

    _fadeAnimIn = Tween<double>(begin: 0.0, end: 1.0).animate(_animationCurve);
    _fadeAnimOut = Tween<double>(begin: 1.0, end: 0.0).animate(_animationCurve);
    _updateAnimations();
  }

  void _updateAnimations() {
    final Offset beginIn;
    final Offset endOut;

    if (widget.axis == Axis.vertical) {
      beginIn = _isMovingRight
          ? const Offset(0.0, 1.0)
          : const Offset(0.0, -1.0);
      endOut = _isMovingRight
          ? const Offset(0.0, -1.0)
          : const Offset(0.0, 1.0);
    } else {
      beginIn = _isMovingRight
          ? const Offset(1.0, 0.0)
          : const Offset(-1.0, 0.0);
      endOut = _isMovingRight
          ? const Offset(-1.0, 0.0)
          : const Offset(1.0, 0.0);
    }

    _slideAnimIn = Tween<Offset>(
      begin: beginIn,
      end: Offset.zero,
    ).animate(_animationCurve);

    _slideAnimOut = Tween<Offset>(
      begin: Offset.zero,
      end: endOut,
    ).animate(_animationCurve);
  }

  @override
  void didUpdateWidget(covariant AuthScopedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _animController.duration = widget.duration;
    }
    if (oldWidget.authListenable != widget.authListenable) {
      oldWidget.authListenable.removeListener(_handleAuthChanged);
      widget.authListenable.addListener(_handleAuthChanged);
    }
    _resetForAuthenticationBoundary();

    final bool axisChanged = oldWidget.axis != widget.axis;
    final bool indexChanged = oldWidget.selectedIndex != widget.selectedIndex;

    if (indexChanged || axisChanged) {
      if (indexChanged &&
          widget.enableAnimation &&
          widget.duration > Duration.zero) {
        _previousIndex = oldWidget.selectedIndex;
        _isMovingRight = widget.selectedIndex > oldWidget.selectedIndex;
        _updateAnimations();
        _animController.forward(from: 0.0);
      } else {
        if (indexChanged) {
          _previousIndex = null;
          _animController.value = 1.0;
        }
        _updateAnimations();
      }
    }
  }

  void _handleAuthChanged() {
    if (!mounted || !_resetForAuthenticationBoundary()) return;
    setState(() {});
  }

  bool _resetForAuthenticationBoundary() {
    final authenticated = widget.isAuthenticated();
    if (authenticated == _wasAuthenticated) return false;

    _wasAuthenticated = authenticated;
    _authGeneration++;
    _previousIndex = null;
    _pageCache.clear();
    return true;
  }

  @override
  void dispose() {
    widget.authListenable.removeListener(_handleAuthChanged);
    _animationCurve.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleIds = widget.visibleIds;
    if (visibleIds.isEmpty) return const SizedBox.shrink();

    for (final id in visibleIds) {
      _pageCache.putIfAbsent(
        id,
        () => KeyedSubtree(
          key: ValueKey('auth-$_authGeneration-$id'),
          child: widget.pageBuilder(id),
        ),
      );
    }
    _pageCache.keys
        .where((id) => !visibleIds.contains(id))
        .toList()
        .forEach(_pageCache.remove);

    final selectedIndex = widget.selectedIndex.clamp(0, visibleIds.length - 1);
    final selectedId = visibleIds[selectedIndex];

    final prevIndex = _previousIndex?.clamp(0, visibleIds.length - 1);
    final prevId = (prevIndex != null && prevIndex != selectedIndex)
        ? visibleIds[prevIndex]
        : null;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: visibleIds.map((id) {
          final child = _pageCache[id]!;
          final isSelected = (id == selectedId);
          final isPrevious = (id == prevId);

          final slideAnim = isPrevious ? _slideAnimOut : _slideAnimIn;
          final fadeAnim = isPrevious ? _fadeAnimOut : _fadeAnimIn;

          return Offstage(
            offstage: !isSelected && !isPrevious,
            child: SlideTransition(
              position: slideAnim,
              child: FadeTransition(opacity: fadeAnim, child: child),
            ),
          );
        }).toList(),
      ),
    );
  }
}
