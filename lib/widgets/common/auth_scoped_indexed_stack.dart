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
  });

  final Listenable authListenable;
  final bool Function() isAuthenticated;
  final List<String> visibleIds;
  final int selectedIndex;
  final Widget Function(String id) pageBuilder;
  final Duration duration;
  final bool enableAnimation;

  @override
  State<AuthScopedIndexedStack> createState() => _AuthScopedIndexedStackState();
}

class _AuthScopedIndexedStackState extends State<AuthScopedIndexedStack>
    with SingleTickerProviderStateMixin {
  final Map<String, Widget> _pageCache = {};
  late bool _wasAuthenticated;
  int _authGeneration = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
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
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _updateSlideAnim();
  }

  void _updateSlideAnim() {
    final beginOffset = _isMovingRight ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
    _slideAnim = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.fastOutSlowIn,
      ),
    );
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

    if (oldWidget.selectedIndex != widget.selectedIndex && widget.enableAnimation) {
      _isMovingRight = widget.selectedIndex > oldWidget.selectedIndex;
      _updateSlideAnim();
      _animController.forward(from: 0.0);
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
    _pageCache.clear();
    return true;
  }

  @override
  void dispose() {
    widget.authListenable.removeListener(_handleAuthChanged);
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

    return IndexedStack(
      index: selectedIndex,
      children: visibleIds.map((id) {
        final child = _pageCache[id]!;
        if (id == selectedId && widget.enableAnimation) {
          return SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: child,
            ),
          );
        }
        return child;
      }).toList(),
    );
  }
}
