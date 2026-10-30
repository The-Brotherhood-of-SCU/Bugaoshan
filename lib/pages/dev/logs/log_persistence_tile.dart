import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

/// Dev 页的「落盘开关」入口。
///
/// 通过 [logPersistenceEnabledSettingProvider] 控制文件输出并保存开关状态。
/// 放在压测入口旁边，便于开启落盘后复现问题并导出日志。
class LogPersistenceTile extends ConsumerWidget {
  const LogPersistenceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = ref.watch(logPersistenceEnabledSettingProvider);
    final logger = ref.watch(appLoggerBridge);

    // 开关状态与「落盘实际是否可用」是两件事：前者是用户意图（ValueNotifier/Pod），
    // 后者由 sink 健康状况决定（AppLogger 自身也是 ChangeNotifier）。
    // 两个都监听，否则故障期间 UI 不会更新——而这正是最需要它更新的时刻。
    return ListenableBuilder(
      listenable: logger,
      builder: (context, _) {
        final unavailable = logger.fileSinkUnavailable;
        final dropped = logger.droppedWriteLines;
        return SwitchListTile(
          // 不设 contentPadding：与本页其余 ListTile 的默认内边距对齐。
          secondary: Icon(
            unavailable || dropped > 0 ? Icons.warning_amber : Icons.save_alt,
          ),
          title: Text(l10n.logPersistenceSwitch),
          subtitle: Text(
            '${_subtitle(l10n, enabled, unavailable, logger.fileSinkError)}'
            '${dropped == 0 ? '' : '\n${l10n.logDroppedEntries(dropped)}'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: unavailable || dropped > 0
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
          value: enabled,
          onChanged: (v) =>
              ref.read(logPersistenceEnabledSettingProvider.notifier).update(v),
        );
      },
    );
  }

  /// 如实反映三态：已关闭 / 正常写入 / **配置为开但实际写不进去**。
  ///
  /// 最后一种最关键：此时用户看到的开关是「开」，若文案还说「正在初始化」
  /// 或照常显示写入说明，用户会以为日志已被保留——而崩溃现场恰恰因此丢失。
  static String _subtitle(
    AppLocalizations l10n,
    bool enabled,
    bool unavailable,
    String? error,
  ) {
    if (!enabled) return l10n.logPersistenceOff;
    if (unavailable) {
      return '${l10n.logPersistenceUnavailable(error == null ? '' : ': $error')}\n'
          '${l10n.logPersistenceRetryHint}';
    }
    return l10n.logPersistenceActive;
  }
}
