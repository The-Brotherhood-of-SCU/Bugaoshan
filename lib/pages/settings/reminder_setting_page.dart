import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/reminder_plan.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/reminder/reminder_service.dart';
import 'package:bugaoshan/services/reminder/reminder_transport.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/utils/system_insets.dart';
import 'package:bugaoshan/widgets/adaptive/adaptive_glass_controls.dart';
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

  /// 系统通知权限状态，为 null 时表示尚未完成查询。
  ReminderPermissionStatus? _permissionStatus;
  bool _requestingPermission = false;
  int? _pendingCount;
  bool _refreshing = false;

  /// 缓存关闭免打扰功能前的起止时间，用于再次启用时恢复用户原配置，避免覆盖自定义时段。
  TimeOfDay? _lastQuietStart;
  TimeOfDay? _lastQuietEnd;

  /// 提前提醒备选时间列表（单位：分钟）。涵盖近距离教学区与跨校区通勤等不同时间粒度。
  static const List<int> _leadChoices = [5, 10, 15, 30, 60];

  /// 卡片内带 [TileIcon] 的行文本起始缩进（20 左内边距 + 36 图标宽 + 14 间距）。
  static const double _tileDividerIndent = 70;

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
    final status = await _service.permissionStatus();
    if (status.isGranted && !_isGranted) {
      // Returning from system settings must restore requests even if the plan
      // itself has not changed since permission was revoked.
      await _service.onPermissionGranted();
    } else {
      await _service.reschedule(force: true);
    }
    // Query pending requests after scheduling, so the count is current.
    final pending = await _service.pendingCount();
    if (!mounted) return;
    setState(() {
      _permissionStatus = status;
      _pendingCount = pending;
    });
  }

  bool get _isGranted => _permissionStatus?.isGranted ?? false;

  /// 当前平台不具备本地提醒投递能力，授权引导无意义。
  bool get _isPermissionUnsupported =>
      _permissionStatus == ReminderPermissionStatus.unsupported;

  Duration get _animDuration => _appConfig.cardSizeAnimationDuration.value;

  Future<void> _toggleMaster(bool enabled) async {
    _appConfig.reminderEnabled.value = enabled;
    // 开启主开关且处于未决定授权状态时，主动请求系统权限以完成引导流程。
    if (enabled &&
        !_isGranted &&
        _permissionStatus == ReminderPermissionStatus.notDetermined) {
      await _requestPermission();
      return;
    }
    await _refreshStatus();
  }

  Future<void> _requestPermission() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    // 权限被系统明确拒绝后无法重复触发授权弹窗，直接引导跳转系统设置页面。
    if (_permissionStatus == ReminderPermissionStatus.denied) {
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
      if (!mounted) return;
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

  static String _formatMonthDayTime(DateTime dt) =>
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reminderSettingsTitle)),
      body: ListView(
        padding: withSystemBottomInset(
          context,
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        children: [
          // 权限状态横幅：授权通过后平滑收起，避免从系统设置返回时生硬跳变。
          AnimatedSize(
            duration: _animDuration,
            curve: appCurve,
            alignment: Alignment.topCenter,
            child: _permissionStatus == null || _isGranted
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildPermissionCard(l10n),
                  ),
          ),
          SectionTitle(title: l10n.settingsGeneral),
          InfoCard(
            indent: _tileDividerIndent,
            children: [_buildMasterSwitch(l10n)],
          ),
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

  // ── 权限引导卡片 ─────────────────────────────────────────────────

  Widget _buildPermissionCard(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final denied = _permissionStatus == ReminderPermissionStatus.denied;
    final accent = _isPermissionUnsupported
        ? colorScheme.onSurfaceVariant
        : colorScheme.error;
    final hint = switch (_permissionStatus) {
      ReminderPermissionStatus.denied => l10n.reminderPermissionDeniedHint,
      ReminderPermissionStatus.unsupported =>
        l10n.reminderPermissionUnsupportedHint,
      _ => l10n.reminderPermissionNotDeterminedHint,
    };

    return StyledCard(
      borderColor: accent.withValues(alpha: 0.22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TileIcon(
                  icon: _isPermissionUnsupported
                      ? Icons.notifications_paused_outlined
                      : Icons.notifications_off_outlined,
                  color: accent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.reminderPermissionTitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!_isPermissionUnsupported) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _requestingPermission ? null : _requestPermission,
                  icon: _requestingPermission
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          denied
                              ? Icons.open_in_new_rounded
                              : Icons.notifications_active_outlined,
                          size: 18,
                        ),
                  label: Text(
                    denied
                        ? l10n.reminderPermissionOpenSettings
                        : l10n.reminderPermissionRequest,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── 总开关 ──────────────────────────────────────────────────────

  Widget _buildMasterSwitch(AppLocalizations l10n) {
    return ValueListenableBuilder<bool>(
      valueListenable: _appConfig.reminderEnabled,
      builder: (context, enabled, _) => _ReminderSwitchTile(
        icon: enabled
            ? Icons.notifications_active_outlined
            : Icons.notifications_none_outlined,
        title: l10n.reminderMasterSwitch,
        subtitle: l10n.reminderMasterSwitchHint,
        value: enabled,
        onChanged: _toggleMaster,
      ),
    );
  }

  // ── 课前提醒 ────────────────────────────────────────────────────

  Widget _buildCourseSection(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ValueListenableBuilder<bool>(
      valueListenable: _appConfig.reminderEnabled,
      builder: (context, masterEnabled, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title: l10n.reminderCourseSection),
          AnimatedOpacity(
            duration: _animDuration,
            curve: appCurve,
            opacity: masterEnabled ? 1.0 : 0.45,
            child: IgnorePointer(
              ignoring: !masterEnabled,
              child: StyledCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const TileIcon(icon: Icons.alarm_outlined),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.reminderLeadTime,
                                  style: theme.textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.reminderLeadTimeHint,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: theme.dividerColor.withValues(alpha: 0.08),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ValueListenableBuilder<List<int>>(
                            valueListenable: _appConfig.reminderLeadMinutes,
                            builder: (context, selected, _) => Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final minutes in _leadChoices)
                                  _buildLeadChip(
                                    context: context,
                                    label: l10n.reminderLeadMinutes(minutes),
                                    isSelected: selected.contains(minutes),
                                    onTap: () {
                                      final next = {...selected};
                                      if (selected.contains(minutes)) {
                                        next.remove(minutes);
                                      } else {
                                        next.add(minutes);
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
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 15,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l10n.reminderLeadTimeMultiHint,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return FilterChip(
      label: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: isSelected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: colorScheme.primaryContainer,
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.45,
      ),
      side: BorderSide(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.35)
            : colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      onSelected: (_) => onTap(),
    );
  }

  // ── 免打扰 ──────────────────────────────────────────────────────

  Widget _buildQuietSection(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: _appConfig.reminderEnabled,
      builder: (context, masterEnabled, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title: l10n.reminderQuietSection),
          AnimatedOpacity(
            duration: _animDuration,
            curve: appCurve,
            opacity: masterEnabled ? 1.0 : 0.45,
            child: IgnorePointer(
              ignoring: !masterEnabled,
              child: StyledCard(
                child: ValueListenableBuilder<TimeOfDay?>(
                  valueListenable: _appConfig.reminderQuietStart,
                  builder: (context, start, _) =>
                      ValueListenableBuilder<TimeOfDay?>(
                        valueListenable: _appConfig.reminderQuietEnd,
                        builder: (context, end, _) {
                          final enabled = start != null && end != null;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ReminderSwitchTile(
                                icon: Icons.do_not_disturb_on_outlined,
                                title: l10n.reminderQuietEnabled,
                                subtitle: enabled
                                    ? '${_hhmm(start)} – ${_hhmm(end)}'
                                    : null,
                                value: enabled,
                                onChanged: (on) {
                                  if (on) {
                                    // 优先恢复历史时段；无历史记录时应用默认起止时段。
                                    final nextStart =
                                        _lastQuietStart ??
                                        const TimeOfDay(hour: 23, minute: 0);
                                    final nextEnd =
                                        _lastQuietEnd ??
                                        const TimeOfDay(hour: 7, minute: 0);
                                    _lastQuietStart = nextStart;
                                    _lastQuietEnd = nextEnd;
                                    _appConfig.reminderQuietStart.value =
                                        nextStart;
                                    _appConfig.reminderQuietEnd.value = nextEnd;
                                  } else {
                                    _lastQuietStart = start;
                                    _lastQuietEnd = end;
                                    _appConfig.reminderQuietStart.value = null;
                                    _appConfig.reminderQuietEnd.value = null;
                                  }
                                },
                              ),
                              ClipRect(
                                child: AnimatedSize(
                                  duration: _animDuration,
                                  curve: appCurve,
                                  alignment: Alignment.topCenter,
                                  child: enabled
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InfoCard.divider(
                                              theme,
                                              _tileDividerIndent,
                                            ),
                                            IconTile(
                                              icon: Icons.bedtime_outlined,
                                              label: l10n.reminderQuietStart,
                                              value: _hhmm(start),
                                              onTap: () =>
                                                  _pickQuietTime(isStart: true),
                                            ),
                                            InfoCard.divider(
                                              theme,
                                              _tileDividerIndent,
                                            ),
                                            IconTile(
                                              icon: Icons.wb_sunny_outlined,
                                              label: l10n.reminderQuietEnd,
                                              value: _hhmm(end),
                                              onTap: () => _pickQuietTime(
                                                isStart: false,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                ),
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
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title: l10n.reminderStatusSection),
        StyledCard(
          child: ValueListenableBuilder<ReminderPlan?>(
            valueListenable: _service.lastPlan,
            builder: (context, plan, _) {
              final hasReminders = plan != null && plan.reminders.isNotEmpty;
              final statusIcon = plan == null
                  ? Icons.schedule_outlined
                  : (hasReminders
                        ? Icons.event_available_outlined
                        : Icons.event_busy_outlined);
              final statusTitle = plan == null
                  ? l10n.reminderStatusEmpty
                  : (hasReminders
                        ? l10n.reminderStatusScheduled(
                            plan.reminders.length,
                            _formatMonthDayTime(plan.windowEnd),
                          )
                        : l10n.reminderStatusNoUpcoming);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TileIcon(
                          icon: statusIcon,
                          color: hasReminders
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusTitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_pendingCount != null && _isGranted) ...[
                                const SizedBox(height: 2),
                                Text(
                                  l10n.reminderStatusPending(_pendingCount!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          tooltip: l10n.reminderStatusRefresh,
                          onPressed: _refreshing ? null : _refreshPlan,
                          icon: _refreshing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  if (hasReminders) ...[
                    Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: theme.dividerColor.withValues(alpha: 0.08),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 8,
                        children: [
                          for (final item in plan.reminders.take(3))
                            _buildReminderPreviewRow(theme, item),
                        ],
                      ),
                    ),
                  ],
                  if (plan != null && plan.droppedCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: _buildInlineAlert(
                        theme: theme,
                        icon: Icons.warning_amber_rounded,
                        text: l10n.reminderStatusDropped(plan.droppedCount),
                      ),
                    ),
                  ValueListenableBuilder<String?>(
                    valueListenable: _service.lastError,
                    builder: (context, error, _) => error == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                            child: _buildInlineAlert(
                              theme: theme,
                              icon: Icons.error_outline_rounded,
                              text: l10n.reminderStatusError(error),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReminderPreviewRow(ThemeData theme, ReminderItem item) {
    final colorScheme = theme.colorScheme;
    final timeLabel = _formatMonthDayTime(item.fireAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppShapes.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppShapes.small),
            ),
            child: Text(
              timeLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    item.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineAlert({
    required ThemeData theme,
    required IconData icon,
    required String text,
  }) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppShapes.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 隐私提示 ────────────────────────────────────────────────────

  Widget _buildPrivacyHint(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 15,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.reminderPrivacyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 与 [IconTile] 保持完全一致的左内边距（20）、图标块（36×36）和间距（14），
/// 尾部承载 [AdaptiveGlassSwitch]，确保同一卡片内开关行与普通行像素级对齐。
class _ReminderSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ReminderSwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return BaseTile(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          TileIcon(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.textTheme.bodyLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          AdaptiveGlassSwitch(
            semanticLabel: title,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
