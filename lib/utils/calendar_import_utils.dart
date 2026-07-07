import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

class CalendarDestination {
  final String id;
  final String title;
  final String sourceTitle;
  final bool isDefault;

  const CalendarDestination({
    required this.id,
    required this.title,
    required this.sourceTitle,
    required this.isDefault,
  });

  factory CalendarDestination.fromJson(Map<Object?, Object?> json) {
    return CalendarDestination(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sourceTitle: json['sourceTitle'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class CalendarImportUtils {
  static const MethodChannel channel = MethodChannel('bugaoshan/update');

  const CalendarImportUtils._();

  static Future<String?> pickIosCalendarIdentifier(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    if (!Platform.isIOS) return null;

    final rawCalendars =
        await channel.invokeListMethod<Object?>('listWritableCalendars') ??
        const <Object?>[];
    final calendars = rawCalendars
        .whereType<Map<Object?, Object?>>()
        .map(CalendarDestination.fromJson)
        .where(
          (calendar) => calendar.id.isNotEmpty && calendar.title.isNotEmpty,
        )
        .toList();

    if (calendars.isEmpty) {
      throw PlatformException(
        code: 'NO_WRITABLE_CALENDARS',
        message: 'No writable calendars are available',
      );
    }
    if (!context.mounted) return null;

    final selected = await showModalBottomSheet<CalendarDestination>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Text(
                    l10n.exportScheduleSelectCalendar,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: calendars.length,
                    itemBuilder: (context, index) {
                      final calendar = calendars[index];
                      final subtitleParts = [
                        if (calendar.isDefault)
                          l10n.exportScheduleCalendarDefault,
                        if (calendar.sourceTitle.isNotEmpty)
                          calendar.sourceTitle,
                      ];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        leading: Icon(
                          calendar.isDefault
                              ? Icons.event_available_outlined
                              : Icons.calendar_month_outlined,
                        ),
                        title: Text(calendar.title),
                        subtitle: subtitleParts.isEmpty
                            ? null
                            : Text(subtitleParts.join(' · ')),
                        onTap: () => Navigator.of(sheetContext).pop(calendar),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return selected?.id;
  }
}
