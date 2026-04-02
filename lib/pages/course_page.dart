import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rubbish_plan/injection/injector.dart';
import 'package:rubbish_plan/l10n/app_localizations.dart';
import 'package:rubbish_plan/models/course.dart';
import 'package:rubbish_plan/pages/course_edit_page.dart';
import 'package:rubbish_plan/pages/import_schedule_page.dart';
import 'package:rubbish_plan/pages/schedule_management_page.dart';
import 'package:rubbish_plan/providers/course_provider.dart';
import 'package:rubbish_plan/widgets/common/text.dart';
import 'package:rubbish_plan/widgets/course/course_detail_sheet.dart';
import 'package:rubbish_plan/widgets/course/course_grid.dart';
import 'package:rubbish_plan/widgets/dialog/dialog.dart';
import 'package:rubbish_plan/widgets/route/router_utils.dart';

class CoursePage extends StatefulWidget {
  const CoursePage({super.key});

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  final courseProvider = getIt<CourseProvider>();
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Initialize PageController with the current week (0-indexed)
    _pageController = PageController(
      initialPage: courseProvider.currentWeek.value - 1,
    );
    
    // Listen to changes in currentWeek to animate the PageView
    courseProvider.currentWeek.addListener(_onCurrentWeekChanged);
  }

  @override
  void dispose() {
    courseProvider.currentWeek.removeListener(_onCurrentWeekChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onCurrentWeekChanged() {
    final targetPage = courseProvider.currentWeek.value - 1;
    if (_pageController.hasClients && _pageController.page?.round() != targetPage) {
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: Listenable.merge([
        courseProvider.courses,
        courseProvider.scheduleConfig,
        courseProvider.currentWeek,
        courseProvider.isLoading,
      ]),
      builder: (context, _) {
        if (courseProvider.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final config = courseProvider.scheduleConfig.value;
        final week = courseProvider.currentWeek.value;
        final totalWeeks = config.totalWeeks;
        final allCourses = courseProvider.courses.value;

        return Column(
          children: [
            // Top bar: date, week switcher, action buttons
            _buildTopBar(context, l10n, week, totalWeeks),
            const SizedBox(height: 8),
            // Course grid
            Expanded(
              child: allCourses.isEmpty
                  ? Center(child: Text(l10n.noCourseThisWeek))
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: totalWeeks,
                      onPageChanged: (index) {
                        // Update current week when user swipes (index is 0-based)
                        courseProvider.updateCurrentWeek(index + 1);
                      },
                      itemBuilder: (context, index) {
                        final displayWeek = index + 1;
                        return CourseGrid(
                          courses: allCourses,
                          config: config,
                          displayWeek: displayWeek,
                          totalWeeks: totalWeeks,
                          onCourseTap: _onCourseTap,
                          onCourseLongPress: _onCourseLongPress,
                          onEmptyTap: _onEmptyTap,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, AppLocalizations l10n, int week, int totalWeeks) {
    return Row(
      spacing: 8,
      children: [
        const SizedBox(width: 8),
        // Week navigation
        IconButton(
          onPressed: week > 1 ? () => _changeWeek(week - 1) : null,
          icon: const Icon(Icons.chevron_left, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        GestureDetector(
          onTap: () => _goToCurrentWeek(),
          child: TitleText(l10n.currentWeek(week)),
        ),
        IconButton(
          onPressed: week < totalWeeks ? () => _changeWeek(week + 1) : null,
          icon: const Icon(Icons.chevron_right, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const Expanded(child: SizedBox()),
        IconButton(
          onPressed: _showSchedulePicker,
          icon: const Icon(Icons.list_alt_rounded),
        ),
        IconButton(
          onPressed: _onAddCourse,
          icon: const Icon(Icons.add),
        ),
        IconButton(
          onPressed: _onImport,
          icon: const Icon(Icons.download),
        ),
        IconButton(
          onPressed: _onExport,
          icon: const Icon(Icons.send),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _changeWeek(int newWeek) {
    courseProvider.updateCurrentWeek(newWeek);
  }

  void _goToCurrentWeek() {
    final currentWeek = courseProvider.scheduleConfig.value.getCurrentWeek();
    courseProvider.updateCurrentWeek(currentWeek);
  }

  void _showSchedulePicker() {
    popupOrNavigate(context, const ScheduleManagementPage());
  }

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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  l10n.importSchedule,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.text_fields),
                title: Text(l10n.importFromText),
                onTap: () {
                  Navigator.pop(context);
                  popupOrNavigate(outerContext, ImportSchedulePage(courseProvider: courseProvider));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _onExport() async {
    final l10n = AppLocalizations.of(context)!;
    final config = courseProvider.scheduleConfig.value;
    final allCourses = courseProvider.courses.value;

    final data = {
      'config': config.toJson(),
      'courses': allCourses.map((e) => e.toJson()).toList(),
    };

    final jsonStr = json.encode(data);
    await Clipboard.setData(ClipboardData(text: jsonStr));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportSuccess)),
      );
    }
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
      builder: (context) => CourseDetailSheet(
        course: course,
        courseProvider: courseProvider,
      ),
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
      CourseEditPage(
        prefillDayOfWeek: dayOfWeek,
        prefillSection: section,
      ),
    );
  }
}
