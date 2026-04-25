import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/export_schedule_provider.dart';

Future<void> showExportScheduleSheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final exportProvider = ExportScheduleProvider.create();

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
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 8,
              ),
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
      final semesterName = await exportProvider.saveIcsToTempFile(
        l10n.icsTeacherLabel,
      );
      if (!context.mounted) return;
      if (semesterName == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.exportScheduleAsIcsFailed)),
        );
        return;
      }

      final destinationPath = await FilePicker.saveFile(
        dialogTitle: l10n.exportScheduleAsIcsTo,
        fileName: '$semesterName.ics',
      );
      if (!context.mounted) return;
      if (destinationPath == null) {
        await exportProvider.cleanTempFile();
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.exportScheduleAsIcsCanceled)),
        );
        return;
      }

      final result = await exportProvider.moveTempToDestination(
        destinationPath,
      );
      if (!context.mounted) return;
      if (result == ExportResult.success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.exportScheduleAsIcsSuccess)),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.exportScheduleAsIcsFailed)),
        );
      }
      break;
  }
}
