part of 'course_page.dart';

class _VacationView extends StatefulWidget {
  final ScheduleConfig scheduleConfig;
  final List<ScheduleConfig> allSchedules;
  final void Function(AcademicCalendarSemester semester)? onViewNextSemester;

  const _VacationView({
    required this.scheduleConfig,
    required this.allSchedules,
    this.onViewNextSemester,
  });

  @override
  State<_VacationView> createState() => _VacationViewState();
}

class _VacationViewState extends State<_VacationView> {
  AcademicCalendarSemester? _nextSemester;
  bool _loading = true;
  bool _hasNextSemesterSchedule = false;

  @override
  void initState() {
    super.initState();
    _loadNextSemester();
  }

  Future<void> _loadNextSemester() async {
    try {
      final data = await AcademicCalendarService.loadBundledCalendar();
      if (mounted) {
        final next = data.findNextSemester(
          widget.scheduleConfig.semesterEndDate,
        );
        setState(() {
          _nextSemester = next;
          _hasNextSemesterSchedule =
              next != null &&
              next.findMatchingScheduleId(widget.allSchedules) != null;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('VacationView: failed to load next semester data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final vacationStart = widget.scheduleConfig.semesterEndDate.add(
      const Duration(days: 1),
    );
    final isOnVacation = !today.isBefore(vacationStart);

    return ThirdCenter(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.onVacation,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (_loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                _buildVacationContent(
                  l10n,
                  textTheme,
                  colorScheme,
                  today,
                  isOnVacation,
                  vacationStart,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVacationContent(
    AppLocalizations l10n,
    TextTheme textTheme,
    ColorScheme colorScheme,
    DateTime today,
    bool isOnVacation,
    DateTime vacationStart,
  ) {
    if (isOnVacation && _nextSemester == null) {
      return Text(
        l10n.enjoyVacation,
        style: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      );
    }

    final daysUntil = isOnVacation
        ? _nextSemester!.startDate.difference(today).inDays
        : vacationStart.difference(today).inDays;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isOnVacation
              ? l10n.daysUntilNextSemester(daysUntil)
              : l10n.daysUntilVacation(daysUntil),
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        if (_nextSemester != null) ...[
          const SizedBox(height: 20),
          _buildNextSemesterInfo(l10n, textTheme, colorScheme),
        ],
      ],
    );
  }

  Widget _buildNextSemesterInfo(
    AppLocalizations l10n,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final semester = _nextSemester!;
    final regEvent = semester.registrationEvent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppShapes.medium),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.nextSemester,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            semester.name,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          if (regEvent != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.registrationDates(
                '${regEvent.date.month}/${regEvent.date.day}',
                regEvent.endDate != null
                    ? '${regEvent.endDate!.month}/${regEvent.endDate!.day}'
                    : '${regEvent.date.month}/${regEvent.date.day}',
              ),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (widget.onViewNextSemester != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _hasNextSemesterSchedule
                  ? () => widget.onViewNextSemester!(semester)
                  : null,
              child: Text(l10n.viewNextSemesterSchedule),
            ),
          ],
        ],
      ),
    );
  }
}
