part of 'campus_notice_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  Attachment floating button, list sheet & download logic
// ═══════════════════════════════════════════════════════════════════════════════

class _AttachmentFab extends StatefulWidget {
  const _AttachmentFab({
    required this.attachments,
    required this.boundarySize,
  });

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
            final raw =
                _offsetAtDown + (event.position - _pointerStart);
            setState(() {
              _offset = _clampOffset(raw);
            });
          },
          onPointerUp: (event) {
            final distance =
                (event.position - _pointerStart).distance;
            setState(() => _pressed = false);
            if (distance < 5) {
              _showAttachmentSheet(
                  context, widget.attachments, l10n);
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
                    color:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                  Text(
                    '${widget.attachments.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.8,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.attach_file,
                    color: Theme.of(ctx).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '${l10n.attachments} (${attachments.length})',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: attachments.length,
              itemBuilder: (ctx, index) =>
                  _AttachmentTile(attachment: attachments[index]),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AttachmentTile extends StatefulWidget {
  const _AttachmentTile({required this.attachment});

  final _NoticeAttachment attachment;

  @override
  State<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<_AttachmentTile> {
  bool _downloading = false;
  String? _downloadedPath;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final dir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${dir.path}/Bugaoshan/notice_attachments');
    if (!saveDir.existsSync()) return;
    final filePath = '${saveDir.path}/${widget.attachment.fileName}';
    if (File(filePath).existsSync()) {
      if (!mounted) return;
      setState(() => _downloadedPath = filePath);
    }
  }

  IconData _fileIcon() {
    final name = widget.attachment.fileName.toLowerCase();
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (name.endsWith('.doc') || name.endsWith('.docx')) {
      return Icons.description;
    }
    if (name.endsWith('.xls') || name.endsWith('.xlsx')) {
      return Icons.table_chart;
    }
    if (name.endsWith('.ppt') || name.endsWith('.pptx')) {
      return Icons.slideshow;
    }
    if (name.endsWith('.zip') ||
        name.endsWith('.rar') ||
        name.endsWith('.7z')) {
      return Icons.folder_zip;
    }
    return Icons.insert_drive_file;
  }

  Future<void> _download() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _downloading = true);

    try {
      final response = await _NoticeHttp.get(widget.attachment.url);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final bytes = response.bodyBytes;
      final fileName = widget.attachment.fileName;

      // Save to app documents directory.
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/Bugaoshan/notice_attachments');
      if (!saveDir.existsSync()) {
        saveDir.createSync(recursive: true);
      }

      // Deduplicate file names.
      var filePath = '${saveDir.path}/$fileName';
      var file = File(filePath);
      if (file.existsSync()) {
        final baseName = p.basenameWithoutExtension(fileName);
        final ext = p.extension(fileName);
        var counter = 1;
        while (file.existsSync()) {
          filePath = '${saveDir.path}/$baseName ($counter)$ext';
          file = File(filePath);
          counter++;
        }
      }

      await file.writeAsBytes(bytes);

      if (!mounted) return;
      setState(() => _downloadedPath = filePath);
    } catch (e) {
      debugPrint('Attachment download error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.attachmentDownloadFailed),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _openFile() {
    if (_downloadedPath == null) return;
    OpenFilex.open(_downloadedPath!);
  }

  void _shareFile() {
    if (_downloadedPath == null) return;
    Share.shareXFiles([XFile(_downloadedPath!)]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: Icon(_fileIcon(),
          color: Theme.of(context).colorScheme.primary),
      title: Text(
        widget.attachment.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _downloading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _downloadedPath != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.share,
                          color: Theme.of(context).colorScheme.primary),
                      tooltip: l10n.share,
                      onPressed: _shareFile,
                    ),
                    IconButton(
                      icon: Icon(Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary),
                      tooltip: l10n.open,
                      onPressed: _openFile,
                    ),
                  ],
                )
              : IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: l10n.download,
                  onPressed: _download,
                ),
    );
  }
}
