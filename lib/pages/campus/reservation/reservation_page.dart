import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/scu_backend/reservation/models/reservation_models.dart';
import 'package:bugaoshan/pages/auth/scu_login_page.dart';
import 'package:bugaoshan/providers/reservation_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/scu_backend/core/scu_auth.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/open_link.dart';
import 'package:bugaoshan/utils/system_insets.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';

/// 望江校区研究生活动室预约。
///
/// 展示专题 [kReservationTopicId] 下的活动室与选中活动室未来若干天的时段
/// 占用，支持**在应用内点选时段直接提交预约**（`site/resource/launch`）。
///
/// 已知边界：需要审批的活动室提交后仍要在预约系统完成申请流程（上传申请
/// 表等，30 分钟内），提交成功且返回流程地址时本页会引导跳转；若资源开启
/// 短信/滑块验证（`anti_bot`），应用内的直约会被服务端拒绝，届时以服务端
/// 返回的原文提示，仍可走底部「去官方页面预约」。
class ReservationPage extends StatefulWidget {
  const ReservationPage({super.key});

  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage>
    with WidgetsBindingObserver {
  static const String _tag = 'ReservationPage';

  late final ReservationProvider _provider;
  late final ScuAuthProvider _auth;
  final ScrollController _resourceScrollController = ScrollController();

  /// 活动室标签条当前能否继续向左右滚动（用于箭头置灰）。
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _recoveringSession = false;

  /// 待提交的已选时段：日期 -> 该日选中的时段 id 集合。
  ///
  /// 页面本地状态：切换活动室 / 翻日期区间 / 提交成功后清空。
  final Map<String, Set<String>> _selectedSlots = {};

  /// 提交请求进行中（防重复提交）。
  bool _launching = false;

  /// 已选时段总数。
  int get _selectedCount =>
      _selectedSlots.values.fold(0, (sum, ids) => sum + ids.length);

  void _clearSelection() {
    // 提交等异步路径会在 await 后调用；页面可能已随弹窗关闭而 dispose。
    if (!mounted || _selectedSlots.isEmpty) return;
    setState(_selectedSlots.clear);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = getIt<ReservationProvider>();
    _auth = getIt<ScuAuthProvider>();
    _auth.addListener(_onAuthChanged);
    _resourceScrollController.addListener(_updateResourceScrollState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onAuthChanged();
      _syncScrollStateAfterLayout();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_onAuthChanged);
    _resourceScrollController.removeListener(_updateResourceScrollState);
    _resourceScrollController.dispose();
    super.dispose();
  }

  /// 同步箭头可用状态。只在边界状态变化时 setState，滚动过程中不反复重建。
  void _updateResourceScrollState() {
    final controller = _resourceScrollController;
    if (!controller.hasClients) return;
    final position = controller.position;
    final canLeft = position.pixels > position.minScrollExtent + 0.5;
    final canRight = position.pixels < position.maxScrollExtent - 0.5;
    if (canLeft == _canScrollLeft && canRight == _canScrollRight) return;
    setState(() {
      _canScrollLeft = canLeft;
      _canScrollRight = canRight;
    });
  }

  /// 标签条首帧进树后同步一次箭头状态。
  ///
  /// 资源还在加载时标签条不在树上（hasClients 为 false），推迟到下一帧重试，
  /// 直到挂载为止；挂载后的滚动变化由 controller 的 listener 覆盖。
  void _syncScrollStateAfterLayout() {
    if (!mounted) return;
    if (_resourceScrollController.hasClients) {
      _updateResourceScrollState();
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _syncScrollStateAfterLayout(),
      );
    }
  }

