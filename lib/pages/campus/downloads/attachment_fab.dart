import 'package:flutter/material.dart';

import 'attachments_sheet.dart';

/// A draggable floating action button that shows attachment count and opens
/// the shared attachments sheet on tap. Shared by JWC notice and party/XGB
/// notice pages.
class NoticeAttachmentFab extends StatefulWidget {
  const NoticeAttachmentFab({
    super.key,
    required this.items,
    required this.dirName,
    required this.boundarySize,
    this.downloadHeaders,
    this.heroTag,
    this.onWebViewDownload,
  });

  final List<AttachItem> items;
  final String dirName;
  final Map<String, String>? downloadHeaders;
  final Size boundarySize;
  final String? heroTag;
  final void Function(String url)? onWebViewDownload;

  @override
  State<NoticeAttachmentFab> createState() => _NoticeAttachmentFabState();
}

class _NoticeAttachmentFabState extends State<NoticeAttachmentFab> {
  static const _fabSize = 56.0;
  static const _margin = 16.0;
  static const _bottomMargin = 32.0;

  late Offset _offset;
  bool _initialized = false;
  Offset _pointerStart = Offset.zero;
  Offset _offsetAtDown = Offset.zero;
  bool _pressed = false;

  Offset _clampOffset(Offset offset) {
    final boundary = widget.boundarySize;
    if (boundary == Size.zero) return offset;
    final maxX = boundary.width - _fabSize - _margin;
    final maxY = boundary.height - _fabSize - _bottomMargin;
    return Offset(
      offset.dx.clamp(_margin, maxX),
      offset.dy.clamp(_margin, maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      _initialized = true;
      _offset = Offset(
        widget.boundarySize.width - _fabSize - _margin,
        widget.boundarySize.height - _fabSize - _bottomMargin,
      );
    }

    final fab = MouseRegion(
      cursor: SystemMouseCursors.move,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          setState(() => _pressed = true);
          _pointerStart = event.position;
          _offsetAtDown = _offset;
        },
        onPointerMove: (event) {
          final raw = _offsetAtDown + (event.position - _pointerStart);
          setState(() => _offset = _clampOffset(raw));
        },
        onPointerUp: (event) {
          final distance = (event.position - _pointerStart).distance;
          setState(() => _pressed = false);
          if (distance < 5) {
            showAttachmentsSheet(
              context,
              items: widget.items,
              dirName: widget.dirName,
              downloadHeaders: widget.downloadHeaders,
              onWebViewDownload: widget.onWebViewDownload,
            );
          }
        },
        onPointerCancel: (_) {
          setState(() => _pressed = false);
        },
        child: Material(
          elevation: _pressed ? 10 : 6,
          shape: const CircleBorder(),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: SizedBox(
            width: _fabSize,
            height: _fabSize,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.attach_file,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 22,
                ),
                Text(
                  '${widget.items.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: widget.heroTag != null
          ? Hero(tag: widget.heroTag!, child: fab)
          : fab,
    );
  }
}
