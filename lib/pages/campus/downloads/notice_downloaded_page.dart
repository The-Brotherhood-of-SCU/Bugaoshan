import 'dart:io';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/download_manager.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/utils/share_utils.dart';
import 'file_utils.dart';

class _DirConfig {
  const _DirConfig(this.dirName, this.label);
  final String dirName;
  final String label;
}

/// Lightweight data object holding a [File] and its pre-computed metadata.
///
/// File size and modification time are computed once during directory listing
/// so that [ListView.itemBuilder] never calls synchronous I/O on the UI thread.
class _FileInfo {
  const _FileInfo(this.file, this.size, this.modified);
  final File file;
  final int size;
  final DateTime modified;
}

class _SearchEntry {
  const _SearchEntry(this.info, this.category);
  final _FileInfo info;
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
  late final List<_DirConfig> _dirConfigs;

  late final TabController _tabController;
  bool _initialized = false;

  /// Pre-computed file metadata keyed by directory name.
  /// File sizes and modification times are computed once in [_loadDir] and
  /// reused in [ListView.itemBuilder] to avoid synchronous I/O on the UI thread.
  final Map<String, List<_FileInfo>> _filesByDir = {};
  final Map<String, bool> _loadedByDir = {};

  bool _loading = true;
  bool _selecting = false;
  final Set<String> _selected = {};
  _SortMode _sortMode = _SortMode.time;
  String _query = '';
  String _filterExt = '';
  final TextEditingController _searchController = TextEditingController();

