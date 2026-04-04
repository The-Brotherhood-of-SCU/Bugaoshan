import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rubbish_plan/injection/injector.dart';
import 'package:rubbish_plan/l10n/app_localizations.dart';
import 'package:rubbish_plan/models/course.dart';
import 'package:rubbish_plan/pages/course_edit_page.dart';
import 'package:rubbish_plan/pages/import_schedule_page.dart';
import 'package:rubbish_plan/providers/course_provider.dart';
import 'package:rubbish_plan/widgets/course/course_detail_sheet.dart';
import 'package:rubbish_plan/widgets/course/course_grid.dart';
import 'package:rubbish_plan/widgets/dialog/dialog.dart';
import 'package:rubbish_plan/widgets/route/router_utils.dart';

class CoursePage extends StatefulWidget {
  const CoursePage({super.key});

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> with WidgetsBindingObserver {
  final courseProvider = getIt<CourseProvider>();
  late PageController _pageController;
  late int _visibleWeek;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _visibleWeek = courseProvider.currentWeek.value;
    _pageController = PageController(
      initialPage: courseProvider.currentWeek.value - 1,
    );
    courseProvider.currentWeek.addListener(_onCurrentWeekChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncToCurrentWeek();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    courseProvider.currentWeek.removeListener(_onCurrentWeekChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncToCurrentWeek();
    }
  }

  void _onCurrentWeekChanged() {
    final targetPage = courseProvider.currentWeek.value - 1;
    if (_pageController.hasClients &&
        _pageController.page?.round() != targetPage) {
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_visibleWeek != courseProvider.currentWeek.value) {
      setState(() {
        _visibleWeek = courseProvider.currentWeek.value;
      });
    }
  }

  void _syncToCurrentWeek() {
    final currentWeek = courseProvider.scheduleConfig.value.getCurrentWeek();
    courseProvider.updateCurrentWeek(currentWeek);
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
                        final displayWeek = index + 1;
                        if (_visibleWeek != displayWeek) {
                          setState(() {
                            _visibleWeek = displayWeek;
                          });
                        }
                        // Update current week when user swipes (index is 0-based)
                        courseProvider.updateCurrentWeek(displayWeek);
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

  Widget _buildTopBar(
    BuildContext context,
    AppLocalizations l10n,
    int week,
    int totalWeeks,
  ) {
    final config = courseProvider.scheduleConfig.value;
    final isCurrentCalendarWeek = _visibleWeek == config.getCurrentWeek();

    final now = DateTime.now();
    final dateStr = '${now.year}/${now.month}/${now.day}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => _goToCurrentWeek(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    dateStr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: week > 1 ? () => _changeWeek(week - 1) : null,
                      icon: const Icon(Icons.chevron_left, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        l10n.currentWeek(week),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: week < totalWeeks
                          ? () => _changeWeek(week + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                    ),
                    if (isCurrentCalendarWeek) ...[
                      const SizedBox(width: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          l10n.thisWeek,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _onImport,
                icon: const Icon(Icons.download_rounded, size: 20),
                tooltip: l10n.importSchedule,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                onPressed: _onExport,
                icon: const Icon(Icons.share_rounded, size: 20),
                tooltip: l10n.exportSchedule,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                onPressed: _onAddCourse,
                icon: const Icon(Icons.add_circle_rounded, size: 24),
                tooltip: l10n.addCourse,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _changeWeek(int newWeek) {
    courseProvider.updateCurrentWeek(newWeek);
  }

  void _goToCurrentWeek() {
    _syncToCurrentWeek();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.exportSuccess)));
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
}
