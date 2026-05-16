import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'file_utils.dart';

class _DirConfig {
  const _DirConfig(this.dirName, this.label);
  final String dirName;
  final String label;
}

class _SearchEntry {
  const _SearchEntry(this.file, this.category);
  final File file;
  final String category;
}

enum _SortMode { time, name, size }

// ── Downloaded Attachments Management Page ──────────────────────────────────────────

class NoticeDownloadedPage extends StatefulWidget {
  const NoticeDownloadedPage({super.key, this.initialTab = 0});

  /// Index of the initially visible tab (0 = 教务处通知, 1 = 党委学工部通知).
  final int initialTab;

  @override
  State<NoticeDownloadedPage> createState() => _NoticeDownloadedPageState();
}

class _NoticeDownloadedPageState extends State<NoticeDownloadedPage>
    with TickerProviderStateMixin {
  final _dirConfigs = [
    _DirConfig(kNoticeAttachmentDir, '教务处通知'),
    _DirConfig(kPartyAttachmentDir, '党委学工部通知'),
    _DirConfig(kTuanweiAttachmentDir, '青春川大通知'),
  ];

  late final TabController _tabController;

  final Map<String, List<File>> _filesByDir = {};
  final Map<String, bool> _loadedByDir = {};

  bool _loading = true;
  bool _selecting = false;
  final Set<String> _selected = {};
  _SortMode _sortMode = _SortMode.time;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  String get _currentDir => _dirConfigs[_tabController.index].dirName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _dirConfigs.length,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, _dirConfigs.length - 1),
    );
    _tabController.addListener(_onTabChanged);
    _loadFiles();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  String _dirPath(String dirName) {
    return 'Bugaoshan/$dirName';
  }

  Future<Directory> _attachmentsDir(String dirName) async {
    final base = await getNoticeBaseDir();
    return Directory('${base.path}/${_dirPath(dirName)}');
  }

  Future<void> _openFolder() async {
    final l10n = AppLocalizations.of(context)!;
    final dir = await _attachmentsDir(_currentDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    try {
      if (Platform.isAndroid) {
        final encodedPath = _dirPath(_currentDir).replaceAll('/', '%2F');
        await launchUrl(
          Uri.parse(
            'content://com.android.externalstorage.documents/document/primary%3AAndroid%2Fdata%2Fio.github.the_brotherhood_of_scu.bugaoshan%2Ffiles%2F$encodedPath',
          ),
        );
      } else {
        await launchUrl(Uri.file(dir.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.openFolderFailed}: $e')));
    }
  }

  Future<void> _loadFiles() async {
    final futures = _dirConfigs.map((cfg) => _loadDir(cfg.dirName));
    await Future.wait(futures);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadDir(String dirName) async {
    final dir = await _attachmentsDir(dirName);
    List<File> files;
    if (!dir.existsSync()) {
      files = [];
    } else {
      files = dir.listSync().whereType<File>().toList();
      _sortFiles(files);
    }
    if (!mounted) return;
    setState(() {
      _filesByDir[dirName] = files;
      _loadedByDir[dirName] = true;
    });
  }

  void _sortFiles(List<File> files) {
    switch (_sortMode) {
      case _SortMode.time:
        files.sort(
          (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
        );
      case _SortMode.name:
        files.sort(
          (a, b) => p
              .basename(a.path)
              .toLowerCase()
              .compareTo(p.basename(b.path).toLowerCase()),
        );
      case _SortMode.size:
        files.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
    }
  }

  void _changeSort(_SortMode mode) {
    setState(() {
      _sortMode = mode;
      for (final cfg in _dirConfigs) {
        final files = _filesByDir[cfg.dirName];
        if (files != null) _sortFiles(files);
      }
    });
  }

  List<File> get _currentFiles {
    final all = _filesByDir[_currentDir] ?? [];
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((f) => p.basename(f.path).toLowerCase().contains(q))
        .toList();
  }

  Map<String, List<File>> get _allFilteredFiles {
    if (_query.isEmpty) {
      return Map.fromEntries(
        _dirConfigs.map(
          (cfg) => MapEntry(cfg.dirName, _filesByDir[cfg.dirName] ?? []),
        ),
      );
    }
    final q = _query.toLowerCase();
    final result = <String, List<File>>{};
    for (final cfg in _dirConfigs) {
      final all = _filesByDir[cfg.dirName] ?? [];
      result[cfg.dirName] = all
          .where((f) => p.basename(f.path).toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  int get _totalMatches {
    var count = 0;
    for (final files in _allFilteredFiles.values) {
      count += files.length;
    }
    return count;
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
      _selected.addAll(_currentFiles.map((f) => f.path));
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
    for (final cfg in _dirConfigs) {
      final dir = await _attachmentsDir(cfg.dirName);
      if (dir.existsSync()) {
        for (final sub in dir.listSync().whereType<Directory>()) {
          if (sub.listSync().isEmpty) sub.deleteSync();
        }
      }
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

  // ── UI helpers ────────────────────────────────────────────────────────────────────

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Icons.description;
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return Icons.table_chart;
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return Icons.slideshow;
    if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _openFile(File file) => OpenFilex.open(file.path);

  void _shareFile(File file) => Share.shareXFiles([XFile(file.path)]);

  void _shareSelected() {
    final files = _selected.map((p) => XFile(p)).toList();
    Share.shareXFiles(files);
  }

  PopupMenuItem<_SortMode> _sortItem(_SortMode mode, String label, IconData icon) {
    return PopupMenuItem(
      value: mode,
      child: ListTile(
        leading: Icon(
          icon,
          color: _sortMode == mode ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: _sortMode == mode ? FontWeight.bold : null,
          ),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _fileListView(List<File> files) {
    final l10n = AppLocalizations.of(context)!;
    if (files.isEmpty) {
      return Center(
        child: Text(
          _query.isNotEmpty ? l10n.noData : l10n.noDownloadedAttachments,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: files.length,
      itemBuilder: (ctx, index) {
        final file = files[index];
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
          title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${_formatSize(size)}  ·  ${formatDate(modified)}',
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
          onTap: _selecting ? () => _toggleSelect(file) : () => _openFile(file),
          onLongPress: _selecting ? null : () => _enterSelection(file),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
              title: Text(l10n.downloadedAttachments),
              actions: [
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: l10n.openFolder,
                  onPressed: _openFolder,
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBar(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              hintText: l10n.searchAttachmentsHint,
              leading: const Icon(Icons.search),
            ),
          ),
          if (_query.isNotEmpty)
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _totalMatches == 0
                  ? Center(
                      child: Text(
                        l10n.noData,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _totalMatches,
                      itemBuilder: (ctx, index) {
                        final entries = <_SearchEntry>[];
                        for (final cfg in _dirConfigs) {
                          for (final f in _allFilteredFiles[cfg.dirName] ?? []) {
                            entries.add(_SearchEntry(f, cfg.label));
                          }
                        }
                        final entry = entries[index];
                        final file = entry.file;
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
                          title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${entry.category}  ·  ${_formatSize(size)}  ·  ${formatDate(modified)}',
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
                          onTap: _selecting ? () => _toggleSelect(file) : () => _openFile(file),
                          onLongPress: _selecting ? null : () => _enterSelection(file),
                        );
                      },
                    ),
            )
          else
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          tabs: [
                            for (final cfg in _dirConfigs)
                              Tab(
                                text:
                                    '${cfg.label} (${(_filesByDir[cfg.dirName] ?? []).length})',
                              ),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              for (final cfg in _dirConfigs)
                                _fileListView(_filesByDir[cfg.dirName] ?? []),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
