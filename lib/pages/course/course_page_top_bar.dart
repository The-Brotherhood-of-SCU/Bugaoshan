part of 'course_page.dart';

class _TopBar extends StatelessWidget {
  final int week;
  final int totalWeeks;
  final int visibleWeek;
  final bool isViewingVacation;

  /// 放假页是否存在（与 _CoursePageState._showVacationPage 同源）。
  /// 徽章和右箭头都以它为准，避免「显示假期中却无放假页可翻」的脱节。
  final bool hasVacationPage;
  final VoidCallback onPreviousWeek;
  final VoidCallback? onNextWeek;
  final VoidCallback onGoToCurrentWeek;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onAddCourse;

  const _TopBar({
    required this.week,
    required this.totalWeeks,
    required this.visibleWeek,
    this.isViewingVacation = false,
    this.hasVacationPage = false,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onGoToCurrentWeek,
    required this.onImport,
    required this.onExport,
    required this.onAddCourse,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = getIt<CourseProvider>().scheduleConfig.value;
    final actualWeek = config.getCurrentWeek();
    final isCurrentCalendarWeek = visibleWeek == actualWeek;
    // 与放假页共用同一判定：没有放假页时不显示「假期中」徽章，
    // 避免徽章提示假期但右箭头无处可去。
    final isInVacation = hasVacationPage && actualWeek > config.totalWeeks;

    final now = DateTime.now();
    final dateStr = '${now.year}/${now.month}/${now.day}';
    final canGoLeft = isViewingVacation || week > 1;
    // 最后一周时只有存在放假页才能继续往右翻。
    final canGoRight =
        !isViewingVacation && (week < totalWeeks || hasVacationPage);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onGoToCurrentWeek,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dateStr,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: canGoLeft ? onPreviousWeek : null,
                      child: Icon(
                        Icons.chevron_left,
                        size: 16,
                        color: canGoLeft
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).disabledColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    AnimatedSize(
                      duration:
                          appConfigService.cardSizeAnimationDuration.value,
                      curve: appCurve,
                      child: Text(
                        isViewingVacation
                            ? l10n.onVacation
                            : l10n.currentWeek(week),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: canGoRight ? onNextWeek : null,
                      child: Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: canGoRight
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).disabledColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    if (isInVacation)
                      _VacationBadge()
                    else
                      _WeekBadge(
                        isCurrentCalendarWeek: isCurrentCalendarWeek,
                        // 无放假页时学期过末 actualWeek 会超过 totalWeeks，
                        // clamp 避免徽章显示越界周数。
                        actualCurrentWeek: actualWeek.clamp(
                          1,
                          config.totalWeeks,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onImport,
                icon: const Icon(Icons.download_rounded, size: 20),
                tooltip: l10n.importSchedule,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                onPressed: onExport,
                icon: const Icon(Icons.share_rounded, size: 20),
                tooltip: l10n.exportSchedule,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                onPressed: onAddCourse,
                icon: const Icon(Icons.add_circle_rounded, size: 24),
                tooltip: l10n.addCourse,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekBadge extends StatelessWidget {
  final bool isCurrentCalendarWeek;
  final int actualCurrentWeek;

  const _WeekBadge({
    required this.isCurrentCalendarWeek,
    required this.actualCurrentWeek,
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
        duration: appConfigService.cardSizeAnimationDuration.value,
        curve: appCurve,
        child: textWidget,
      ),
    );
    return body;
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
