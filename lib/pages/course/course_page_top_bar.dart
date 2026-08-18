part of 'course_page.dart';

class _TopBar extends StatelessWidget {
  final int visibleWeek;
  final int totalWeeks;
  final int actualWeek;
  final bool isViewingVacation;
  final bool isTodayOnVacation;
  final bool isNotStarted;
  final bool canGoPrevious;
  final bool canGoNext;

  final VoidCallback onPreviousWeek;
  final VoidCallback? onNextWeek;
  final VoidCallback onGoToCurrentWeek;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onAddCourse;

  const _TopBar({
    required this.visibleWeek,
    required this.totalWeeks,
    required this.actualWeek,
    this.isViewingVacation = false,
    this.isTodayOnVacation = false,
    this.isNotStarted = false,
    this.canGoPrevious = false,
    this.canGoNext = false,
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
    final isCurrentCalendarWeek = visibleWeek == actualWeek;

    final now = DateTime.now();
    final dateStr = '${now.year}/${now.month}/${now.day}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: GestureDetector(
              onTap: onGoToCurrentWeek,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
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
                          duration:
                              appConfigService.cardSizeAnimationDuration.value,
                          curve: appCurve,
                          child: Text(
                            isViewingVacation
                                ? l10n.onVacation
                                : isNotStarted
                                ? l10n.notStarted
                                : l10n.currentWeek(visibleWeek),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                        // 未开学：没有「当前周」概念，不显示本周徽章。
                        const SizedBox.shrink()
                      else if (isTodayOnVacation)
                        const _VacationBadge()
                      else
                        _WeekBadge(
                          isCurrentCalendarWeek: isCurrentCalendarWeek,
                          // 无放假页时学期过末 actualWeek 会超过 totalWeeks，
                          // clamp 避免徽章显示越界周数。
                          actualCurrentWeek: actualWeek.clamp(1, totalWeeks),
                        ),
                    ],
                  ),
                ],
              ),
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
