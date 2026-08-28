import 'package:bugaoshan/widgets/common/third_center.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/academic_calendar.dart';
import 'course_page_controller.dart';
import 'package:bugaoshan/theme_shape.dart';

class VacationView extends StatefulWidget {
  final CoursePageController controller;
  final void Function(AcademicCalendarSemester semester)? onViewNextSemester;

  const VacationView({
    super.key,
    required this.controller,
    this.onViewNextSemester,
  });

  @override
  State<VacationView> createState() => _VacationViewState();
}

class _VacationViewState extends State<VacationView> {
  @override
  void initState() {
    super.initState();
    // 触发 controller 懒加载校历，下学期数据由 controller 统一缓存
    widget.controller.ensureCalendarNextSemester();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final config = widget.controller.config;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final vacationStart = config.semesterEndDate.add(const Duration(days: 1));
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
              ListenableBuilder(
                listenable: Listenable.merge([
                  widget.controller.calendarNextSemester,
                  widget.controller.calendarNextSemesterLoading,
                ]),
                builder: (context, _) {
                  final loading =
                      widget.controller.calendarNextSemesterLoading.value;
                  final nextSemester =
                      widget.controller.calendarNextSemester.value;
                  if (loading) {
                    return const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  return _buildVacationContent(
                    l10n,
                    textTheme,
                    colorScheme,
                    today,
                    isOnVacation,
                    vacationStart,
                    nextSemester,
                  );
                },
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
    AcademicCalendarSemester? nextSemester,
  ) {
    if (isOnVacation && nextSemester == null) {
      return Text(
        l10n.enjoyVacation,
        style: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      );
    }

    final daysUntil = isOnVacation
        ? nextSemester!.startDate.difference(today).inDays
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
        if (nextSemester != null) ...[
          const SizedBox(height: 20),
          _buildNextSemesterInfo(l10n, textTheme, colorScheme, nextSemester),
        ],
      ],
    );
  }

  Widget _buildNextSemesterInfo(
    AppLocalizations l10n,
    TextTheme textTheme,
    ColorScheme colorScheme,
    AcademicCalendarSemester semester,
  ) {
    final regEvent = semester.registrationEvent;
    final hasSchedule = widget.controller.hasCalendarNextSemesterSchedule;

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
              onPressed: hasSchedule
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
