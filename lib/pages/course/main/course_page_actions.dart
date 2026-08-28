import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import '../edit/course_edit_page.dart';
import '../import/import_schedule_page.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final outerContext = context;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppShapes.extraLarge),
        ),
      ),
      builder: (context) => SafeArea(
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
                  l10n.importSchedule,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.share),
                title: Text(l10n.importFromShare),
                onTap: () {
                  Navigator.pop(context);
                  popupOrNavigate(
                    outerContext,
                    ImportSchedulePage(
                      courseProvider: courseProvider,
                      mode: ImportMode.share,
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.school),
                title: Text(l10n.importFromJwxt),
                onTap: () {
                  Navigator.pop(context);
                  popupOrNavigate(
                    outerContext,
                    ImportSchedulePage(
                      courseProvider: courseProvider,
                      mode: ImportMode.jwxt,
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.cloud_download_outlined),
                title: Text(l10n.importFromJwxtOnline),
                onTap: () {
                  Navigator.pop(context);
                  popupOrNavigate(
                    outerContext,
                    ImportSchedulePage(
                      courseProvider: courseProvider,
                      mode: ImportMode.online,
                    ),
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

  static void showExportSheet(BuildContext context) {
    showExportScheduleSheet(context);
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
