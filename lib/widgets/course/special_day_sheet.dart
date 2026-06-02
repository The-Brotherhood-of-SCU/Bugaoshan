import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/notice/jwc/campus_notice_page.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

/// 点击课表表头的特殊日（假/节/气）后弹出的统一信息悬浮窗
///
/// 如果是放假类型，下方还会显示调休操作按钮。
Future<void> showSpecialDaySheet(
  BuildContext context,
  DateTime date,
  SpecialDayInfo info,
) async {
  switch (info.type) {
    case SpecialDayType.holiday:
      await _showHolidaySheet(context, date, info);
    case SpecialDayType.festival:
      await _showSimpleSheet(context, date, info, Colors.orange);
    case SpecialDayType.solarTerm:
      await _showSimpleSheet(context, date, info, Colors.green);
    case SpecialDayType.ordinary:
      break;
  }
}

/// 简单展示型弹窗（节 / 气）
Future<void> _showSimpleSheet(
  BuildContext context,
  DateTime date,
  SpecialDayInfo info,
  Color color,
) async {
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  Text(
                    info.name ?? '${date.month}月${date.day}日',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (info.subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        info.subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Text(
                    '${date.month}月${date.day}日',
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

/// 放假操作型弹窗（假）
Future<void> _showHolidaySheet(
  BuildContext context,
  DateTime date,
  SpecialDayInfo info,
) async {
  final l10n = AppLocalizations.of(context)!;
  final courseProvider = getIt<CourseProvider>();
  final dateKey =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  final override = courseProvider.holidayOverrides.value[dateKey];

  final shouldApply = override?.active ?? HolidayUtils.isStatutoryHoliday(date);
  final hasMakeup = override?.makeupDate != null;

  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  Text(
                    info.name ?? '${date.month}月${date.day}日',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (info.subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        info.subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Text(
                    '${date.month}月${date.day}日',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // 取消设置放假（当前是放假状态）
            if (shouldApply)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.cancel_outlined, color: Colors.grey),
                title: Text(l10n.cancelHoliday),
                subtitle: Text(l10n.cancelHolidayDesc),
                onTap: () async {
                  Navigator.pop(ctx);
                  await courseProvider.cancelHoliday(date);
                },
              ),
            // 设置放假
            if (!shouldApply)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.beach_access, color: Colors.red),
                title: Text(l10n.setHoliday),
                subtitle: Text(l10n.setHolidayDesc),
                onTap: () async {
                  Navigator.pop(ctx);
                  await courseProvider.setHoliday(date);
                },
              ),
            // 取消调休（仅当已有调休）
            if (hasMakeup)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.orange,
                ),
                title: Text(l10n.cancelMakeup),
                subtitle: Text(l10n.cancelMakeupDesc),
                onTap: () async {
                  Navigator.pop(ctx);
                  await courseProvider.cancelMakeup(date);
                },
              ),
            // 设置/修改调休
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.date_range, color: Colors.orange),
              title: Text(
                hasMakeup ? l10n.modifyMakeupDate : l10n.setHolidayWithMakeup,
              ),
              subtitle: Text(
                hasMakeup
                    ? l10n.modifyMakeupDateDesc
                    : l10n.setHolidayWithMakeupDesc,
              ),
              onTap: () async {
                Navigator.pop(ctx);
                _pickMakeupDate(context, date);
              },
            ),
            // 查询调休安排
            if (info.name != null)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.search, color: Colors.blue),
                title: Text(l10n.searchHolidaySchedule),
                subtitle: Text(l10n.searchHolidayScheduleDesc),
                onTap: () {
                  Navigator.pop(ctx);
                  popupOrNavigate(
                    logicRootContext,
                    CampusNoticePage(searchQuery: info.name, searchDate: date),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

Future<void> _pickMakeupDate(BuildContext context, DateTime holidayDate) async {
  final l10n = AppLocalizations.of(context)!;
  final courseProvider = getIt<CourseProvider>();

  final now = DateTime.now();
  // 默认选节假日后的第一天
  final initialDate = holidayDate.add(const Duration(days: 1));

  final picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: holidayDate.subtract(const Duration(days: 30)),
    lastDate: DateTime(now.year + 1, 12, 31),
    helpText: l10n.selectMakeupDate,
    cancelText: l10n.cancel,
    confirmText: l10n.confirm,
  );

  if (picked != null) {
    if (!context.mounted) return;

    // 计算调休日所在的教学周
    final config = courseProvider.scheduleConfig.value;
    final diff = picked.difference(config.semesterStartDate).inDays;
    final pickedWeek = ((diff + config.semesterStartDate.weekday - 1) ~/ 7) + 1;
    final hasCoursesOnDay = courseProvider.courses.value.any(
      (c) => c.dayOfWeek == picked.weekday && c.isActiveInWeek(pickedWeek),
    );
    if (hasCoursesOnDay) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.makeupDateHasCoursesTitle),
          content: Text(l10n.makeupDateHasCoursesBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      return;
    }

    // 如果选择了周末且课表未显示周末，提示用户
    if (picked.weekday == DateTime.saturday ||
        picked.weekday == DateTime.sunday) {
      if (!config.showWeekend) {
        final weekdayName = picked.weekday == DateTime.saturday
            ? l10n.saturday
            : l10n.sunday;
        if (!context.mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.holidayWeekendWarningTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${picked.month}月${picked.day}日（$weekdayName）',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(l10n.holidayWeekendWarningBody),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  config.showWeekend = true;
                  courseProvider.updateScheduleConfig(config);
                  Navigator.pop(ctx);
                },
                child: Text(l10n.enableWeekend),
              ),
            ],
          ),
        );
      }
    }
    await courseProvider.setHolidayWithMakeup(holidayDate, picked);
  }
}
