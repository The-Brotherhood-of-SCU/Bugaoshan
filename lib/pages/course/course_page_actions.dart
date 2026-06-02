part of 'course_page.dart';

extension _CoursePageActions on _CoursePageState {
  void _onImport() {
    final l10n = AppLocalizations.of(context)!;
    final outerContext = context; // Capture the stable context
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

  void _onExport() {
    showExportScheduleSheet(context);
  }

  void _onAddCourse() {
    popupOrNavigate(context, const CourseEditPage());
  }

  void _onCourseTap(Course course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          CourseDetailSheet(course: course, courseProvider: courseProvider),
    );
  }

  void _onCourseLongPress(Course course) {
    final l10n = AppLocalizations.of(context)!;
    showYesNoDialog(
      title: l10n.deleteCourse,
      content: l10n.deleteCourseConfirm,
    ).then((confirm) async {
      if (confirm == true) {
        await courseProvider.deleteCourse(course.id);
      }
    });
  }

  void _onEmptyTap(int dayOfWeek, int section) {
    popupOrNavigate(
      context,
      CourseEditPage(prefillDayOfWeek: dayOfWeek, prefillSection: section),
    );
  }

  void _onSpecialDayTap(DateTime date, SpecialDayInfo info) {
    showSpecialDaySheet(context, date, info);
  }
}