  /// 页面跨夜挂着再回到前台时，把区间夹回今天，避免继续展示昨天的日历。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _provider.ensureRangeNotPast();
    }
  }

  void _onAuthChanged() {
    final auth = getIt<ScuAuthProvider>();
    if (auth.isLoggedIn) {
      _provider.ensureLoaded();
    } else if (!auth.isAutoLoggingIn &&
        !_recoveringSession &&
        auth.accessToken != null) {
      _recoverSession();
    }
  }

  Future<void> _recoverSession() async {
    setState(() => _recoveringSession = true);
    try {
      await getIt<ScuAuth>().refresh();
    } catch (e, logStackTrace) {
      AppLog.e(_tag, '_recoverSession 失败', error: e, stackTrace: logStackTrace);
    } finally {
      if (mounted) setState(() => _recoveringSession = false);
    }
  }

  void _openLoginPage() {
    popupOrNavigate(context, const ScuLoginPage());
  }

  Future<void> _openOfficialPage() async {
    await openLink(kReservationSpecialPageUrl);
  }

  /// 已选时段展开为提交用的（日期, 时段 id）列表，按日期、时段顺序。
  List<ReservationLaunchSlot> _flattenSelection() {
    final slots = <ReservationLaunchSlot>[];
    for (final day in _selectedSlots.keys) {
      for (final periodId in _selectedSlots[day]!) {
        slots.add(ReservationLaunchSlot(date: day, periodId: periodId));
      }
    }
    return slots;
  }

  /// 弹出确认框（含人数），确认后提交预约。
  Future<void> _openLaunchConfirm() async {
    final l10n = AppLocalizations.of(context)!;
    final resource = _provider.selectedResource;
    final slots = _flattenSelection();
    if (resource == null || slots.isEmpty) return;

    final number = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        var people = 1;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(l10n.reservationLaunchConfirmTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppShapes.small),
                  Wrap(
                    spacing: AppShapes.small,
                    runSpacing: AppShapes.xs,
                    children: [
                      for (final slot in slots)
                        _InfoChip(label: _slotLabelText(slot)),
                    ],
                  ),
                  const SizedBox(height: AppShapes.large),
                  Row(
                    children: [
                      Text(
                        l10n.reservationPeopleNumber,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: people > 1
                            ? () => setDialogState(() => people--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$people',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      // 容量未提供（null）时不设上限。
                      IconButton(
                        onPressed:
                            resource.capacity == null ||
                                people < resource.capacity!
                            ? () => setDialogState(() => people++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(people),
                  child: Text(l10n.reservationLaunchSubmit),
                ),
              ],
            );
          },
        );
      },
    );
    if (number == null || number < 1 || !mounted) return;
    await _launch(slots: slots, number: number);
  }

  String _slotLabelText(ReservationLaunchSlot slot) =>
      '${_dayLabel(slot.date)} ${_slotLabelOf(slot.periodId)}';

  /// 时段 id → 「08:00-12:00」标签；找不到（罕见）退回 id 本身。
  String _slotLabelOf(String periodId) {
    final calendar = _provider.calendar;
    if (calendar != null) {
      for (final slot in calendar.slots) {
        if (slot.id == periodId) return slot.label;
      }
    }
    return periodId;
  }

  /// 提交预约并按结果反馈；成功后清空选择（日历由 provider 刷新）。
  ///
  /// 状态复位（`_launching`）先于结果弹窗：结果弹窗要等用户关闭才返回，
  /// 若在 await 之后才复位，提交条上的转圈会一直转（pumpAndSettle 也过不去）。
  Future<void> _launch({
    required List<ReservationLaunchSlot> slots,
    required int number,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _launching = true);

    ReservationLaunchResult? result;
    ScuException? failure;
    try {
      result = await _provider.launchReservation(slots: slots, number: number);
      _clearSelection();
    } on ReservationApplyPendingException catch (e) {
      // 已有未提交预约单：本次选择作废。
      _clearSelection();
      failure = e;
    } on UnauthenticatedException catch (e) {
      _clearSelection();
      failure = e;
    } on ServiceException catch (e) {
      // 服务端拒绝（如缺申请表字段）：保留选择便于修改后重试。
      failure = e;
    } catch (e, logStackTrace) {
      // 未知异常（网络中断等）：不带 message，让展示层落到 l10n 兜底文案。
      AppLog.e(_tag, 'launch 失败', error: e, stackTrace: logStackTrace);
    } finally {
      if (mounted) setState(() => _launching = false);
    }
    if (!mounted) return;

    if (result != null) {
      if (result.needsProcess) {
        // 需审批的资源：单已创建，还要去流程页完成申请（上传申请表等）。
        final openProcess = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.reservationLaunchProcessTitle),
            content: Text(l10n.reservationLaunchProcessBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.reservationOpenProcess),
              ),
            ],
          ),
        );
        if (openProcess == true && mounted) {
          // 服务端偶尔只回 is_relate 不带 process_url：降级到官方专题页
          // （「我的预约」里有申请入口），不能当成「预约成功」。
          await openLink(
            result.processUrl.isNotEmpty
                ? result.processUrl
                : kReservationSpecialPageUrl,
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.reservationLaunchSuccess)));
      }
      return;
    }

    if (failure is ReservationApplyPendingException) {
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.reservationApplyPendingTitle),
          content: Text(l10n.reservationApplyPendingBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _openOfficialPage();
              },
              child: Text(l10n.reservationGoOfficial),
            ),
          ],
        ),
      );
      return;
    }

    final message = failure?.message ?? l10n.reservationLaunchFailedGeneric;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── 我的预约 ─────────────────────────────────────────────────────────────

  Future<void> _openMyAppointments() async {
    // 失败在 provider 内转 appointmentsError 状态，不会成为未捕获异常。
    unawaited(_provider.loadAppointments());
    await showDialog(
      context: context,
      builder: (dialogContext) => _MyAppointmentsDialog(provider: _provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: Listenable.merge([_provider, getIt<ScuAuthProvider>()]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(l10n.reservationTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.close,
            onPressed: () => popDialog(),
          ),
          actions: [
            if (getIt<ScuAuthProvider>().isLoggedIn &&
                _provider.state != ReservationLoadState.loading) ...[
              IconButton(
                tooltip: l10n.reservationMyAppointments,
                onPressed: _openMyAppointments,
                icon: const Icon(Icons.event_note_outlined),
              ),
              IconButton(
                tooltip: l10n.refresh,
                onPressed: () {
                  _clearSelection();
                  _provider.refresh();
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ],
        ),
        body: _buildBody(l10n),
        bottomNavigationBar: _buildBottomBar(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final auth = getIt<ScuAuthProvider>();

    if (!auth.isLoggedIn) {
      return auth.isAutoLoggingIn || _recoveringSession
          ? const AutoLoginLoadingWidget()
          : const LoginRequiredWidget();
    }

    if (_provider.state == ReservationLoadState.loading &&
        _provider.calendar == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_provider.errorKind == ReservationErrorKind.unauthenticated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.reservationSessionExpired,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _openLoginPage,
                icon: const Icon(Icons.login),
                label: Text(l10n.goToLogin),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  _clearSelection();
                  _provider.refresh();
                },
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_provider.errorKind != null) {
      return RetryableErrorWidget.message(
        message: _provider.errorMessage ?? l10n.loadFailed,
        onRetry: () {
          _clearSelection();
          _provider.refresh();
        },
      );
    }

    if (_provider.resources.isEmpty) {
      return Center(
        child: Text(
          l10n.reservationNoResources,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return RefreshIndicator(
      // 刷新后日历可能已是别人约走的状态，已选时段必须一并清掉。
      onRefresh: () async {
        _clearSelection();
        await _provider.refresh();
      },
      child: ListView(
        padding: withSystemBottomInset(
          context,
          const EdgeInsets.all(AppShapes.large),
        ),
        children: [
          _buildResourcePicker(l10n),
          const SizedBox(height: AppShapes.large),
          _buildCalendar(l10n),
        ],
      ),
    );
  }

  /// 资源选择：横向滚动的胶囊，两侧带翻页箭头。
  ///
  /// 桌面端只靠滚轮或拖拽不好发现「右边还有活动室」，所以显式给左右箭头，
  /// 并按滚动位置禁用（到头了就不再可点）。
  Widget _buildResourcePicker(AppLocalizations l10n) {
    final controller = _resourceScrollController;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.reservationChooseRoom,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppShapes.small),
        Row(
          children: [
            _ScrollArrow(
              icon: Icons.chevron_left,
              tooltip: l10n.reservationScrollLeft,
              enabled: _canScrollLeft,
              onPressed: () => _scrollResources(-1),
            ),
            Expanded(
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  itemCount: _provider.resources.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppShapes.small),
                  itemBuilder: (context, index) {
                    final resource = _provider.resources[index];
                    final selected =
                        resource.id == _provider.selectedResourceId;
                    return ChoiceChip(
                      label: Text(resource.name),
                      selected: selected,
                      onSelected: (_) {
                        _clearSelection();
                        _provider.selectResource(resource.id);
                      },
                    );
                  },
                ),
              ),
            ),
            _ScrollArrow(
              icon: Icons.chevron_right,
              tooltip: l10n.reservationScrollRight,
              enabled: _canScrollRight,
              onPressed: () => _scrollResources(1),
            ),
          ],
        ),
      ],
    );
  }

  /// 按一屏宽度翻页；到达两端时箭头置灰。
  void _scrollResources(int direction) {
    final controller = _resourceScrollController;
    if (!controller.hasClients) return;
    final position = controller.position;
    final page = position.viewportDimension * 0.8;
    final target = (position.pixels + direction * page).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildCalendar(AppLocalizations l10n) {
    final calendar = _provider.calendar;
    final resource = _provider.selectedResource;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (resource != null) ...[
          _buildResourceInfo(resource, l10n),
          const SizedBox(height: AppShapes.large),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.reservationAvailability,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            // 翻走之后给一条回到今天的捷径；已经在今天这一屏时禁用。
            TextButton(
              onPressed: _provider.isAtTodayRange
                  ? null
                  : () {
                      _clearSelection();
                      _provider.resetRange();
                    },
              child: Text(l10n.reservationBackToToday),
            ),
            IconButton(
              tooltip: l10n.reservationPreviousWeek,
              onPressed: _provider.isAtTodayRange
                  ? null
                  : () {
                      _clearSelection();
                      _provider.shiftRange(-ReservationProvider.visibleDays);
                    },
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: l10n.reservationNextWeek,
              onPressed: () {
                _clearSelection();
                _provider.shiftRange(ReservationProvider.visibleDays);
              },
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: AppShapes.small),
        if (calendar == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (calendar.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                l10n.reservationNoSlots,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          _buildCalendarGrid(calendar, l10n),
        const SizedBox(height: AppShapes.large),
        _buildLegend(l10n),
      ],
    );
  }

  Widget _buildResourceInfo(
    ReservationResource resource,
    AppLocalizations l10n,
  ) {
    return StyledCard(
      padding: const EdgeInsets.all(AppShapes.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resource.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (resource.attributes.isNotEmpty) ...[
            const SizedBox(height: AppShapes.small),
            Wrap(
              spacing: AppShapes.small,
              runSpacing: AppShapes.xs,
              children: [
                for (final attribute in resource.attributes)
                  Text(
                    '${attribute.name}：${attribute.value}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppShapes.small),
          Wrap(
            spacing: AppShapes.small,
            runSpacing: AppShapes.xs,
            children: [
              if (resource.needsApproval)
                _InfoChip(label: l10n.reservationNeedsApproval),
              if (resource.maxPeriodsPerDay > 0)
                _InfoChip(
                  label: l10n.reservationDailyLimit(resource.maxPeriodsPerDay),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 日期 × 时段的网格：行为时段，列为日期。
  ///
  /// 时段列固定在左侧，只有日期列横向滚动——否则横滑后连「几点到几点」
  /// 都被滚走，用户不知道看的是哪一行。
  ///
  /// 不用 `DataTable`：它在横屏 / 小高度弹窗里会被父级压扁（实测行高
  /// 只剩 11px），`dataRowMinHeight` 也兜不住。这里用手工 Row/Column
  /// 布局，行高由 `SizedBox` 写死，超出部分交给外层 ListView 滚动。
  Widget _buildCalendarGrid(
    ReservationCalendar calendar,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    const headingHeight = 44.0;
    const rowHeight = 48.0;
    const dayWidth = 72.0;
    final gridHeight = headingHeight + calendar.slots.length * rowHeight;

    return SizedBox(
      height: gridHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 固定列：时段
          SizedBox(
            width: 108,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: headingHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.reservationTimeColumn,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
                for (final slot in calendar.slots)
                  SizedBox(
                    height: rowHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(slot.label, style: textStyle),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: gridHeight,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          // 可滚动列：日期
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: headingHeight,
                    child: Row(
                      children: [
                        for (final day in calendar.days)
                          SizedBox(
                            width: dayWidth,
                            child: Center(
                              child: Text(
                                _dayLabel(day),
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final slot in calendar.slots)
                    SizedBox(
                      height: rowHeight,
                      child: Row(
                        children: [
                          for (final day in calendar.days)
                            SizedBox(
                              width: dayWidth,
                              child: Center(
                                child: _SlotCell(
                                  state: calendar.stateOf(day, slot.id),
                                  selected:
                                      _selectedSlots[day]?.contains(slot.id) ??
                                      false,
                                  onTap: () => _onSlotTap(day, slot, calendar),
                                ),
                              ),
                            ),
                        ],
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

  void _onSlotTap(
    String day,
    ReservationTimeSlot slot,
    ReservationCalendar calendar,
  ) {
    final state = calendar.stateOf(day, slot.id);
    if (!state.bookable) return;

    final daySelection = _selectedSlots.putIfAbsent(day, () => <String>{});
    if (daySelection.contains(slot.id)) {
      setState(() => daySelection.remove(slot.id));
      if (daySelection.isEmpty) _selectedSlots.remove(day);
      return;
    }

    // 每日时段上限（资源 config 的 ResourceUseDayTimesRule，0 = 不限）。
    final resource = _provider.selectedResource;
    final maxPerDay = resource?.maxPeriodsPerDay ?? 0;
    if (maxPerDay > 0 && daySelection.length >= maxPerDay) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reservationDailyLimitReached(maxPerDay))),
      );
      return;
    }
    setState(() => daySelection.add(slot.id));
  }

  Widget _buildLegend(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppShapes.large,
      runSpacing: AppShapes.small,
      children: [
        _LegendDot(
          color: _slotStatusColor(scheme, ReservationSlotStatus.available),
          label: l10n.reservationStatusAvailable,
        ),
        _LegendDot(
          color: _slotStatusColor(scheme, ReservationSlotStatus.full),
          label: l10n.reservationStatusFull,
        ),
        _LegendDot(
          color: _slotStatusColor(scheme, ReservationSlotStatus.notOpen),
          label: l10n.reservationStatusUnavailable,
        ),
      ],
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    if (!getIt<ScuAuthProvider>().isLoggedIn) return const SizedBox.shrink();

    final selectedCount = _selectedCount;
    if (selectedCount > 0) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppShapes.large,
            AppShapes.small,
            AppShapes.large,
            AppShapes.small,
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _launching ? null : _openLaunchConfirm,
                  icon: _launching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_available),
                  label: Text(l10n.reservationLaunchButton),
                ),
              ),
              const SizedBox(width: AppShapes.small),
              IconButton(
                tooltip: l10n.reservationClearSelection,
                onPressed: _launching ? null : _clearSelection,
                icon: const Icon(Icons.clear_all),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppShapes.large,
          AppShapes.small,
          AppShapes.large,
          AppShapes.small,
        ),
        child: OutlinedButton.icon(
          onPressed: _openOfficialPage,
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.reservationGoOfficial),
        ),
      ),
    );
  }

  static String _dayLabel(String day) {
    // `YYYY-MM-DD` → `M/D`，保持表头紧凑。
    final parts = day.split('-');
    if (parts.length != 3) return day;
    final month = int.tryParse(parts[1]);
    final date = int.tryParse(parts[2]);
    if (month == null || date == null) return day;
    return '$month/$date';
  }
}

/// 时段状态 → 展示色。图例与格子共用同一套取色，避免「图例一个色、
/// 格子另一个色」对不上号。
Color _slotStatusColor(ColorScheme scheme, ReservationSlotStatus status) =>
    switch (status) {
      ReservationSlotStatus.available => scheme.primary,
      ReservationSlotStatus.full => scheme.error,
      ReservationSlotStatus.notOpen ||
      ReservationSlotStatus.expired ||
      ReservationSlotStatus.disabled => scheme.onSurfaceVariant,
    };

/// 单元格：可约显示剩余数（可点选），约满显示「满」，其余显示「—」。
class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.state,
    required this.onTap,
    this.selected = false,
  });

  final ReservationSlotState state;
  final VoidCallback onTap;

  /// 已被选中待提交（仅可约格子会出现）。
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (state.bookable) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppShapes.small),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppShapes.small,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primaryContainer.withValues(alpha: 0.55)
                    : null,
                borderRadius: BorderRadius.circular(AppShapes.small),
                border: selected
                    ? Border.all(color: scheme.primary, width: 1.6)
                    : null,
              ),
              child: Text(
                l10n.reservationRemaining(state.remaining),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _slotStatusColor(
                    scheme,
                    ReservationSlotStatus.available,
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: 10, color: scheme.onPrimary),
                ),
              ),
          ],
        ),
      );
    }

    final text = switch (state.status) {
      ReservationSlotStatus.full => l10n.reservationStatusFull,
      ReservationSlotStatus.notOpen => l10n.reservationStatusUnavailable,
      ReservationSlotStatus.expired => l10n.reservationStatusUnavailable,
      ReservationSlotStatus.disabled => l10n.reservationStatusUnavailable,
      ReservationSlotStatus.available => l10n.reservationStatusUnavailable,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppShapes.small,
        vertical: 4,
      ),
      child: Text(
        text,
        style: TextStyle(color: _slotStatusColor(scheme, state.status)),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppShapes.small,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppShapes.small),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}

/// 「我的预约」弹窗：列出全部预约单（资源、状态、时段明细），可取消
/// `is_cancel == 1` 的单（整单取消，传全部明细 id）。
class _MyAppointmentsDialog extends StatelessWidget {
  const _MyAppointmentsDialog({required this.provider});

  final ReservationProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.reservationMyAppointments)),
          IconButton(
            tooltip: l10n.refresh,
            onPressed: provider.appointmentsLoading
                ? null
                : () => provider.loadAppointments(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      content: ConstrainedBox(
        // 手机窄屏随弹窗收缩，桌面宽屏封顶 420。内层 maxFinite 占满可用宽，
        // 避免 AlertDialog 对 shrinkWrap 列表做 intrinsic 测量。
        constraints: const BoxConstraints(maxWidth: 420),
        child: SizedBox(
          width: double.maxFinite,
          child: ListenableBuilder(
            listenable: provider,
            builder: (context, _) {
              if (provider.appointmentsLoading &&
                  provider.appointments.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              final error = provider.appointmentsError;
              if (error != null && provider.appointments.isEmpty) {
                // 拉取失败 ≠ 没有预约：明确给出错误文案，标题行的刷新即重试。
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    error.isNotEmpty
                        ? error
                        : l10n.reservationMyAppointmentsError,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: scheme.error),
                  ),
                );
              }
              final items = provider.appointments;
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l10n.reservationMyAppointmentsEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppShapes.small),
                  itemBuilder: (context, index) {
                    final appointment = items[index];
                    return _AppointmentTile(
                      appointment: appointment,
                      provider: provider,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

/// 单张预约单的行：资源名 + 状态标签 + 时段明细 + 取消按钮。
class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment, required this.provider});

  final ReservationAppointment appointment;
  final ReservationProvider provider;

  String _statusText(AppLocalizations l10n) => switch (appointment.status) {
    0 => l10n.reservationStatusPendingApply,
    1 || 2 => l10n.reservationStatusReviewing,
    3 => l10n.reservationStatusBooked,
    4 => l10n.reservationStatusCheckInPending,
    _ => l10n.reservationStatusClosed,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppShapes.small),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(AppShapes.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  appointment.resourceName,
                  style: textTheme.titleSmall,
                ),
              ),
              _InfoChip(label: _statusText(l10n)),
            ],
          ),
          if (appointment.details.isNotEmpty) ...[
            const SizedBox(height: AppShapes.xs),
            Wrap(
              spacing: AppShapes.small,
              runSpacing: AppShapes.xs,
              children: [
                for (final detail in appointment.details)
                  Text(
                    detail.label,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
          if (appointment.createdAt.isNotEmpty) ...[
            const SizedBox(height: AppShapes.xs),
            Text(
              appointment.createdAt,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (appointment.canCancel)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _confirmCancel(context, l10n),
                child: Text(l10n.reservationCancel),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.reservationCancel),
        content: Text(l10n.reservationCancelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.reservationCancel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await provider.cancelAppointment(appointment);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.reservationCancelSuccess)),
      );
    } on ServiceException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.reservationLaunchFailedGeneric)),
      );
    }
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// 活动室标签条两侧的翻页箭头，到达两端时置灰。
class _ScrollArrow extends StatelessWidget {
  const _ScrollArrow({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }
}
