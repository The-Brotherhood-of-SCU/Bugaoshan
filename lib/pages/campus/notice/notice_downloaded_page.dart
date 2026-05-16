part of 'campus_notice_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  Downloaded Attachments Management Page
// ═══════════════════════════════════════════════════════════════════════════════

enum _SortMode { time, name, size }

class _DownloadedAttachmentsPage extends StatefulWidget {
  const _DownloadedAttachmentsPage();

  @override
  State<_DownloadedAttachmentsPage> createState() =>
      _DownloadedAttachmentsPageState();
}

class _DownloadedAttachmentsPageState
    extends State<_DownloadedAttachmentsPage> {
  List<File> _files = [];
  bool _loading = true;
  bool _selecting = false;
  final Set<String> _selected = {};
  _SortMode _sortMode = _SortMode.time;
  bool _searching = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Directory> _attachmentsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory('${dir.path}/Bugaoshan/notice_attachments');
  }

  Future<void> _loadFiles() async {
    final dir = await _attachmentsDir();
    if (!dir.existsSync()) {
      if (!mounted) return;
      setState(() {
        _files = [];
        _loading = false;
      });
      return;
    }
    final files = dir.listSync().whereType<File>().toList();
    _sortFiles(files);
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  void _sortFiles(List<File> files) {
    switch (_sortMode) {
      case _SortMode.time:
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      case _SortMode.name:
        files.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
      case _SortMode.size:
        files.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
    }
  }

  void _changeSort(_SortMode mode) {
    setState(() {
      _sortMode = mode;
      _sortFiles(_files);
    });
  }

  List<File> get _filteredFiles {
    if (_query.isEmpty) return _files;
    final q = _query.toLowerCase();
    return _files.where((f) => p.basename(f.path).toLowerCase().contains(q)).toList();
  }

  void _enterSelection(File file) {
    setState(() {
      _selecting = true;
      _selected.clear();
      _selected.add(file.path);
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleSelect(File file) {
    setState(() {
      if (_selected.contains(file.path)) {
        _selected.remove(file.path);
        if (_selected.isEmpty) _selecting = false;
      } else {
        _selected.add(file.path);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selected.addAll(_filteredFiles.map((f) => f.path));
    });
  }

  Future<void> _deleteSelected() async {
    final l10n = AppLocalizations.of(context)!;
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.confirmDeleteSelected(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final path in _selected) {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.fileDeleted),
        duration: const Duration(seconds: 2),
      ),
    );
    _exitSelection();
    _loadFiles();
  }

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description;
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return Icons.table_chart;
    }
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
      return Icons.slideshow;
    }
    if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z')) {
      return Icons.folder_zip;
    }
    return Icons.insert_drive_file;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openFile(File file) async {
    final uri = Uri.file(file.path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareFile(File file) {
    Share.shareXFiles([XFile(file.path)]);
  }

  void _shareSelected() {
    final files = _selected.map((p) => XFile(p)).toList();
    Share.shareXFiles(files);
  }

  PopupMenuItem<_SortMode> _sortItem(_SortMode mode, String label, IconData icon) {
    return PopupMenuItem(
      value: mode,
      child: ListTile(
        leading: Icon(icon,
            color: _sortMode == mode
                ? Theme.of(context).colorScheme.primary
                : null),
        title: Text(label,
            style: TextStyle(
                fontWeight: _sortMode == mode ? FontWeight.bold : null)),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayFiles = _filteredFiles;

    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelection,
              ),
              title: Text('${_selected.length}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: l10n.selectAll,
                  onPressed: _selectAll,
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: l10n.share,
                  onPressed: _selected.isEmpty ? null : _shareSelected,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.deleteSelected(_selected.length),
                  onPressed: _selected.isEmpty ? null : _deleteSelected,
                ),
              ],
            )
          : AppBar(
              title: _searching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: l10n.searchAttachmentsHint,
                        border: InputBorder.none,
                      ),
                    )
                  : Text(l10n.downloadedAttachments),
              actions: [
                IconButton(
                  icon: Icon(_searching ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      if (_searching) {
                        _searching = false;
                        _query = '';
                        _searchController.clear();
                      } else {
                        _searching = true;
                      }
                    });
                  },
                ),
                PopupMenuButton<_SortMode>(
                  icon: const Icon(Icons.sort),
                  onSelected: _changeSort,
                  itemBuilder: (ctx) => [
                    _sortItem(_SortMode.time, l10n.sortByTime, Icons.access_time),
                    _sortItem(_SortMode.name, l10n.sortByName, Icons.sort_by_alpha),
                    _sortItem(_SortMode.size, l10n.sortBySize, Icons.data_usage),
                  ],
                ),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : displayFiles.isEmpty
              ? Center(
                  child: Text(
                    _query.isNotEmpty ? l10n.noData : l10n.noDownloadedAttachments,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: displayFiles.length,
                  itemBuilder: (ctx, index) {
                    final file = displayFiles[index];
                    final name = p.basename(file.path);
                    final size = file.lengthSync();
                    final modified = file.lastModifiedSync();
                    final isSelected = _selected.contains(file.path);

                    return ListTile(
                      leading: _selecting
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleSelect(file),
                            )
                          : Icon(
                              _fileIcon(name),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      title: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_formatSize(size)}  ·  ${_formatDate(modified)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: _selecting
                          ? null
                          : PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'open') {
                                  _openFile(file);
                                } else if (value == 'share') {
                                  _shareFile(file);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'open',
                                  child: ListTile(
                                    leading: const Icon(Icons.open_in_new),
                                    title: Text(l10n.open),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'share',
                                  child: ListTile(
                                    leading: const Icon(Icons.share),
                                    title: Text(l10n.share),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                      onTap: _selecting
                          ? () => _toggleSelect(file)
                          : () => _openFile(file),
                      onLongPress: _selecting
                          ? null
                          : () => _enterSelection(file),
                    );
                  },
                ),
    );
  }
}
