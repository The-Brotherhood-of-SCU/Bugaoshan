part of 'course_page.dart';

class _TopBar extends StatelessWidget {
  final int week;
  final int totalWeeks;
  final int visibleWeek;
  final bool isViewingVacation;
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
    final isCurrentCalendarWeek = visibleWeek == config.getCurrentWeek();

    final now = DateTime.now();
    final dateStr = '${now.year}/${now.month}/${now.day}';
    final canGoLeft = isViewingVacation || week > 1;
    final canGoRight = !isViewingVacation && week <= totalWeeks;

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
                    SizedBox(
                      width: isViewingVacation ? 80 : 60,
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
                    if (isViewingVacation)
                      _VacationBadge()
                    else
                      _WeekBadge(
                        isCurrentCalendarWeek: isCurrentCalendarWeek,
                        actualCurrentWeek: config.getCurrentWeek(),
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
