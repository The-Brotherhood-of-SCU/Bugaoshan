part of 'campus_notice_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  Attachment floating button, list sheet & download logic
// ═══════════════════════════════════════════════════════════════════════════════

class _AttachmentFab extends StatefulWidget {
  const _AttachmentFab({required this.attachments, required this.boundarySize});

  final List<_NoticeAttachment> attachments;
  final Size boundarySize;

  @override
  State<_AttachmentFab> createState() => _AttachmentFabState();
}

class _AttachmentFabState extends State<_AttachmentFab> {
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
    final l10n = AppLocalizations.of(context)!;

    if (!_initialized) {
      _initialized = true;
      _offset = Offset(
        widget.boundarySize.width - _fabSize - _margin,
        widget.boundarySize.height - _fabSize - _bottomMargin,
      );
    }

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: MouseRegion(
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
            setState(() {
              _offset = _clampOffset(raw);
            });
          },
          onPointerUp: (event) {
            final distance = (event.position - _pointerStart).distance;
            setState(() => _pressed = false);
            if (distance < 5) {
              _showAttachmentSheet(context, widget.attachments, l10n);
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
                    '${widget.attachments.length}',
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
      ),
    );
  }
}

void _showAttachmentSheet(
  BuildContext context,
  List<_NoticeAttachment> attachments,
  AppLocalizations l10n,
) {
  showAttachmentsSheet(
    context,
    items: attachments.map((a) => AttachItem(url: a.url, name: a.text)).toList(),
    dirName: kNoticeAttachmentDir,
    downloadHeaders: _NoticeHttp._buildHeaders(),
  );
}
