import 'package:flutter/material.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/app_logger.dart';

/// Dev 页的「落盘开关」入口。
///
/// 与设置页的同名开关共用 [AppConfigProvider.logPersistenceEnabled]，两处
/// 读写的是同一个 ValueNotifier，改动任一处即时生效——不存在两份状态。
///
/// 为什么要在 Dev 页再放一个：普通用户不会为了「把崩溃现场交给开发者」去翻
/// 设置页，而出问题时主动开这个开关的人恰恰就是开发者。放在压测入口旁边，
/// 「开启 → 复现 → adb 拉文件」是一条连贯的路径。
class LogPersistenceTile extends StatelessWidget {
  const LogPersistenceTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appConfig = getIt<AppConfigProvider>();
    final logger = getIt<AppLogger>();

    // 开关状态与「落盘实际是否可用」是两件事：前者是用户意图（ValueNotifier），
    // 后者由 sink 健康状况决定（AppLogger 自身也是 ChangeNotifier）。
    // 两个都监听，否则故障期间 UI 不会更新——而这正是最需要它更新的时刻。
    return ListenableBuilder(
      listenable: Listenable.merge([appConfig.logPersistenceEnabled, logger]),
      builder: (context, _) {
        final enabled = appConfig.logPersistenceEnabled.value;
        final unavailable = logger.fileSinkUnavailable;
        return SwitchListTile(
          // 不设 contentPadding：与本页其余 ListTile 的默认内边距对齐。
          secondary: Icon(unavailable ? Icons.warning_amber : Icons.save_alt),
          title: const Text('保留诊断日志到本机'),
          subtitle: Text(
            _subtitle(enabled, unavailable, logger.fileSinkError),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: unavailable ? Theme.of(context).colorScheme.error : null,
            ),
          ),
          value: enabled,
          onChanged: (v) => appConfig.logPersistenceEnabled.value = v,
        );
      },
    );
  }

  /// 如实反映三态：已关闭 / 正常写入 / **配置为开但实际写不进去**。
  ///
  /// 最后一种最关键：此时用户看到的开关是「开」，若文案还说「正在初始化」
  /// 或照常显示写入说明，用户会以为日志已被保留——而崩溃现场恰恰因此丢失。
  static String _subtitle(bool enabled, bool unavailable, String? error) {
    if (!enabled) return '关闭时仅保留在内存，App 退出即丢失';
    if (unavailable) {
      return '落盘不可用${error == null ? '' : '：$error'}\n'
          '请关闭后重新开启；若仍失败，可能是设备存储空间不足。';
    }
    return 'warn/error 会写入 bugaoshan.log（约 6 MB 上限，自动轮转）';
  }
}
