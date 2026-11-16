import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bugaoshan/services/storage_cleanup_service.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:bugaoshan/utils/share_utils.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

/// 启动失败时的兜底界面：直接以 MaterialApp 作为根，展示错误堆栈，
/// 并提供清理本地存储的恢复入口（DI 可能尚未装配完成，故不依赖 GetIt 之外的设施）。
class StartupErrorApp extends StatefulWidget {
  final String? errorMessage;
  final Directory? logExportDirectory;
  const StartupErrorApp({
    super.key,
    this.errorMessage,
    this.logExportDirectory,
  });

  @override
  State<StartupErrorApp> createState() => _StartupErrorAppState();
}

class _StartupErrorAppState extends State<StartupErrorApp> {
  static const String _tag = 'StartupErrorAppState';

  String? _status;
  bool _exporting = false;

  Future<void> _copyLogs(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Clipboard.setData(ClipboardData(text: AppLog.exportToText()));
      _setStatus(l10n.logCopied);
    } catch (error, stackTrace) {
      AppLog.e(_tag, '复制启动日志失败', error: error, stackTrace: stackTrace);
      _setStatus(l10n.logCopyFailed);
    }
  }

  Future<void> _exportLogs(BuildContext context, {required bool share}) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _exporting = true);
    String? path;
    try {
      final directory = widget.logExportDirectory ?? await resolveLogDir();
      path = await AppLog.exportToFile(directory);
      _setStatus(l10n.logSaved(path));
      if (share && context.mounted) {
        await shareSingleFile(path, context: context);
      }
    } catch (error, stackTrace) {
      AppLog.e(
        _tag,
        path == null ? '保存启动日志失败' : '分享启动日志失败',
        error: error,
        stackTrace: stackTrace,
      );
      _setStatus(
        path == null
            ? l10n.logSaveFailed
            : '${l10n.logSaved(path)}\n${l10n.logShareFailed}',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _setStatus(String status) {
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _run(
    BuildContext context,
    String label,
    Future<void> Function() action,
  ) async {
    if (!await _confirm(context, label)) return;
    try {
      await action();
      _setStatus('$label: done');
    } catch (error, stackTrace) {
      AppLog.e(_tag, '$label 失败', error: error, stackTrace: stackTrace);
      _setStatus('$label: failed - $error');
    }
  }

  /// 清理不可撤销，执行前先与用户确认。
  Future<bool> _confirm(BuildContext context, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$label?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // home 外再套一层 Builder：State.context 位于 MaterialApp 之上，
    // 沿着它向上找不到 Localizations / Navigator，直接拿它调 showDialog
    // 会命中 debugCheckHasMaterialLocalizations 断言。
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: _buildPage),
    );
  }

  Widget _buildPage(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final canClearCache = StorageCleanupService.canClearCacheDirectory;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.logStartupTitle,
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.linear(1.5),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  widget.errorMessage ?? '',
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _exporting ? null : () => _copyLogs(context),
                      icon: const Icon(Icons.copy_all),
                      label: Text(l10n.logCopy),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exporting
                          ? null
                          : () => _exportLogs(context, share: false),
                      icon: const Icon(Icons.save_alt),
                      label: Text(l10n.logSave),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exporting
                          ? null
                          : () => _exportLogs(context, share: true),
                      icon: const Icon(Icons.share),
                      label: Text(l10n.logShare),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.error),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 20,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '危险操作 / Danger Zone',
                            style: TextStyle(
                              color: colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'These actions delete local data and cannot be undone.',
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton(
                            onPressed: () => _run(
                              context,
                              'Clear Shared Preferences',
                              StorageCleanupService.clearSharedPreferences,
                            ),
                            child: const Text('Clear Shared Preferences'),
                          ),
                          Tooltip(
                            message: canClearCache
                                ? 'Deletes the app-private cache directory.'
                                : 'Unavailable on this platform: the temporary '
                                      'directory is shared with other programs.',
                            child: ElevatedButton(
                              onPressed: canClearCache
                                  ? () => _run(
                                      context,
                                      'Clear Cache Directory',
                                      StorageCleanupService.clearCacheDirectory,
                                    )
                                  : null,
                              child: const Text('Clear Cache Directory'),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _run(
                              context,
                              'Clear Data Directory',
                              StorageCleanupService.clearDataDirectory,
                            ),
                            child: const Text('Clear Data Directory'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 16),
                  SelectableText(_status!, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
