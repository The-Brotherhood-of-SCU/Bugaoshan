import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import '../edit/course_edit_page.dart';
import '../import/import_source_sheet.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import '../widgets/course_detail_sheet.dart';
import '../widgets/special_day_sheet.dart';
import 'package:bugaoshan/utils/export_schedule_utils.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:bugaoshan/theme_shape.dart';

/// CoursePage 相关的用户操作集合。
/// 从原先 `extension _CoursePageActions on _CoursePageState` 抽离为独立 helper，
/// 通过显式参数注入 [BuildContext] 与 [CourseProvider]，避免持有 State 私有成员。
class CoursePageActions {
  static void showImportSheet(
    BuildContext context,
    CourseProvider courseProvider,
  ) {
    showScheduleImportSheet(context, courseProvider: courseProvider);
  }

  static void showExportSheet(BuildContext context, {int? visibleWeek}) {
    showExportScheduleSheet(context, visibleWeek: visibleWeek);
  }

  static void navigateToAddCourse(
    BuildContext context,
    ScheduleConfig scheduleConfig,
  ) {
    popupOrNavigate(context, CourseEditPage(scheduleConfig: scheduleConfig));
  }

  static void showCourseDetailSheet(
    BuildContext context,
    Course course,
    CourseProvider courseProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppShapes.extraLarge),
        ),
      ),
      builder: (context) =>
          CourseDetailSheet(course: course, courseProvider: courseProvider),
    );
  }

  static Future<void> handleCourseLongPress(
    BuildContext context,
    Course course,
    CourseProvider courseProvider,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showYesNoDialog(
      title: l10n.deleteCourse,
      content: l10n.deleteCourseConfirm,
    );
    if (confirm == true) {
      await courseProvider.deleteCourse(course.id);
    }
  }

  static void handleEmptyTap(
    BuildContext context,
    int dayOfWeek,
    int section,
    ScheduleConfig scheduleConfig,
  ) {
    popupOrNavigate(
      context,
      CourseEditPage(
        scheduleConfig: scheduleConfig,
        prefillDayOfWeek: dayOfWeek,
        prefillSection: section,
      ),
    );
  }

  static void handleSpecialDayTap(
    BuildContext context,
    DateTime date,
    SpecialDayInfo info,
  ) {
    showSpecialDaySheet(context, date, info);
  }
}
