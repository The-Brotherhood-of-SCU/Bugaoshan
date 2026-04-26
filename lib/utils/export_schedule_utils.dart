import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/export_schedule_provider.dart';
import 'package:flutter/services.dart';

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

  final ExportAction? action = await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                l10n.exportSchedule,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.copy),
              title: Text(l10n.exportScheduleAsCopy),
              onTap: () => Navigator.of(sheetContext).pop(ExportAction.copy),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.calendar_month),
              title: Text(l10n.exportScheduleAsIcs),
              onTap: () => Navigator.of(sheetContext).pop(ExportAction.ics),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );

  if (!context.mounted) return;

  final scaffoldMessenger = ScaffoldMessenger.of(context);
  switch (action) {
    case null:
      debugPrint("[showExportScheduleSheet] canceled");
      break;
    case ExportAction.copy:
      debugPrint("[showExportScheduleSheet] copy");
      final result = await exportProvider.copyToClipBoard();
      if (!context.mounted) return;
      if (result == ExportResult.success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.exportScheduleAsCopySuccess)),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.exportScheduleAsCopyFailed)),
        );
      }
      break;
    case ExportAction.ics:
      debugPrint("[showExportScheduleSheet] ics");
      final semesterName = exportProvider.genIcs(l10n.icsTeacherLabel);

      String? destinationPath;
      try {
        destinationPath = await FilePicker.saveFile(
          dialogTitle: l10n.exportScheduleAsIcsTo,
          fileName: '$semesterName.ics',
          bytes: exportProvider.getIcsBytes(),
        );
      } on PlatformException catch (e) {
        debugPrint("[showExportScheduleSheet] failed to save file: $e");
        if (!context.mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.exportScheduleAsIcsFailed)),
        );
        return;
      } catch (e) {
        debugPrint("[showExportScheduleSheet] $e");
        if (!context.mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.exportScheduleAsIcsFailed)),
        );
        return;
      }

      if (!context.mounted) return;
      if (destinationPath == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.exportScheduleAsIcsCanceled)),
        );
        return;
      }
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.exportScheduleAsIcsSuccess)),
      );
      return;
  }
}
