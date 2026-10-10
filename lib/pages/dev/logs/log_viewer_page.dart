import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/dev/logs/log_entry_tile.dart';
import 'package:bugaoshan/pages/dev/logs/log_filter_bar.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:bugaoshan/utils/share_utils.dart';

/// 全屏日志查看器（开发者调试用）。
///
/// - 顶栏：复制全部、保存分享、复制目录路径、清空
/// - 内容：level 多选过滤 chip + tag 下拉 + 反时序列表 + 按 level 着色
///
/// 文案直接写中文而非走 l10n：本页只在 Dev 页出现，不面向普通用户，
/// 引入 arb 键反而增加翻译维护成本。
class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  static const String _appBarTitle = '应用日志';

  final _log = getIt<AppLogger>();
  // null = 全部 level 启用（无筛选）；非空 = 仅显示集合中的 level。
  Set<LogLevel>? _filterLevels;
  String? _filterTag; // null = All

  /// 解析到日志落盘目录（必要时创建子目录）：
  /// - Android = app 外部 cache 下的 `Bugaoshan/logs/`（文件管理器可见，OS 可清理）
  /// - 其他 = OS temp 下的 `Bugaoshan/logs/`
  ///
  /// 与 [AppLogger] 自动落盘共用同一目录，故「打开文件夹」能看到全部日志文件。
  Future<Directory> _logDir() => resolveLogDir();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(_appBarTitle),
        actions: [
          IconButton(
            tooltip: '复制全部',
            icon: const Icon(Icons.copy_all),
            onPressed: _copyAll,
          ),
          IconButton(
            tooltip: '保存并分享',
            icon: const Icon(Icons.save_alt),
            onPressed: _save,
          ),
          IconButton(
            tooltip: '复制日志目录路径',
            icon: const Icon(Icons.folder_open),
            onPressed: _openFolder,
          ),
          IconButton(
            tooltip: '清空内存日志',
            icon: const Icon(Icons.delete_sweep),
            onPressed: _confirmClear,
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          Expanded(
            // 筛选条与列表同处此监听器内：tag 下拉的条数依赖当前缓冲，
            // 放在外面则只有 setState（切换筛选）时才刷新，新日志带来的
            // tag 与条数变化不会反映到下拉上。
            child: ListenableBuilder(
              listenable: _log,
              builder: (context, _) {
                return Column(
                  children: [
                    LogFilterBar(
                      tagCounts: _log.tagCounts,
                      levels: _filterLevels,
                      tag: _filterTag,
                      onLevelToggled: _toggleLevel,
                      onTagChanged: (v) => setState(() => _filterTag = v),
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildList(context)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final all = _log.entries;
    final levels = _filterLevels;
    final filtered = all
        .where((e) {
          if (levels != null && !levels.contains(e.level)) return false;
          if (_filterTag != null && e.tag != _filterTag) return false;
          return true;
        })
        .toList(growable: false);

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          all.isEmpty ? '暂无日志' : '没有符合条件的日志',
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
      itemBuilder: (context, i) => LogEntryTile(entry: reversed[i]),
    );
  }

  void _toggleLevel(LogLevel level, bool selected) {
    setState(() {
      final current = _filterLevels;
      if (selected) {
        // 勾选一个 level：第一次勾选时变成「只显示这个」，再勾选更多 = 多选并集。
        _filterLevels = {...?current, level};
      } else {
        if (current == null) {
          // 当前是「全部启用」状态；取消勾选该 level ⇒ 改成「其他三个」。
          _filterLevels = {
            for (final l in LogLevel.values)
              if (l != level) l,
          };
        } else {
          current.remove(level);
          if (current.isEmpty || current.length == LogLevel.values.length) {
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
    messenger.showSnackBar(const SnackBar(content: Text('已复制全部日志到剪贴板')));
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await _logDir();
      final path = await _log.exportToFile(dir);
      try {
        if (!mounted) return;
        await shareSingleFile(path, context: context);
        messenger.showSnackBar(const SnackBar(content: Text('已导出，正在分享…')));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  /// 打开 app log 所在目录。
  ///
  /// Android 上**不能**直接调起文件管理器：
  /// - 系统 DocumentsUI 只注册了 `ACTION_OPEN_DOCUMENT`，不接受 VIEW 一个目录
  ///   document URI，故 `launchUrl` 必然抛
  ///   `PlatformException(ACTIVITY_NOT_FOUND)`；
  /// - 且 Android 11+ scoped storage 下文件管理器无权进入
  ///   `Android/data/<package>/cache/`。
  ///
  /// 因此 Android 改为「复制绝对路径」——配合顶栏 Save（分享导出）才是把日志
  /// 取出来的正确路径。其余平台 `Uri.file(dir)` 交给桌面文件管理器是有效的。
  Future<void> _openFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    final dir = await _logDir();
    if (Platform.isAndroid) {
      await Clipboard.setData(ClipboardData(text: dir.path));
      messenger.showSnackBar(
        SnackBar(content: Text('已复制目录路径：${dir.path}\n点「保存并分享」可把日志发给自己。')),
      );
      return;
    }
    try {
      await launchUrl(Uri.file(dir.path));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('打开目录失败：$e')));
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空内存中的日志？'),
        content: const Text('仅清空当前内存中的日志，磁盘上已保存的文件不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed == true) _log.clear();
  }
}
