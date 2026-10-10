import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';

/// 仅 debug 构建可见：压测日志落盘，一次性发出 N 条带序号的 warn/error。
///
/// 用途：验证「日志轮转在高频写入下是否丢日志」这类**文件系统时序问题**。
/// 该类问题在 `flutter test` 里不可靠（宿主文件系统与移动端差异），
/// 需在真机或模拟器上跑，并用 `adb` 拉取日志目录核对行数：
///
/// ```
/// # 触发后执行（Android 外部 cache）：
/// adb shell run-as <包名> ls -l cache/Bugaoshan/logs/
/// ```
///
/// 之所以用「带序号的消息」而非单纯计数：若确有丢失，能直接看出丢的是
/// 哪几条、第几轮轮转开始丢，而不只是「少了N 条」。
class LogStressTile extends StatelessWidget {
  /// 单次压测的条数。
  ///
  /// 取 200是为了在 2 MB × 3 份的默认配置下触发多次轮转
  /// （每条约 100 字节，200 条 ≈ 20 KB，远小于容量——
  /// 想验证「不丢」时应确保写入量不超过容量，否则超出部分本就该被淘汰）。
  static const int defaultBurst = 200;

  final int burst;

  const LogStressTile({super.key, this.burst = defaultBurst});

  @override
  Widget build(BuildContext context) {
    // release 构建直接不渲染，避免把测试工具暴露给用户。
    if (!kDebugMode) return const SizedBox.shrink();

    final logger = getIt<AppLogger>();
    return ListTile(
      leading: const Icon(Icons.speed),
      title: const Text('压测日志落盘（仅 debug）'),
      subtitle: Text('发出 $burst 条 warn/error，用于核对是否丢日志'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final confirmed = await showYesNoDialog(
          title: '压测日志落盘',
          content:
              '将连续写入 $burst 条 warn/error 日志。\n\n'
              '触发后请用 adb 拉取日志目录，核对总行数是否等于 $burst。\n'
              '注意：若落盘容量小于写入量，超出部分会被正常轮转淘汰，'
              '此时行数少于 $burst 属预期。',
        );
        if (confirmed != true) return;

        // 刻意不做 await：模拟真实场景中的同步突发（如批量错误同时抛出），
        // 这正是旧实现丢日志的触发条件。
        for (var i = 0; i < burst; i++) {
          logger.w('LogStress', 'stress-$i ${'x' * 80}');
        }

        if (!context.mounted) return;
        final sinkOn = logger.fileSinkEnabled;
        final message = sinkOn
            ? '已写入 $burst 条到内存队列。若落盘未开启，请先在软件设置中开启。'
            : '已写入 $burst 条到内存，但**落盘当前未开启**，磁盘上不会有文件。'
                  '请先到「设置 → 软件设置」开启「在本机保留诊断日志」。';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 6),
          ),
        );
      },
    );
  }
}
