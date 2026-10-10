import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/export/schedule_export_view.dart';
import 'package:bugaoshan/pages/course/export/schedule_image_export.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/export_schedule_provider.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/calendar_export_utils.dart';

enum ScheduleExportAction { copy, image, ics, addToCalendar }

/// 组装「导出课表」弹层的条目（纯函数，不读 [Platform]，便于测试）。
///
/// 顺序固定为 copy、image（仅 [imageSupported] 时）、ics、
/// addToCalendar（仅 [calendarImportAvailable] 时）。
@visibleForTesting
List<ExportSheetItem<ScheduleExportAction>> buildScheduleExportSheetItems(
  AppLocalizations l10n, {
  required bool imageSupported,
  required bool calendarImportAvailable,
}) {
  return [
    ExportSheetItem(
      value: ScheduleExportAction.copy,
      icon: Icons.copy,
      label: l10n.exportScheduleAsCopy,
    ),
    if (imageSupported)
      ExportSheetItem(
        value: ScheduleExportAction.image,
        icon: Icons.image_outlined,
        label: l10n.exportScheduleAsImage,
      ),
    ExportSheetItem(
      value: ScheduleExportAction.ics,
      icon: Icons.calendar_month,
      label: l10n.exportScheduleAsIcs,
    ),
    if (calendarImportAvailable)
      ExportSheetItem(
        value: ScheduleExportAction.addToCalendar,
        icon: Icons.event_available,
        label: l10n.exportScheduleAddToCalendar,
      ),
  ];
}

Future<void> showExportScheduleSheet(
  BuildContext context, {
  ScheduleConfig? schedule,
  List<Course>? courses,
  int? visibleWeek,
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

  final action =
      await CalendarExportUtils.showActionSheetItems<ScheduleExportAction>(
        context,
        title: l10n.exportSchedule,
        items: buildScheduleExportSheetItems(
          l10n,
          imageSupported: isScheduleImageExportSupported,
          calendarImportAvailable:
              CalendarExportUtils.nativeCalendarImportAvailable,
        ),
      );

  if (!context.mounted) return;

  if (action == null) {
    debugPrint("[showExportScheduleSheet] canceled");
    return;
  }

  if (action == ScheduleExportAction.image) {
    // 点击时刻快照当前生效的配置与课程，避免弹层展示期间切表导致漂移。
    final cfg = exportProvider.resolvedConfig;
    final all = exportProvider.resolvedCourses;
    if (cfg == null) {
      AppLog.w(
        'showExportScheduleSheet',
        'image export skipped: no schedule config',
      );
      return;
    }
    final data = ScheduleExportData(
      config: cfg,
      courses: all,
      targetWeek: resolveExportTargetWeek(cfg, visibleWeek: visibleWeek),
    );
    await showScheduleImageExportFlow(context, data: data);
    return;
  }

  final CalendarExportAction legacyAction = switch (action) {
    ScheduleExportAction.copy => CalendarExportAction.copy,
    ScheduleExportAction.ics => CalendarExportAction.ics,
    ScheduleExportAction.addToCalendar => CalendarExportAction.addToCalendar,
    ScheduleExportAction.image => throw StateError('unreachable'),
  };

  await CalendarExportUtils.handleExportAction(
    context: context,
    l10n: l10n,
    action: legacyAction,
    copyToClipboard: () async =>
        await exportProvider.copyToClipBoard() == ExportResult.success,
    copySuccessMessage: l10n.exportScheduleAsCopySuccess,
    copyFailedMessage: l10n.exportScheduleAsCopyFailed,
    buildCalendarPayload: () =>
        exportProvider.buildCalendarPayload(l10n.icsTeacherLabel),
    logTag: 'showExportScheduleSheet',
  );
}
