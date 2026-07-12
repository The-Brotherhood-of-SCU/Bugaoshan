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
  });

  final Listenable authListenable;
  final bool Function() isAuthenticated;
  final List<String> visibleIds;
  final int selectedIndex;
  final Widget Function(String id) pageBuilder;

  @override
  State<AuthScopedIndexedStack> createState() => _AuthScopedIndexedStackState();
}

class _AuthScopedIndexedStackState extends State<AuthScopedIndexedStack> {
  final Map<String, Widget> _pageCache = {};
  late bool _wasAuthenticated;
  int _authGeneration = 0;

  @override
  void initState() {
    super.initState();
    _wasAuthenticated = widget.isAuthenticated();
    widget.authListenable.addListener(_handleAuthChanged);
  }

  @override
  void didUpdateWidget(covariant AuthScopedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authListenable != widget.authListenable) {
      oldWidget.authListenable.removeListener(_handleAuthChanged);
      widget.authListenable.addListener(_handleAuthChanged);
    }
    _resetForAuthenticationBoundary();
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
    return IndexedStack(
      index: selectedIndex,
      children: visibleIds.map((id) => _pageCache[id]!).toList(),
    );
  }
}
