import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/utils/app_shapes.dart';
import 'package:bugaoshan/utils/calendar_event_utils.dart';
import 'package:bugaoshan/utils/calendar_import_utils.dart';

export 'package:bugaoshan/utils/calendar_event_utils.dart'
    show CalendarExportPayload;

enum CalendarExportAction { copy, ics, addToCalendar }

class CalendarExportUtils {
  const CalendarExportUtils._();

  static bool get nativeCalendarImportAvailable =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  static Future<CalendarExportAction?> showActionSheet(
    BuildContext context,
    AppLocalizations l10n, {
    required String title,
    bool includeCopy = false,
  }) {
    return showModalBottomSheet<CalendarExportAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppShapes.extraLarge),
        ),
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
                  title,
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              if (includeCopy)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Icons.copy),
                  title: Text(l10n.exportScheduleAsCopy),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(CalendarExportAction.copy),
                ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.calendar_month),
                title: Text(l10n.exportScheduleAsIcs),
                onTap: () =>
                    Navigator.of(sheetContext).pop(CalendarExportAction.ics),
              ),
              if (nativeCalendarImportAvailable)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Icons.event_available),
                  title: Text(l10n.exportScheduleAddToCalendar),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(CalendarExportAction.addToCalendar),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static Future<bool> copyJsonToClipboard(
    Object? data, {
    required String logTag,
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: json.encode(data)));
      debugPrint("[$logTag] clipboard written success");
      return true;
    } on PlatformException catch (e) {
      debugPrint("[$logTag] platform related exception: $e");
    } catch (e) {
      debugPrint("[$logTag] other exception: $e");
    }
    return false;
  }

  static Future<void> saveIcsContent({
    required BuildContext context,
    required AppLocalizations l10n,
    required String fileName,
    required String content,
    required String logTag,
  }) {
    return saveIcsBytes(
      context: context,
      l10n: l10n,
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(content)),
      logTag: logTag,
    );
  }

  static Future<void> handleExportAction({
    required BuildContext context,
    required AppLocalizations l10n,
    required CalendarExportAction action,
    required Future<bool> Function() copyToClipboard,
    required String copySuccessMessage,
    required String copyFailedMessage,
    required FutureOr<CalendarExportPayload> Function() buildCalendarPayload,
    required String logTag,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 先构建 payload 检查是否有课程
    final payload = await Future.value(buildCalendarPayload());
    if (!context.mounted) return;

    final hasEvents = payload.events.isNotEmpty;

    switch (action) {
      case CalendarExportAction.copy:
        // 复制到剪贴板可以正常处理空课表
        final success = await copyToClipboard();
        if (!context.mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(success ? copySuccessMessage : copyFailedMessage),
          ),
        );
        return;
      case CalendarExportAction.ics:
        // 导出 ICS 可以正常处理空课表
        await saveIcsContent(
          context: context,
          l10n: l10n,
          fileName: payload.fileName,
          content: payload.icsContent,
          logTag: logTag,
        );
        return;
      case CalendarExportAction.addToCalendar:
        // 添加到日历需要有课程
        if (!hasEvents) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(l10n.exportScheduleAddToCalendarEmpty)),
          );
          return;
        }
        await importToCalendar(
          context: context,
          l10n: l10n,
          events: payload.events,
          saveIcsToCache: () => writeIcsContentToCache(
            fileName: payload.fileName,
            content: payload.icsContent,
          ),
          logTag: logTag,
        );
        return;
    }
  }

  static Future<void> saveIcsBytes({
    required BuildContext context,
    required AppLocalizations l10n,
    required String fileName,
    required Uint8List bytes,
    required String logTag,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    String? destinationPath;
    try {
      destinationPath = await FilePicker.saveFile(
        dialogTitle: l10n.exportScheduleAsIcsTo,
        fileName: fileName,
        bytes: bytes,
      );
    } on PlatformException catch (e) {
      debugPrint("[$logTag] failed to save ICS file: $e");
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.exportScheduleAsIcsFailed)),
      );
      return;
    } catch (e) {
      debugPrint("[$logTag] failed to export ICS file: $e");
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.exportScheduleAsIcsFailed)),
      );
      return;
    }

    if (!context.mounted) return;
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          destinationPath == null
              ? l10n.exportScheduleAsIcsCanceled
              : l10n.exportScheduleAsIcsSuccess,
        ),
      ),
    );
  }

  static Future<void> importToCalendar({
    required BuildContext context,
    required AppLocalizations l10n,
    required List<Map<String, Object>> events,
    required Future<String> Function() saveIcsToCache,
    required String logTag,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (events.isEmpty) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.exportScheduleAddToCalendarFailed)),
      );
      return;
    }

    try {
      String? result;
      if (Platform.isIOS || Platform.isMacOS) {
        // iOS/iPadOS/macOS do not expose a public API for importing a local .ics
        // file into Calendar. The native side uses EventKit to write events.
        final calendarIdentifier =
            await CalendarImportUtils.pickIosCalendarIdentifier(context, l10n);
        if (!context.mounted || calendarIdentifier == null) return;
        result = await CalendarImportUtils.channel.invokeMethod<String>(
          'importIcsToCalendar',
          {'events': events, 'calendarIdentifier': calendarIdentifier},
        );
      } else if (Platform.isAndroid) {
        final icsPath = await saveIcsToCache();
        result = await CalendarImportUtils.channel.invokeMethod<String>(
          'importIcsToCalendar',
          {'path': icsPath},
        );
      } else {
        final icsPath = await saveIcsToCache();
        final openResult = await OpenFilex.open(icsPath);
        if (openResult.type != ResultType.done) {
          throw PlatformException(
            code: 'OPEN_ICS_FAILED',
            message: openResult.message,
          );
        }
        result = 'opened';
      }

      if (!context.mounted) return;
      if (result == 'opened' || result == 'imported') {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.exportScheduleAddToCalendarSuccess)),
        );
      }
      // If result == 'picker', the system picker is already shown.
    } catch (e) {
      debugPrint("[$logTag] failed to import calendar: $e");
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.exportScheduleAddToCalendarFailed)),
      );
    }
  }

  static Future<String> writeIcsContentToCache({
    required String fileName,
    required String content,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final file = File('${cacheDir.path}/$fileName');
    await file.writeAsString(content);
    return file.path;
  }
}
