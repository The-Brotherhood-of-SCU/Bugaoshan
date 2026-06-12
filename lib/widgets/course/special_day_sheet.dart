import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';
import 'package:bugaoshan/utils/app_shapes.dart';

/// 点击课表表头的特殊日（假/节/气）后弹出的信息悬浮窗
Future<void> showSpecialDaySheet(
  BuildContext context,
  DateTime date,
  SpecialDayInfo info,
) async {
  switch (info.type) {
    case SpecialDayType.holiday:
      await _showSheet(context, date, info, Colors.red);
    case SpecialDayType.festival:
      await _showSheet(context, date, info, Colors.orange);
    case SpecialDayType.solarTerm:
      await _showSheet(context, date, info, Colors.green);
    case SpecialDayType.ordinary:
      break;
  }
}

Future<void> _showSheet(
  BuildContext context,
  DateTime date,
  SpecialDayInfo info,
  Color color,
) async {
  final l10n = AppLocalizations.of(context)!;
  final typeLabel = switch (info.type) {
    SpecialDayType.holiday => l10n.holidayTypeLabel,
    SpecialDayType.festival => l10n.festivalTypeLabel,
    SpecialDayType.solarTerm => l10n.solarTermTypeLabel,
    _ => '',
  };

  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppShapes.extraLarge),
      ),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Holiday/festival/term name
                  Text(
                    info.name ?? l10n.dateMonthDay(date.month, date.day),
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Holiday total days subtitle
                  if (info.holidayTotalDays != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        l10n.holidayTotalDays(info.holidayTotalDays!),
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  // Date
                  Text(
                    l10n.dateMonthDay(date.month, date.day),
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
