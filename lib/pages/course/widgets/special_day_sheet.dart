import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/date_display_format.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';
import 'package:bugaoshan/theme_shape.dart';

/// 点击课表表头的特殊日（假/节/气）后弹出的信息悬浮窗。
///
/// 日期文案与表头同源，使用调用方传入的 [dateFormat]（全局日期格式设置），
/// 避免弹窗与表头显示成两种顺序。
Future<void> showSpecialDaySheet(
  BuildContext context,
  DateTime date,
  SpecialDayInfo info, {
  required DateDisplayFormat dateFormat,
}) async {
  switch (info.type) {
    case SpecialDayType.holiday:
      await _showSheet(context, date, info, Colors.red, dateFormat);
    case SpecialDayType.festival:
      await _showSheet(context, date, info, Colors.orange, dateFormat);
    case SpecialDayType.solarTerm:
      await _showSheet(context, date, info, Colors.green, dateFormat);
    case SpecialDayType.ordinary:
      break;
  }
}

Future<void> _showSheet(
  BuildContext context,
  DateTime date,
  SpecialDayInfo info,
  Color color,
  DateDisplayFormat dateFormat,
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
                      borderRadius: BorderRadius.circular(AppShapes.xs),
                    ),
                    child: Text(
                      typeLabel,
                      style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Holiday/festival/term name
                  Text(
                    info.name ?? dateFormat.formatMonthDay(date),
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
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  // Date
                  Text(
                    dateFormat.formatMonthDay(date),
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
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
