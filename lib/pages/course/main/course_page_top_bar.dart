import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/date_display_format.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/theme_shape.dart';

/// 切换课表菜单里「管理课表」项的哨兵值，不会与课表 id 冲突。
const _kScheduleManagementMenuValue = '__management__';

/// 顶栏操作按钮的边长（含点击区）。
///
/// IconButton 在 M3 下默认被 `MaterialTapTargetSize.padded` 撑到 48×48，`constraints`
/// 参数拦不住它 —— 4 个按钮要吃 192px，窄屏上会把「第 N 周」挤成「第 …」，320px 下
/// 甚至直接 RenderFlex 溢出。这里显式固定为紧凑尺寸（图标仍居中，热区 40×40）。
const double _kActionSize = 40;

/// 单行布局所需的最小宽度（会按文字缩放放大）。
///
/// 低于该宽度时改为「日期 + 操作按钮」一行、「周次导航」独占一行，
/// 保证「第 N 周」永远拿得到整行宽度，不再被省略号截断。
const double _kSingleRowMinWidth = 360;

class CoursePageTopBar extends StatelessWidget {
  final int visibleWeek;
  final int totalWeeks;
  final int actualWeek;
  final bool isViewingVacation;
  final bool isTodayOnVacation;
  final bool isNotStarted;
  final bool canGoPrevious;
  final bool canGoNext;
  final Duration animationDuration;

  final VoidCallback onPreviousWeek;
  final VoidCallback? onNextWeek;
  final VoidCallback onGoToCurrentWeek;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onAddCourse;

  /// 课表快捷切换：多于一份课表时在右侧按钮区最前显示弹窗菜单。
  final List<ScheduleConfig> schedules;
  final String? currentScheduleId;
  final ValueChanged<String> onSwitchSchedule;
  final VoidCallback onOpenScheduleManagement;

  /// 左上角日期的排列与分隔符，由调用方从全局设置解析后传入。
  final DateDisplayFormat dateFormat;

