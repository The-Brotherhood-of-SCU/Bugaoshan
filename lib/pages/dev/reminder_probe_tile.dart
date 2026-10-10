import 'dart:convert';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/reminder_plan.dart';
import 'package:bugaoshan/services/reminder/reminder_service.dart';
import 'package:bugaoshan/services/reminder/reminder_transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 开发者选项中的本地提醒排期探针组件。
///
/// 用于调试并观测本地提醒状态：展示授权状态、排期计划摘要与系统挂起计数，
/// 并通过真实调度链路发送短延迟探针通知，以隔离排期计算异常与宿主平台投递异常。
class ReminderProbeTile extends StatefulWidget {
  const ReminderProbeTile({super.key});

  @override
  State<ReminderProbeTile> createState() => _ReminderProbeTileState();
}

class _ReminderProbeTileState extends State<ReminderProbeTile> {
  bool _sending = false;
  bool _requesting = false;

  /// 系统通知授权状态，为 null 表示尚未查询。
  /// 用于区分直接触发权限请求弹窗与引导跳转系统设置页面的交互分支。
  String? _permissionStatus;

  @override
  void initState() {
    super.initState();
    _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final status = await getIt<ReminderService>().permissionStatus();
    if (mounted) setState(() => _permissionStatus = status);
  }

  Future<void> _requestPermission() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final service = getIt<ReminderService>();

    // 权限被拒后系统不再弹窗提示，引导跳转至系统设置界面进行手动授权。
    if (_permissionStatus == 'denied') {
      final opened = await service.openNotificationSettings();
      if (!opened && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.reminderHostProbeOpenSettingsFailed)),
        );
      }
      return;
    }

    setState(() => _requesting = true);
    try {
      final granted = await service.requestPermission();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? l10n.reminderHostProbePermissionGranted
                : l10n.reminderHostProbePermissionDenied,
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.reminderHostProbeFailed}: $e')),
      );
    } finally {
      await _refreshPermission();
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _fireProbe() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await getIt<ReminderService>().fireProbe(
        title: l10n.reminderProbeTitle,
        body: l10n.reminderProbeBody,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.reminderHostProbeSent)),
      );
    } on ReminderPermissionDenied {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.reminderHostProbeDenied)),
      );
      await _refreshPermission();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.reminderHostProbeFailed}: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _copyPlan(ReminderPlan plan) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final text = const JsonEncoder.withIndent('  ').convert(plan.toJson());
    try {
      await Clipboard.setData(ClipboardData(text: text));
      messenger.showSnackBar(SnackBar(content: Text(l10n.reminderPlanCopied)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.reminderPlanFailed}: $e')),
      );
    }
  }

  /// 构建授权状态视图行。
  ///
  /// 保持 ListTile 默认 contentPadding，确保左侧图标列与同级列表项视觉对齐。
  Widget _buildPermissionRow(AppLocalizations l10n, ThemeData theme) {
    final status = _permissionStatus;
    final granted = status == 'authorized' || status == 'provisional';
    final label = switch (status) {
      null => l10n.reminderHostProbePermissionUnknown,
      'authorized' => l10n.reminderHostProbePermissionAuthorized,
      'provisional' => l10n.reminderHostProbePermissionProvisional,
      'denied' => l10n.reminderHostProbePermissionDeniedLabel,
      'notDetermined' => l10n.reminderHostProbePermissionNotDetermined,
      _ => l10n.reminderHostProbePermissionUnknown,
    };

    return ListTile(
      leading: Icon(
        granted ? Icons.notifications_active : Icons.notifications_off_outlined,
        color: granted ? theme.colorScheme.primary : theme.colorScheme.error,
      ),
      title: Text(l10n.reminderHostProbePermissionTitle),
      subtitle: Text(label, style: theme.textTheme.bodySmall),
      trailing: _requesting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FilledButton.tonal(
              onPressed: _requestPermission,
              child: Text(
                // 权限处于被拒状态时切换按钮文案为引导打开系统设置。
                status == 'denied'
                    ? l10n.reminderHostProbeOpenSettings
                    : l10n.reminderHostProbeRequestPermission,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = getIt<ReminderService>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPermissionRow(l10n, theme),
        const Divider(height: 24),
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(l10n.reminderHostProbeTitle),
          subtitle: Text(
            l10n.reminderHostProbeSubtitle,
            style: theme.textTheme.bodySmall,
          ),
          trailing: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FilledButton.tonal(
                  onPressed: _fireProbe,
                  child: Text(l10n.reminderHostProbeAction),
                ),
        ),
        ValueListenableBuilder<ReminderPlan?>(
          valueListenable: service.lastPlan,
          builder: (context, plan, _) {
            // 保持与同级 ListTile 内容对齐（水平内边距 16）。
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: plan == null
                  ? Text(
                      l10n.reminderPlanEmpty,
                      style: theme.textTheme.bodySmall,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.reminderPlanSummary(
                            plan.reminders.length,
                            '${plan.windowEnd.month}/${plan.windowEnd.day} '
                            '${plan.windowEnd.hour.toString().padLeft(2, '0')}:'
                            '${plan.windowEnd.minute.toString().padLeft(2, '0')}',
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                        if (plan.droppedCount > 0)
                          Text(
                            l10n.reminderPlanDropped(plan.droppedCount),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        FutureBuilder<int>(
                          future: service.pendingCount(),
                          builder: (context, snapshot) => snapshot.hasData
                              ? Text(
                                  l10n.reminderPlanPending(snapshot.data!),
                                  style: theme.textTheme.bodySmall,
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (plan.reminders.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              plan.reminders
                                  .take(3)
                                  .map(
                                    (r) =>
                                        '${r.fireAt.month}/${r.fireAt.day} '
                                        '${r.fireAt.hour.toString().padLeft(2, '0')}:'
                                        '${r.fireAt.minute.toString().padLeft(2, '0')} '
                                        '${r.title}',
                                  )
                                  .join('\n'),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _copyPlan(plan),
                            icon: const Icon(Icons.copy, size: 16),
                            label: Text(l10n.reminderPlanCopy),
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
        ValueListenableBuilder<String?>(
          valueListenable: service.lastError,
          builder: (context, error, _) => error == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Text(
                    error,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
