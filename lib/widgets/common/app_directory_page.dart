import 'dart:io';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/open_file.dart';
import 'package:bugaoshan/utils/share_utils.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class _DirectoryFile {
  const _DirectoryFile(this.file, this.stat);

  final File file;
  final FileStat stat;
}

/// 浏览应用自己的日志或附件目录；不把沙箱目录 URI 交给外部文件管理器。
class AppDirectoryPage extends StatefulWidget {
  const AppDirectoryPage({
    super.key,
    required this.directory,
    required this.title,
  });

  final Directory directory;
  final String title;

  @override
  State<AppDirectoryPage> createState() => _AppDirectoryPageState();
}

class _AppDirectoryPageState extends State<AppDirectoryPage> {
  static const String _tag = 'AppDirectoryPage';
  late Future<List<_DirectoryFile>> _files;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _files = _loadFiles();
  }

  Future<List<_DirectoryFile>> _loadFiles() =>
      AppLog.guard(_tag, '读取应用目录', () async {
        final files = <_DirectoryFile>[];
        // 只展示直接存放的普通文件，排除内部索引、子目录和符号链接。
        await for (final entity in widget.directory.list(followLinks: false)) {
          if (entity is! File || p.basename(entity.path).startsWith('.')) {
            continue;
          }
          final stat = await entity.stat();
          // 日志可能恰好轮转，附件也可能被其他页面删除。
          if (stat.type == FileSystemEntityType.file) {
            files.add(_DirectoryFile(entity, stat));
          }
        }
        files.sort((a, b) {
          final byTime = b.stat.modified.compareTo(a.stat.modified);
          return byTime != 0 ? byTime : a.file.path.compareTo(b.file.path);
        });
        return files;
      });

  void _refresh() {
    setState(() {
      _files = _loadFiles();
    });
  }

  Future<void> _open(File file) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await openFile(file.path);
      if (result.type != ResultType.done) {
        throw StateError('File open failed: ${result.type.name}');
      }
    } catch (error, stackTrace) {
      AppLog.e(_tag, '打开目录文件失败', error: error, stackTrace: stackTrace);
      if (mounted) {
        _showError(AppLocalizations.of(context)!.appDirectoryOpenFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(File file) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // 分享独立副本，接收方读取时不受日志轮转或附件删除影响。
      final cache = await getTemporaryDirectory();
      final snapshotDir = await cache.createTemp('directory-share-');
      final snapshot = await file.copy(
        p.join(snapshotDir.path, p.basename(file.path)),
      );
      if (!mounted) return;
      await shareSingleFile(snapshot.path, context: context);
      // 分享面板关闭时接收方可能尚未读完，副本交由应用缓存清理。
    } catch (error, stackTrace) {
      AppLog.e(_tag, '分享目录文件失败', error: error, stackTrace: stackTrace);
      if (mounted) {
        _showError(AppLocalizations.of(context)!.appDirectoryShareFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _fileDetails(BuildContext context, FileStat stat) {
    final size = stat.size;
    final formattedSize = size < 1024
        ? '$size B'
        : size < 1024 * 1024
        ? '${(size / 1024).toStringAsFixed(1)} KB'
        : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    final localizations = MaterialLocalizations.of(context);
    final modified = stat.modified.toLocal();
    return '$formattedSize · ${localizations.formatShortDate(modified)} '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(modified))}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<_DirectoryFile>>(
      future: _files,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              IconButton(
                tooltip: l10n.refresh,
                onPressed: loading || _busy ? null : _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (_busy) const LinearProgressIndicator(),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : snapshot.hasError
                      ? Center(child: Text(l10n.appDirectoryLoadFailed))
                      : snapshot.data!.isEmpty
                      ? Center(child: Text(l10n.appDirectoryEmpty))
                      : ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final entry = snapshot.data![index];
                            return ListTile(
                              leading: const Icon(
                                Icons.insert_drive_file_outlined,
                              ),
                              title: Text(p.basename(entry.file.path)),
                              subtitle: Text(_fileDetails(context, entry.stat)),
                              onTap: _busy ? null : () => _open(entry.file),
                              trailing: IconButton(
                                tooltip: l10n.share,
                                onPressed: _busy
                                    ? null
                                    : () => _share(entry.file),
                                icon: const Icon(Icons.share_outlined),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
