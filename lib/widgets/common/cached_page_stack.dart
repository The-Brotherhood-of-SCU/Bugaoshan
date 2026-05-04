import 'package:flutter/material.dart';

/// A widget that lazily builds and caches page widgets by [currentId].
/// Pages stay alive via [Offstage] once built, preserving their state.
class CachedPageStack extends StatefulWidget {
  final String currentId;
  final Widget Function(String id) pageBuilder;

  const CachedPageStack({
    super.key,
    required this.currentId,
    required this.pageBuilder,
  });

  @override
  State<CachedPageStack> createState() => _CachedPageStackState();
}

class _CachedPageStackState extends State<CachedPageStack> {
  final Map<String, Widget> _cache = {};

  @override
  Widget build(BuildContext context) {
    _cache.putIfAbsent(
      widget.currentId,
      () => widget.pageBuilder(widget.currentId),
    );

    return Stack(
      children: [
        for (final entry in _cache.entries)
          Offstage(
            offstage: entry.key != widget.currentId,
            child: entry.value,
          ),
      ],
    );
  }
}
