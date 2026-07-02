import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/export_schedule_provider.dart';
import 'package:bugaoshan/utils/calendar_export_utils.dart';

Future<void> showExportScheduleSheet(
  BuildContext context, {
  ScheduleConfig? schedule,
  List<Course>? courses,
}) async {
  final l10n = AppLocalizations.of(context)!;

  if (schedule != null && courses == null) {
    if (!context.mounted) return;
    courses = await getIt<CourseProvider>().getCoursesForSchedule(schedule.id);
  }

  if (!context.mounted) return;

  final exportProvider = schedule != null && courses != null
      ? ExportScheduleProvider.forSchedule(schedule, courses)
      : ExportScheduleProvider.create();

  final action = await CalendarExportUtils.showActionSheet(
    context,
    l10n,
    title: l10n.exportSchedule,
    includeCopy: true,
  );

  if (!context.mounted) return;

  if (action == null) {
    debugPrint("[showExportScheduleSheet] canceled");
    return;
  }

  await CalendarExportUtils.handleExportAction(
    context: context,
    l10n: l10n,
    action: action,
    copyToClipboard: () async =>
        await exportProvider.copyToClipBoard() == ExportResult.success,
    copySuccessMessage: l10n.exportScheduleAsCopySuccess,
    copyFailedMessage: l10n.exportScheduleAsCopyFailed,
    buildCalendarPayload: () =>
        exportProvider.buildCalendarPayload(l10n.icsTeacherLabel),
    logTag: 'showExportScheduleSheet',
  );
}
