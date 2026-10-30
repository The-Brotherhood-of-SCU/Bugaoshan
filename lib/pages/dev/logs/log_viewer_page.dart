import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/dev/logs/log_entry_tile.dart';
import 'package:bugaoshan/pages/dev/logs/log_filter_bar.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/share_utils.dart';
import 'package:bugaoshan/utils/platform_utils.dart';
import 'package:bugaoshan/widgets/common/app_directory_page.dart';

/// 全屏日志查看器（开发者调试用）。
///
/// - 顶栏：复制全部、保存分享、复制目录路径、清空
/// - 内容：level 多选过滤 chip + tag 下拉 + 反时序列表 + 按 level 着色
///
/// 用户反馈问题时也会进入此页，操作文案随应用语言切换。
class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  static const String _tag = 'LogViewerPage';

  final _log = getIt<AppLogger>();
  // null = 全部 level 启用（无筛选）；非空 = 仅显示集合中的 level。
  Set<LogLevel>? _filterLevels;
  String? _filterTag; // null = All
  int _view = 0; // 全部 / 认证 / 业务错误

  @override
  void initState() {
    super.initState();
    _log.addListener(_resetMissingTag);
  }

  void _resetMissingTag() {
    final tag = _filterTag;
    if (tag != null && !_log.hasTag(tag)) {
      setState(() => _filterTag = null);
    }
  }

  @override
  void dispose() {
    _log.removeListener(_resetMissingTag);
    super.dispose();
  }

  /// 解析到日志落盘目录（必要时创建子目录）：
  /// - Android = app 外部 cache 下的 `Bugaoshan/logs/`（文件管理器可见，OS 可清理）
  /// - 其他 = OS temp 下的 `Bugaoshan/logs/`
  ///
  /// 与 [AppLogger] 自动落盘共用同一目录，故「打开文件夹」能看到全部日志文件。
  Future<Directory> _logDir() => resolveLogDir();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.runtimeLogs),
        actions: [
          IconButton(
            tooltip: l10n.logCopyAll,
            icon: const Icon(Icons.copy_all),
            onPressed: _copyAll,
          ),
          IconButton(
            tooltip: l10n.logSaveShare,
            icon: const Icon(Icons.save_alt),
            onPressed: _save,
          ),
          IconButton(
            tooltip: Platform.isAndroid
                ? l10n.logCopyFolderPath
                : l10n.logOpenFolder,
            icon: const Icon(Icons.folder_open),
            onPressed: _openFolder,
          ),
          IconButton(
            tooltip: l10n.logClearMemory,
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
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final (index, label) in [
                          l10n.logAll,
                          l10n.logAuthentication,
                          l10n.logBusinessErrors,
                        ].indexed)
                          ChoiceChip(
                            label: Text(label),
                            selected: _view == index,
                            onSelected: (_) => setState(() {
                              _view = index;
                              _filterTag = null;
                            }),
                          ),
                      ],
                    ),
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
    final l10n = AppLocalizations.of(context)!;
    final all = _log.entries;
    final levels = _filterLevels;
    final filtered = all
        .where((e) {
          if (levels != null && !levels.contains(e.level)) return false;
          if (_view == 1 && e.category != LogCategory.authentication) {
            return false;
          }
          if (_view == 2 &&
              (e.category != LogCategory.business ||
                  (e.level != LogLevel.warn && e.level != LogLevel.error))) {
            return false;
          }
          if (_filterTag != null && e.tag != _filterTag) return false;
          return true;
        })
        .toList(growable: false);

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          all.isEmpty ? l10n.logEmpty : l10n.logNoMatches,
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
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: _log.exportToText()));
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.logCopied)));
    } catch (error, stackTrace) {
      AppLog.e(_tag, '复制日志失败', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.logCopyFailed)));
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await _logDir();
      final path = await _log.exportToFile(dir);
      try {
        if (!mounted) return;
        await shareSingleFile(path, context: context);
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(l10n.logShared)));
      } catch (e, stackTrace) {
        AppLog.e(_tag, '分享日志失败', error: e, stackTrace: stackTrace);
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(l10n.logShareFailed)));
      }
    } catch (e, stackTrace) {
      AppLog.e(_tag, '保存日志失败', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.logSaveFailed)));
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
  /// 取出来的正确路径。OHOS 使用应用内文件列表；其余平台沿用外部目录打开。
  Future<void> _openFolder() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await _logDir();
      if (isOhos) {
        await _log.flushFileSink();
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                AppDirectoryPage(directory: dir, title: l10n.runtimeLogs),
          ),
        );
        return;
      }
      if (Platform.isAndroid) {
        await Clipboard.setData(ClipboardData(text: dir.path));
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.logDirectoryCopied(dir.path))),
        );
        return;
      }
      if (!await launchUrl(Uri.file(dir.path))) throw StateError('文件管理器无法打开');
    } catch (e, stackTrace) {
      AppLog.e(_tag, '打开日志目录失败', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.logDirectoryOpenFailed)),
      );
    }
  }

  Future<void> _confirmClear() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logClearTitle),
        content: Text(l10n.logClearHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true) _log.clear();
  }
}