  const CoursePageTopBar({
    super.key,
    required this.visibleWeek,
    required this.totalWeeks,
    required this.actualWeek,
    this.isViewingVacation = false,
    this.isTodayOnVacation = false,
    this.isNotStarted = false,
    this.canGoPrevious = false,
    this.canGoNext = false,
    required this.animationDuration,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onGoToCurrentWeek,
    required this.onImport,
    required this.onExport,
    required this.onAddCourse,
    this.schedules = const [],
    this.currentScheduleId,
    required this.onSwitchSchedule,
    required this.onOpenScheduleManagement,
    this.dateFormat = const DateDisplayFormat(
      monthFirst: true,
      separator: '/',
    ),
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 大文字缩放时同样需要更多宽度：阈值随缩放放大，避免「第 N 周」被压缩。
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    final weekNav = _buildWeekNav(context, l10n);
    final actions = _buildActions(context, l10n);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 窄屏：日期与操作按钮同行，周次导航独占一行。
          final narrow = constraints.maxWidth < _kSingleRowMinWidth * textScale;
          final date = _buildDate(context);
          if (narrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: onGoToCurrentWeek,
                          child: date,
                        ),
                      ),
                    ),
                    actions,
                  ],
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: onGoToCurrentWeek,
                    child: weekNav,
                  ),
                ),
              ],
            );
          }

          // 宽屏：日期与周次导航在左侧上下排列，操作按钮居右。
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: onGoToCurrentWeek,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [date, const SizedBox(height: 1), weekNav],
                  ),
                ),
              ),
              actions,
            ],
          );
        },
      ),
    );
  }

  /// 左上角日期：完整日期（如 `2026/10/18`），排列与分隔符由全局设置决定。
  Widget _buildDate(BuildContext context) {
    final now = DateTime.now();
    return Text(
      dateFormat.formatFull(now),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  /// 「‹ 第 N 周 ›」+ 本周/未开学/放假徽章。
  Widget _buildWeekNav(BuildContext context, AppLocalizations l10n) {
    final isCurrentCalendarWeek = visibleWeek == actualWeek;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: canGoPrevious ? onPreviousWeek : null,
          child: Icon(
            Icons.chevron_left,
            size: 16,
            color: canGoPrevious
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).disabledColor,
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: AnimatedSize(
            duration: animationDuration,
            curve: appCurve,
            child: Text(
              isViewingVacation
                  ? l10n.onVacation
                  : l10n.currentWeek(visibleWeek),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        GestureDetector(
          onTap: canGoNext ? onNextWeek : null,
          child: Icon(
            Icons.chevron_right,
            size: 16,
            color: canGoNext
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).disabledColor,
          ),
        ),
        const SizedBox(width: 3),
        if (isNotStarted)
          // 未开学：主标签正常显示周数，旁边以徽章标注「未开学」。
          const _NotStartedBadge()
        else if (isTodayOnVacation)
          const _VacationBadge()
        else
          _WeekBadge(
            isCurrentCalendarWeek: isCurrentCalendarWeek,
            // 无放假页时学期过末 actualWeek 会超过 totalWeeks，
            // clamp 避免徽章显示越界周数。
            actualCurrentWeek: actualWeek.clamp(1, totalWeeks),
            animationDuration: animationDuration,
          ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, AppLocalizations l10n) {
    // 显式收掉 IconButton 默认的 48×48 padded 触控尺寸（见 _kActionSize 注释）。
    // style 的优先级高于 IconButton/PopupMenuButton 自身的同名参数。
    final actionStyle = IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      fixedSize: const Size.square(_kActionSize),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.standard,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (schedules.length > 1)
          PopupMenuButton<String>(
            icon: const Icon(Icons.swap_horiz, size: 20),
            tooltip: l10n.switchSchedule,
            style: actionStyle,
            onSelected: (id) {
              if (id == _kScheduleManagementMenuValue) {
                onOpenScheduleManagement();
              } else {
                onSwitchSchedule(id);
              }
            },
            itemBuilder: (context) => [
              ...schedules.map(
                (schedule) => PopupMenuItem<String>(
                  value: schedule.id,
                  child: Row(
                    children: [
                      if (schedule.id == currentScheduleId)
                        Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        )
                      else
                        const SizedBox(width: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          schedule.semesterName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: _kScheduleManagementMenuValue,
                child: Row(
                  children: [
                    // 缩进与上方课表项文字对齐（图标 20 + 间距 8）。
                    const SizedBox(width: 28),
                    Expanded(child: Text(l10n.scheduleManagement)),
                  ],
                ),
              ),
            ],
          ),
        IconButton(
          onPressed: onImport,
          icon: const Icon(Icons.download_rounded, size: 20),
          tooltip: l10n.importSchedule,
          style: actionStyle,
        ),
        IconButton(
          onPressed: onExport,
          icon: const Icon(Icons.share_rounded, size: 20),
          tooltip: l10n.exportSchedule,
          style: actionStyle,
        ),
        IconButton(
          onPressed: onAddCourse,
          icon: const Icon(Icons.add_circle_rounded, size: 24),
          tooltip: l10n.addCourse,
          style: actionStyle,
        ),
      ],
    );
  }
}

class _WeekBadge extends StatelessWidget {
  final bool isCurrentCalendarWeek;
  final int actualCurrentWeek;
  final Duration animationDuration;

  const _WeekBadge({
    required this.isCurrentCalendarWeek,
    required this.actualCurrentWeek,
    required this.animationDuration,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isCurrent = isCurrentCalendarWeek;
    final text = isCurrent
        ? l10n.thisWeek
        : l10n.actualCurrentWeek(actualCurrentWeek);

    final textWidget = Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: isCurrent
            ? scheme.onPrimaryContainer
            : scheme.onSecondaryContainer,
        fontWeight: FontWeight.w600,
        fontSize: 9,
      ),
    );

    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: isCurrent ? scheme.primaryContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppShapes.full),
      ),
      child: AnimatedSize(
        duration: animationDuration,
        curve: appCurve,
        child: textWidget,
      ),
    );
    return body;
  }
}

class _NotStartedBadge extends StatelessWidget {
  const _NotStartedBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppShapes.full),
      ),
      child: Text(
        l10n.notStarted,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _VacationBadge extends StatelessWidget {
  const _VacationBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppShapes.full),
      ),
      child: Text(
        l10n.vacationBadge,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onTertiaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: 9,
        ),
      ),
    );
  }
}
