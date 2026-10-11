import 'package:bugaoshan/widgets/adaptive/adaptive_glass_controls.dart';
import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/reminder_plan.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/reminder/reminder_service.dart';
import 'package:bugaoshan/widgets/common/info_card.dart';
import 'package:bugaoshan/widgets/common/section_title.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/widgets/common/styled_tile.dart';
import 'package:flutter/material.dart';

/// 「通知与提醒」设置页面。
///
/// 聚合系统通知权限授权状态、提醒主开关、提前量偏好、免打扰时段及当前排期状态。
/// 显式呈现授权状态与系统待投递状态，用于异常排查与状态感知。
class ReminderSettingPage extends StatefulWidget {
  const ReminderSettingPage({super.key});

  @override
  State<ReminderSettingPage> createState() => _ReminderSettingPageState();
}

class _ReminderSettingPageState extends State<ReminderSettingPage>
    with WidgetsBindingObserver {
  final _appConfig = getIt<AppConfigProvider>();
  final _service = getIt<ReminderService>();

  /// 系统通知权限状态标识，为 null 时表示尚未完成查询。取值与原生平台返回枚举一致。
  String? _permissionStatus;
  bool _requestingPermission = false;
  int? _pendingCount;
  bool _refreshing = false;

  /// 缓存关闭免打扰功能前的起止时间，用于再次启用时恢复用户原配置，避免覆盖自定义时段。
  TimeOfDay? _lastQuietStart;
  TimeOfDay? _lastQuietEnd;

  /// 提前提醒备选时间列表（单位：分钟）。涵盖近距离教学区与跨校区通勤等不同时间粒度。
  static const List<int> _leadChoices = [5, 10, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastQuietStart = _appConfig.reminderQuietStart.value;
    _lastQuietEnd = _appConfig.reminderQuietEnd.value;
    unawaited(_refreshStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 应用恢复前台时重新查询授权与排期状态，保证用户从系统设置返回后界面及时刷新。
    if (state == AppLifecycleState.resumed) unawaited(_refreshStatus());
  }

  Future<void> _refreshStatus() async {
    // 先强制重排再查询：否则 pendingCount 读到的是上一轮同步的结果，
    // 用户刚改完设置、返回本页时看到的仍是改动前的状态。
    await _service.reschedule(force: true);
    final status = await _service.permissionStatus();
    final pending = await _service.pendingCount();
    if (!mounted) return;
    setState(() {
      _permissionStatus = status;
      _pendingCount = pending;
    });
  }

  bool get _isGranted =>
      _permissionStatus == 'authorized' || _permissionStatus == 'provisional';

  Future<void> _toggleMaster(bool enabled) async {
    _appConfig.reminderEnabled.value = enabled;
    // 开启主开关且处于未决定授权状态时，主动请求系统权限以完成引导流程。
    if (enabled && !_isGranted && _permissionStatus == 'notDetermined') {
      await _requestPermission();
      return;
    }
    await _refreshStatus();
  }

  Future<void> _requestPermission() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    // 权限被系统明确拒绝后无法重复触发授权弹窗，直接引导跳转系统设置页面。
    if (_permissionStatus == 'denied') {
      final opened = await _service.openNotificationSettings();
      if (!opened && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.reminderPermissionOpenFailed)),
        );
      }
      return;
    }
    setState(() => _requestingPermission = true);
    try {
      final granted = await _service.requestPermission();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? l10n.reminderPermissionGrantedToast
                : l10n.reminderPermissionDeniedToast,
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.reminderPermissionFailed}: $e')),
      );
    } finally {
      await _refreshStatus();
      if (mounted) setState(() => _requestingPermission = false);
    }
  }

  Future<void> _pickQuietTime({required bool isStart}) async {
    final current = isStart
        ? _appConfig.reminderQuietStart.value
        : _appConfig.reminderQuietEnd.value;
    final picked = await showTimePicker(
      context: context,
      initialTime:
          current ?? TimeOfDay(hour: isStart ? 23 : 7, minute: isStart ? 0 : 0),
    );
    if (picked == null) return;
    if (isStart) {
      _appConfig.reminderQuietStart.value = picked;
    } else {
      _appConfig.reminderQuietEnd.value = picked;
    }
  }

  Future<void> _refreshPlan() async {
    setState(() => _refreshing = true);
    try {
      // _refreshStatus 内部已包含强制重排逻辑，此处直接复用。
      await _refreshStatus();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reminderSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 权限状态卡片置顶展示：未授权状态下优先引导用户完成权限配置。
          if (!_isGranted) ...[
            _buildPermissionCard(l10n),
            const SizedBox(height: 14),
          ],
          SectionTitle(title: l10n.settingsGeneral),
          InfoCard(children: [_buildMasterSwitch(l10n)]),
          const SizedBox(height: 14),
          _buildCourseSection(l10n),
          const SizedBox(height: 14),
          _buildQuietSection(l10n),
          const SizedBox(height: 14),
          _buildStatusSection(l10n),
          const SizedBox(height: 14),
          _buildPrivacyHint(l10n),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── 权限 ────────────────────────────────────────────────────────

  Widget _buildPermissionCard(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final denied = _permissionStatus == 'denied';
    // 采用中性背景容器搭配错误强调色，避免深色模式下大面积高饱和容器过度强调。
    final accent = theme.colorScheme.error;
    return StyledCard(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notifications_off_outlined, size: 20, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.reminderPermissionTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    denied
                        ? l10n.reminderPermissionDeniedHint
                        : l10n.reminderPermissionNotDeterminedHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: _requestingPermission
                        ? null
                        : _requestPermission,
                    child: _requestingPermission
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            denied
                                ? l10n.reminderPermissionOpenSettings
                                : l10n.reminderPermissionRequest,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 总开关 ──────────────────────────────────────────────────────

  Widget _buildMasterSwitch(AppLocalizations l10n) {
    return ValueListenableBuilder<bool>(
      valueListenable: _appConfig.reminderEnabled,
      builder: (context, enabled, _) => AdaptiveGlassSwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(l10n.reminderMasterSwitch),
        subtitle: Text(
          l10n.reminderMasterSwitchHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        value: enabled,
        onChanged: _toggleMaster,
      ),
    );
  }

  // ── 课前提醒 ────────────────────────────────────────────────────

  Widget _buildCourseSection(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: _appConfig.reminderEnabled,
      builder: (context, masterEnabled, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title: l10n.reminderCourseSection),
          Opacity(
            // 主开关关闭时置灰并禁用交互，维持界面结构可见性。
            opacity: masterEnabled ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !masterEnabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StyledCard(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.reminderLeadTime,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.reminderLeadTimeHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ValueListenableBuilder<List<int>>(
                            valueListenable: _appConfig.reminderLeadMinutes,
                            builder: (context, selected, _) => Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final minutes in _leadChoices)
                                  FilterChip(
                                    label: Text(
                                      l10n.reminderLeadMinutes(minutes),
                                    ),
                                    selected: selected.contains(minutes),
                                    onSelected: (on) {
                                      final next = {...selected};
                                      if (on) {
                                        next.add(minutes);
                                      } else {
                                        next.remove(minutes);
                                      }
                                      // 保证至少保留一个提前时间选项，避免全部取消后与主开关开启状态语义冲突。
                                      if (next.isEmpty) return;
                                      _appConfig.reminderLeadMinutes.value =
                                          next.toList()..sort();
                                    },
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l10n.reminderLeadTimeMultiHint,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 免打扰 ──────────────────────────────────────────────────────

  Widget _buildQuietSection(AppLocalizations l10n) {
    return ValueListenableBuilder<bool>(
      valueListenable: _appConfig.reminderEnabled,
      builder: (context, masterEnabled, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title: l10n.reminderQuietSection),
          Opacity(
            opacity: masterEnabled ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !masterEnabled,
              child: InfoCard(
                children: [
                  ValueListenableBuilder<TimeOfDay?>(
                    valueListenable: _appConfig.reminderQuietStart,
                    builder: (context, start, _) =>
                        ValueListenableBuilder<TimeOfDay?>(
                          valueListenable: _appConfig.reminderQuietEnd,
                          builder: (context, end, _) {
                            final enabled = start != null && end != null;
                            return Column(
                              children: [
                                AdaptiveGlassSwitchListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  title: Text(l10n.reminderQuietEnabled),
                                  subtitle: Text(
                                    l10n.reminderQuietHint,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  value: enabled,
                                  onChanged: (on) {
                                    if (on) {
                                      // 优先恢复历史时段；无历史记录时应用默认起止时段。
                                      final start =
                                          _lastQuietStart ??
                                          const TimeOfDay(hour: 23, minute: 0);
                                      final end =
                                          _lastQuietEnd ??
                                          const TimeOfDay(hour: 7, minute: 0);
                                      _lastQuietStart = start;
                                      _lastQuietEnd = end;
                                      _appConfig.reminderQuietStart.value =
                                          start;
                                      _appConfig.reminderQuietEnd.value = end;
                                    } else {
                                      _lastQuietStart = start;
                                      _lastQuietEnd = end;
                                      _appConfig.reminderQuietStart.value =
                                          null;
                                      _appConfig.reminderQuietEnd.value = null;
                                    }
                                  },
                                ),
                                if (enabled) ...[
                                  IconTile(
                                    icon: Icons.bedtime_outlined,
                                    label: l10n.reminderQuietStart,
                                    value: _hhmm(start),
                                    onTap: () => _pickQuietTime(isStart: true),
                                  ),
                                  IconTile(
                                    icon: Icons.wb_sunny_outlined,
                                    label: l10n.reminderQuietEnd,
                                    value: _hhmm(end),
                                    onTap: () => _pickQuietTime(isStart: false),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 排期状态 ────────────────────────────────────────────────────

  Widget _buildStatusSection(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title: l10n.reminderStatusSection),
        StyledCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<ReminderPlan?>(
                  valueListenable: _service.lastPlan,
                  builder: (context, plan, _) {
                    if (plan == null) {
                      return Text(
                        l10n.reminderStatusEmpty,
                        style: theme.textTheme.bodySmall,
                      );
                    }
                    if (plan.reminders.isEmpty) {
                      return Text(
                        l10n.reminderStatusNoUpcoming,
                        style: theme.textTheme.bodySmall,
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.reminderStatusScheduled(
                            plan.reminders.length,
                            '${plan.windowEnd.month}/${plan.windowEnd.day} '
                            '${plan.windowEnd.hour.toString().padLeft(2, '0')}:'
                            '${plan.windowEnd.minute.toString().padLeft(2, '0')}',
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (_pendingCount != null && _isGranted) ...[
                          const SizedBox(height: 4),
                          Text(
                            l10n.reminderStatusPending(_pendingCount!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (plan.droppedCount > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            l10n.reminderStatusDropped(plan.droppedCount),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          _previewOf(plan, l10n),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: _service.lastError,
                  builder: (context, error, _) => error == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            l10n.reminderStatusError(error),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _refreshing ? null : _refreshPlan,
                    icon: _refreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(l10n.reminderStatusRefresh),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 生成最近待触发提醒项的预览文本，便于用户直观核验排期结果。
  String _previewOf(ReminderPlan plan, AppLocalizations l10n) {
    return plan.reminders
        .take(3)
        .map(
          (r) =>
              '${r.fireAt.month}/${r.fireAt.day} '
              '${r.fireAt.hour.toString().padLeft(2, '0')}:'
              '${r.fireAt.minute.toString().padLeft(2, '0')} '
              '${r.title}',
        )
        .join('\n');
  }

  // ── 隐私提示 ────────────────────────────────────────────────────

  Widget _buildPrivacyHint(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outline,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.reminderPrivacyHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
