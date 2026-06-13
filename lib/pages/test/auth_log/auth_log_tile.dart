import 'package:flutter/material.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/test/auth_log/auth_log_viewer_page.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

/// TestPage 入口：认证日志。
/// 点击进入全屏日志查看器（保存 / 打开文件夹 / 清空由查看器 AppBar 提供）。
class AuthLogTile extends StatelessWidget {
  const AuthLogTile({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final log = getIt<AuthLogger>();

    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final entries = log.entries;
        final last = entries.isEmpty ? null : entries.last;
        final subtitle = last == null
            ? localizations.authLogEmpty
            : localizations.authLogLastEntry(
                _formatTime(last.timestamp),
                last.level.name.toUpperCase(),
                last.tag,
              );
        return ListTile(
          leading: const Icon(Icons.key),
          title: Text(localizations.viewAuthLog),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Text(
            '${entries.length}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          onTap: () => Navigator.of(
            logicRootContext,
          ).push(MaterialPageRoute(builder: (_) => const AuthLogViewerPage())),
        );
      },
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _formatTime(DateTime t) {
    return '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
  }
}
