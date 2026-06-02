import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';

/// 点击课表表头的日期后弹出的调休操作悬浮窗
Future<void> showHolidaySheet(BuildContext context, DateTime date) async {
  final l10n = AppLocalizations.of(context)!;
  final courseProvider = getIt<CourseProvider>();

  final shouldApply = courseProvider.shouldApplyHoliday(date);
  final holidayName = HolidayUtils.getHolidayName(date);
  final dateKey =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  final override = courseProvider.holidayOverrides.value[dateKey];
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
              child: holidayName != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          holidayName,
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.holidayTotalDays(
                            HolidayUtils.getHolidayTotalDays(
                              holidayName,
                              date.year,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '${date.month}月${date.day}日',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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

    // 检查调休日当天是否有课
    final displayWeek = courseProvider.currentWeek.value;
    final hasCoursesOnDay = courseProvider.courses.value.any(
      (c) => c.dayOfWeek == picked.weekday && c.isActiveInWeek(displayWeek),
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
      final config = courseProvider.scheduleConfig.value;
      if (!config.showWeekend) {
        final weekdayName = picked.weekday == DateTime.saturday ? '周六' : '周日';
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