  String get _currentDir => _dirConfigs[_tabController.index].dirName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _tabController.addListener(_onTabChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final l10n = AppLocalizations.of(context)!;
    _dirConfigs = [
      _DirConfig(kNoticeAttachmentDir, l10n.jwcTabLabel),
      _DirConfig(kPartyAttachmentDir, l10n.xgbTabLabel),
      _DirConfig(kTuanweiAttachmentDir, l10n.tuanweiTabLabel),
    ];
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
    if (!await dir.exists()) {
      await dir.create(recursive: true);
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

  /// Lists files in [dirName] asynchronously and pre-computes metadata (size,
  /// modification time) for each file so that the UI never calls synchronous
  /// I/O in [ListView.itemBuilder].
  Future<void> _loadDir(String dirName) async {
    final dir = await _attachmentsDir(dirName);
    List<_FileInfo> infos;
    if (!await dir.exists()) {
      infos = [];
    } else {
      final entries = await dir.list().toList();
      infos = [
        for (final entry in entries)
          if (entry is File)
            _FileInfo(entry, await entry.length(), await entry.lastModified()),
      ];
      _sortInfos(infos);
    }
    if (!mounted) return;
    setState(() {
      _filesByDir[dirName] = infos;
      _loadedByDir[dirName] = true;
    });
  }

  /// Sorts pre-computed [_FileInfo] objects by the active [_sortMode].
  ///
  /// All metadata (size, modification time) has already been computed during
  /// [_loadDir]; no synchronous I/O is performed during sorting.
  void _sortInfos(List<_FileInfo> infos) {
    switch (_sortMode) {
      case _SortMode.time:
        infos.sort((a, b) => b.modified.compareTo(a.modified));
      case _SortMode.name:
        infos.sort(
          (a, b) => p
              .basename(a.file.path)
              .toLowerCase()
              .compareTo(p.basename(b.file.path).toLowerCase()),
        );
      case _SortMode.size:
        infos.sort((a, b) => b.size.compareTo(a.size));
    }
  }

  void _changeSort(_SortMode mode) {
    setState(() {
      _sortMode = mode;
      for (final cfg in _dirConfigs) {
        final infos = _filesByDir[cfg.dirName];
        if (infos != null) _sortInfos(infos);
      }
    });
  }

  bool _fileMatchesFilter(_FileInfo info) {
    if (_filterExt.isNotEmpty &&
        !p.extension(info.file.path).toLowerCase().endsWith(_filterExt)) {
      return false;
    }
    if (_query.isNotEmpty &&
        !p
            .basename(info.file.path)
            .toLowerCase()
            .contains(_query.toLowerCase())) {
      return false;
    }
    return true;
  }

  List<_FileInfo> get _currentInfos {
    final all = _filesByDir[_currentDir] ?? [];
    return all.where(_fileMatchesFilter).toList();
  }

  Map<String, List<_FileInfo>> get _allFilteredInfos {
    final result = <String, List<_FileInfo>>{};
    for (final cfg in _dirConfigs) {
      final all = _filesByDir[cfg.dirName] ?? [];
      result[cfg.dirName] = all.where(_fileMatchesFilter).toList();
    }
    return result;
  }

  int get _totalMatches {
    var count = 0;
    for (final infos in _allFilteredInfos.values) {
      count += infos.length;
    }
    return count;
  }

  void _enterSelection(_FileInfo info) {
    setState(() {
      _selecting = true;
      _selected.clear();
      _selected.add(info.file.path);
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleSelect(_FileInfo info) {
    setState(() {
      if (_selected.contains(info.file.path)) {
        _selected.remove(info.file.path);
        if (_selected.isEmpty) _selecting = false;
      } else {
        _selected.add(info.file.path);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selected.addAll(_currentInfos.map((info) => info.file.path));
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
    final manager = getIt<DownloadManager>();
    for (final path in _selected) {
      final file = File(path);
      if (await file.exists()) await file.delete();
      // Remove stale task from DownloadManager so the attachment sheet
      // won't show a deleted file as "already downloaded".
      final fileName = p.basename(path);
      for (final cfg in _dirConfigs) {
        if (path.contains('/${cfg.dirName}/') ||
            path.contains('\\${cfg.dirName}\\')) {
          manager.remove(cfg.dirName, fileName);
          break;
        }
      }
    }
    for (final cfg in _dirConfigs) {
      final dir = await _attachmentsDir(cfg.dirName);
      if (await dir.exists()) {
        final entries = await dir.list().toList();
        for (final sub in entries.whereType<Directory>()) {
          if (await sub.list().toList().then((l) => l.isEmpty)) {
            await sub.delete();
          }
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
    if (lower.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description;
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return Icons.table_chart;
    }
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
      return Icons.slideshow;
    }
    if (lower.endsWith('.zip') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.7z')) {
      return Icons.folder_zip;
    }
    return Icons.insert_drive_file;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _openFile(File file) => OpenFilex.open(file.path);

  void _shareFile(File file) => shareSingleFile(file.path);

  void _shareSelected() => shareMultipleFiles(_selected.toList());

  void _showFilterMenu() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '排序方式',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setSheetState(() {
                        _changeSort(_SortMode.time);
                        _filterExt = '';
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('重置'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final mode in _SortMode.values)
                    ChoiceChip(
                      label: Text(_sortModeLabel(mode, l10n)),
                      selected: _sortMode == mode,
                      onSelected: (_) {
                        _changeSort(mode);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '文件类型',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: _filterExt.isEmpty,
                    onSelected: (_) {
                      setState(() => _filterExt = '');
                      Navigator.pop(context);
                    },
                  ),
                  for (final ext in ['.pdf', '.doc', '.xls', '.ppt', '.zip'])
                    ChoiceChip(
                      label: Text(ext.toUpperCase()),
                      selected: _filterExt == ext,
                      onSelected: (_) {
                        setState(() => _filterExt = ext);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sortModeLabel(_SortMode mode, AppLocalizations l10n) {
    switch (mode) {
      case _SortMode.time:
        return l10n.sortByTime;
      case _SortMode.name:
        return l10n.sortByName;
      case _SortMode.size:
        return l10n.sortBySize;
    }
  }

  // ── Extracted UI building blocks ─────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final l10n = AppLocalizations.of(context)!;
    return AppBar(
      title: Text(l10n.downloadedAttachments),
      actions: [
        IconButton(
          icon: const Icon(Icons.folder_open),
          tooltip: l10n.openFolder,
          onPressed: _openFolder,
        ),
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: '管理',
          onPressed: () {
            setState(() {
              if (_selecting) {
                _selecting = false;
                _selected.clear();
              } else {
                _selecting = true;
                _selected.clear();
              }
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.filter_list),
          tooltip: '筛选',
          onPressed: _showFilterMenu,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SearchBar(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        hintText: AppLocalizations.of(context)!.searchAttachmentsHint,
        leading: const Icon(Icons.search),
      ),
    );
  }

  Widget _buildFileTile({
    required _FileInfo info,
    required String name,
    required String subtitle,
    required bool isSelected,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final file = info.file;
    return ListTile(
      leading: _selecting
          ? Checkbox(value: isSelected, onChanged: (_) => _toggleSelect(info))
          : Icon(_fileIcon(name), color: Theme.of(context).colorScheme.primary),
      title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
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
      onTap: _selecting ? () => _toggleSelect(info) : () => _openFile(file),
      onLongPress: _selecting ? null : () => _enterSelection(info),
    );
  }

  Widget _buildBatchToolbar() {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedSize(
      duration: appConfigService.cardSizeAnimationDuration.value,
      curve: appCurve,
      alignment: Alignment.topCenter,
      child: _selecting
          ? Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '已选择 ${_selected.length} 个文件',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _selectAll,
                    icon: const Icon(Icons.select_all, size: 18),
                    label: Text(l10n.selectAll),
                  ),
                  const SizedBox(width: 4),
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
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyHint(String message) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  List<_SearchEntry> _buildSearchEntries() {
    final entries = <_SearchEntry>[];
    for (final cfg in _dirConfigs) {
      for (final info in _allFilteredInfos[cfg.dirName] ?? <_FileInfo>[]) {
        entries.add(_SearchEntry(info, cfg.label));
      }
    }
    return entries;
  }

  Widget _buildSearchBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_totalMatches == 0) {
      return _buildEmptyHint(l10n.noData);
    }
    final entries = _buildSearchEntries();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (ctx, index) {
        final entry = entries[index];
        final info = entry.info;
        final name = p.basename(info.file.path);
        final isSelected = _selected.contains(info.file.path);

        return _buildFileTile(
          info: info,
          name: name,
          subtitle:
              '${entry.category}  ·  ${_formatSize(info.size)}  ·  ${formatDate(info.modified)}',
          isSelected: isSelected,
        );
      },
    );
  }

  Widget _buildNormalBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = _allFilteredInfos;
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            for (final cfg in _dirConfigs)
              Tab(
                text: '${cfg.label} (${(filtered[cfg.dirName] ?? []).length})',
              ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              for (final cfg in _dirConfigs)
                _buildFileList(filtered[cfg.dirName] ?? [], l10n),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileList(List<_FileInfo> infos, AppLocalizations l10n) {
    if (infos.isEmpty) {
      return _buildEmptyHint(
        (_query.isNotEmpty || _filterExt.isNotEmpty)
            ? l10n.noData
            : l10n.noDownloadedAttachments,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: infos.length,
      itemBuilder: (ctx, index) {
        final info = infos[index];
        final name = p.basename(info.file.path);
        final isSelected = _selected.contains(info.file.path);

        return _buildFileTile(
          info: info,
          name: name,
          subtitle:
              '${_formatSize(info.size)}  ·  ${formatDate(info.modified)}',
          isSelected: isSelected,
        );
      },
    );
  }

  Widget _buildBody() {
    if (_query.isNotEmpty) return _buildSearchBody();
    return _buildNormalBody();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildBatchToolbar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}
