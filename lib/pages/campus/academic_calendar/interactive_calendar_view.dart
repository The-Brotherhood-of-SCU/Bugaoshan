import 'package:flutter/material.dart';
import 'package:bugaoshan/utils/app_shapes.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:intl/intl.dart';

import 'package:bugaoshan/models/academic_calendar.dart';

class InteractiveCalendarView extends StatelessWidget {
  final AcademicCalendarData? data;
  final AcademicCalendarSemester? selectedSemester;
  final bool loading;
  final String? error;
  final ValueChanged<AcademicCalendarSemester> onSemesterChanged;
  final VoidCallback onRetry;

  const InteractiveCalendarView({
    super.key,
    this.data,
    this.selectedSemester,
    required this.loading,
    this.error,
    required this.onSemesterChanged,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && data == null) {
      return RetryableErrorWidget(
        errorType: LoadErrorType.loadFailed,
        onRetry: onRetry,
      );
    }

    if (data == null || data!.semesters.isEmpty) {
      return Center(child: Text(l10n.calendarNoEventData));
    }

    return Column(
      children: [
        _buildInteractiveSelector(l10n),
        if (selectedSemester != null) ...[
          _buildSemesterHeaderCard(context, l10n, selectedSemester!),
          Expanded(child: _buildTimeline(l10n, selectedSemester!)),
        ],
      ],
    );
  }

  Widget _buildInteractiveSelector(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<AcademicCalendarSemester>(
        initialValue: selectedSemester,
        decoration: InputDecoration(
          labelText: l10n.selectAcademicYear,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: data!.semesters.map((s) {
          return DropdownMenuItem(value: s, child: Text(s.name));
        }).toList(),
        onChanged: (semester) {
          if (semester != null && semester != selectedSemester) {
            onSemesterChanged(semester);
          }
        },
      ),
    );
  }

  Widget _buildSemesterHeaderCard(
    BuildContext context,
    AppLocalizations l10n,
    AcademicCalendarSemester semester,
  ) {
    final now = DateTime.now();
    final currentWeek = semester.getCurrentWeek(now);
    final isCurrent = semester.isDateInSemester(now);

    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.primaryContainer;
    final onCardColor = theme.colorScheme.onPrimaryContainer;

    // Find next upcoming event
    AcademicCalendarEvent? nextEvent;
    for (final event in semester.events) {
      if (!event.isFinished(now) && !event.isActive(now)) {
        if (nextEvent == null || event.date.isBefore(nextEvent.date)) {
          nextEvent = event;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    semester.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onCardColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isCurrent && currentWeek != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppShapes.extraLarge),
                    ),
                    child: Text(
                      l10n.calendarCurrentWeek(currentWeek),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.calendarSemesterStart(DateFormat('yyyy-MM-dd').format(semester.startDate))} (${l10n.calendarWeeksTotal(semester.totalWeeks)})',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onCardColor.withValues(alpha: 0.85),
              ),
            ),
            if (nextEvent != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 16, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.calendarNextEvent}: ${nextEvent.label}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onCardColor,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    l10n.calendarDaysRemaining(
                      nextEvent.getDaysDifference(now),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onCardColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(
    AppLocalizations l10n,
    AcademicCalendarSemester semester,
  ) {
    final now = DateTime.now();

    // Sort events by date
    final sortedEvents = List<AcademicCalendarEvent>.from(semester.events)
      ..sort((a, b) => a.date.compareTo(b.date));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: sortedEvents.length,
      itemBuilder: (context, index) {
        final event = sortedEvents[index];
        final isLast = index == sortedEvents.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Column: Dot & Line
              _buildTimelineIndicator(context, event, isLast, now),
              // Right Column: Card Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 16),
                  child: _buildEventCard(context, l10n, event, now),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineIndicator(
    BuildContext context,
    AcademicCalendarEvent event,
    bool isLast,
    DateTime now,
  ) {
    final theme = Theme.of(context);
    final isActive = event.isActive(now);
    final isPast = event.isFinished(now);

    Color color;
    if (isActive) {
      color = theme.colorScheme.primary;
    } else if (isPast) {
      color = theme.colorScheme.outlineVariant;
    } else {
      color = _getTagColor(theme, event.tag);
    }

    return SizedBox(
      width: 24,
      child: Column(
        children: [
          // Dot
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isActive ? Colors.transparent : color,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isActive ? 4 : 2),
            ),
          ),
          // Line
          if (!isLast)
            Expanded(
              child: Container(
                width: 2,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    AppLocalizations l10n,
    AcademicCalendarEvent event,
    DateTime now,
  ) {
    final theme = Theme.of(context);
    final isActive = event.isActive(now);
    final isPast = event.isFinished(now);

    final tagBg = _getTagBgColor(theme, event.tag);
    final tagText = _getTagTextColor(theme, event.tag);

    // Format dates
    final dateStr = DateFormat('MM/dd').format(event.date);
    final endDateStr = event.endDate != null
        ? DateFormat('MM/dd').format(event.endDate!)
        : null;
    final fullDateRange = endDateStr != null
        ? '$dateStr - $endDateStr'
        : dateStr;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.medium),
        side: isActive
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Left content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Event Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tagBg,
                          borderRadius: BorderRadius.circular(AppShapes.small),
                        ),
                        child: Text(
                          _getTagLabel(l10n, event.tag),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: tagText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Date range text
                      Text(
                        fullDateRange,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isPast
                              ? theme.colorScheme.outline
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isPast
                          ? theme.colorScheme.outline
                          : theme.colorScheme.onSurface,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Right countdown text
            const SizedBox(width: 8),
            _buildCountdownWidget(l10n, theme, event, now, isActive, isPast),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownWidget(
    AppLocalizations l10n,
    ThemeData theme,
    AcademicCalendarEvent event,
    DateTime now,
    bool isActive,
    bool isPast,
  ) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppShapes.medium),
        ),
        child: Text(
          l10n.calendarToday,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (isPast) {
      final days = -event.getDaysDifference(now);
      return Text(
        l10n.calendarStartedNDaysAgo(days),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    } else {
      final days = event.getDaysDifference(now);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppShapes.medium),
        ),
        child: Text(
          l10n.calendarDaysRemaining(days),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  String _getTagLabel(AppLocalizations l10n, String tag) {
    switch (tag) {
      case 'holiday':
        return l10n.calendarHolidayTag;
      case 'exam':
        return l10n.calendarExamTag;
      case 'start':
        return l10n.calendarStartTag;
      default:
        return l10n.calendarEventTag;
    }
  }

  Color _getTagColor(ThemeData theme, String tag) {
    switch (tag) {
      case 'holiday':
        return theme.colorScheme.tertiary;
      case 'exam':
        return theme.colorScheme.error;
      case 'start':
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.secondary;
    }
  }

  Color _getTagBgColor(ThemeData theme, String tag) {
    switch (tag) {
      case 'holiday':
        return theme.colorScheme.tertiaryContainer;
      case 'exam':
        return theme.colorScheme.errorContainer;
      case 'start':
        return theme.colorScheme.primaryContainer;
      default:
        return theme.colorScheme.secondaryContainer;
    }
  }

  Color _getTagTextColor(ThemeData theme, String tag) {
    switch (tag) {
      case 'holiday':
        return theme.colorScheme.onTertiaryContainer;
      case 'exam':
        return theme.colorScheme.onErrorContainer;
      case 'start':
        return theme.colorScheme.onPrimaryContainer;
      default:
        return theme.colorScheme.onSecondaryContainer;
    }
  }
}
