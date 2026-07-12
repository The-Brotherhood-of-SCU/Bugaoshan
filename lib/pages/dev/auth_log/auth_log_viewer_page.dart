import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/campus/downloads/file_utils.dart';
import 'package:bugaoshan/pages/dev/auth_log/auth_log_entry_tile.dart';
import 'package:bugaoshan/pages/dev/auth_log/auth_log_filter_bar.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/utils/share_utils.dart';

/// 全屏日志查看器（开发者调试用，文案不做 i18n）。
///
/// - 顶栏：复制全部、保存分享、打开文件夹、清空
/// - 内容：level 多选过滤 chip + tag 下拉 + 反时序列表 + 按 level 着色
class AuthLogViewerPage extends StatefulWidget {
  const AuthLogViewerPage({super.key});

  @override
  State<AuthLogViewerPage> createState() => _AuthLogViewerPageState();
}

class _AuthLogViewerPageState extends State<AuthLogViewerPage> {
  static const String _appBarTitle = 'Auth Log';

  // 跟 notice_downloaded_page 保持一致；debug 构建下打开文件夹可能失败但
  // 现有附件页也是这个行为，故沿用。
  static const String _androidPackageId =
      'io.github.the_brotherhood_of_scu.bugaoshan';

  final _log = getIt<AuthLogger>();
  // null = 全部 level 启用（无筛选）；非空 = 仅显示集合中的 level。
  Set<AuthLogLevel>? _filterLevels;
  String? _filterTag; // null = All

  /// 解析到 auth log 落盘目录（必要时创建子目录）：
  /// - Android = app 外部 cache 下的 `Bugaoshan/auth_logs/`（文件管理器可见，OS 可清理）
  /// - 其他 = OS temp 下的 `Bugaoshan/auth_logs/`
  Future<Directory> _authLogDir() async {
    final base = await getAuthLogBaseDir();
    final dir = Directory('${base.path}/Bugaoshan/$kAuthLogDir');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(_appBarTitle),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy_all),
            onPressed: _copyAll,
          ),
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save_alt),
            onPressed: _save,
          ),
          IconButton(
            tooltip: 'Open folder',
            icon: const Icon(Icons.folder_open),
            onPressed: _openFolder,
          ),
          IconButton(
            tooltip: 'Clear log',
            icon: const Icon(Icons.delete_sweep),
            onPressed: _confirmClear,
          ),
        ],
      ),
      body: Column(
        children: [
          AuthLogFilterBar(
            entries: _log.entries,
            levels: _filterLevels,
            tag: _filterTag,
            onLevelToggled: _toggleLevel,
            onTagChanged: (v) => setState(() => _filterTag = v),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListenableBuilder(
              listenable: _log,
              builder: (context, _) {
                final all = _log.entries;
                final levels = _filterLevels;
                final filtered = all
                    .where((e) {
                      if (levels != null && !levels.contains(e.level)) {
                        return false;
                      }
                      if (_filterTag != null && e.tag != _filterTag) {
                        return false;
                      }
                      return true;
                    })
                    .toList(growable: false);

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      all.isEmpty ? 'No auth log yet.' : 'No matching entries.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                // 反时序：新条目在顶端。
                final reversed = filtered.reversed.toList(growable: false);
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: reversed.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      AuthLogEntryTile(entry: reversed[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleLevel(AuthLogLevel level, bool selected) {
    setState(() {
      final current = _filterLevels;
      if (selected) {
        // 勾选一个 level：第一次勾选时变成「只显示这个」，再勾选更多 = 多选并集。
        _filterLevels = {...?current, level};
      } else {
        if (current == null) {
          // 当前是「全部启用」状态；取消勾选该 level ⇒ 改成「其他三个」。
          _filterLevels = {
            for (final l in AuthLogLevel.values)
              if (l != level) l,
          };
        } else {
          current.remove(level);
          if (current.isEmpty || current.length == AuthLogLevel.values.length) {
            // 全部取消 或 等价于全部勾上 ⇒ 视作「无筛选」
            _filterLevels = null;
          } else {
            _filterLevels = {...current};
          }
        }
      }
    });
  }

  Future<void> _copyAll() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _log.exportToText()));
    messenger.showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await _authLogDir();
      final path = await _log.exportToFile(dir);
      try {
        if (!mounted) return;
        await shareSingleFile(path, context: context);
        messenger.showSnackBar(const SnackBar(content: Text('Saved')));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  /// 打开 auth log 所在目录：
  /// - Android：通过 content URI 调起系统的文件管理器，定位到 app 外部 cache 子目录。
  /// - 其他平台：直接用文件 URI 调起系统文件管理器（macOS Finder / Windows Explorer / Linux xdg-open）。
  Future<void> _openFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    final dir = await _authLogDir();
    try {
      if (Platform.isAndroid) {
        final encoded = 'Bugaoshan/$kAuthLogDir'.replaceAll('/', '%2F');
        final uri = Uri.parse(
          'content://com.android.externalstorage.documents/document/'
          'primary%3AAndroid%2Fdata%2F$_androidPackageId%2Fcache%2F$encoded',
        );
        await launchUrl(uri);
      } else {
        await launchUrl(Uri.file(dir.path));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Open folder failed: $e')));
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear auth log?'),
        content: const Text(
          'This removes all log entries currently in memory. '
          'Saved files are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) _log.clear();
  }
}
