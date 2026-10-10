import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/utils/export_schedule_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 取出中文 l10n：经 MaterialApp + Builder，保证走正式本地化链路。
Future<AppLocalizations> _zhL10n(WidgetTester tester) async {
  AppLocalizations? l10n;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return l10n!;
}

void main() {
  group('buildScheduleExportSheetItems', () {
    testWidgets('全开：长度 4，第 2 项为 image，且 label 顺序固定', (tester) async {
      final l10n = await _zhL10n(tester);
      final items = buildScheduleExportSheetItems(
        l10n,
        imageSupported: true,
        calendarImportAvailable: true,
      );

      expect(items.length, 4);
      expect(items[1].value, ScheduleExportAction.image);
      expect(items.map((e) => e.value).toList(), [
        ScheduleExportAction.copy,
        ScheduleExportAction.image,
        ScheduleExportAction.ics,
        ScheduleExportAction.addToCalendar,
      ]);
      expect(items.map((e) => e.label).toList(), [
        l10n.exportScheduleAsCopy,
        l10n.exportScheduleAsImage,
        l10n.exportScheduleAsIcs,
        l10n.exportScheduleAddToCalendar,
      ]);
    });

    testWidgets('imageSupported:false → 长度 3 且不含 image', (tester) async {
      final l10n = await _zhL10n(tester);
      final items = buildScheduleExportSheetItems(
        l10n,
        imageSupported: false,
        calendarImportAvailable: true,
      );

      expect(items.length, 3);
      expect(items.map((e) => e.value), [
        ScheduleExportAction.copy,
        ScheduleExportAction.ics,
        ScheduleExportAction.addToCalendar,
      ]);
      expect(items.map((e) => e.label).toList(), [
        l10n.exportScheduleAsCopy,
        l10n.exportScheduleAsIcs,
        l10n.exportScheduleAddToCalendar,
      ]);
    });

    testWidgets('calendarImportAvailable:false → 不含 addToCalendar', (
      tester,
    ) async {
      final l10n = await _zhL10n(tester);
      final items = buildScheduleExportSheetItems(
        l10n,
        imageSupported: true,
        calendarImportAvailable: false,
      );

      expect(items.length, 3);
      expect(items.map((e) => e.value), [
        ScheduleExportAction.copy,
        ScheduleExportAction.image,
        ScheduleExportAction.ics,
      ]);
      expect(items.map((e) => e.label).toList(), [
        l10n.exportScheduleAsCopy,
        l10n.exportScheduleAsImage,
        l10n.exportScheduleAsIcs,
      ]);
    });

    testWidgets('双关：长度 2，仅 copy + ics', (tester) async {
      final l10n = await _zhL10n(tester);
      final items = buildScheduleExportSheetItems(
        l10n,
        imageSupported: false,
        calendarImportAvailable: false,
      );

      expect(items.map((e) => e.value).toList(), [
        ScheduleExportAction.copy,
        ScheduleExportAction.ics,
      ]);
      expect(items.map((e) => e.label).toList(), [
        l10n.exportScheduleAsCopy,
        l10n.exportScheduleAsIcs,
      ]);
    });
  });
}
