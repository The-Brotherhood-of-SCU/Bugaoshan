import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course_edit_page.dart';
import 'package:bugaoshan/pages/import_schedule_page.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/widgets/course/course_detail_sheet.dart';
import 'package:bugaoshan/widgets/course/course_grid.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:bugaoshan/utils/export_schedule_utils.dart';

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
                  : _SwipePageView(
                      controller: _pageController,
                      itemCount: totalWeeks,
                      onPageChanged: (index) {
                        final displayWeek = index + 1;
                        if (_visibleWeek != displayWeek) {
                          setState(() {
                            _visibleWeek = displayWeek;
                          });
                        }
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
                Text(
                  dateStr,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: week > 1 ? () => _changeWeek(week - 1) : null,
                      child: Icon(
                        Icons.chevron_left,
                        size: 16,
                        color: week > 1
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).disabledColor,
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
                    GestureDetector(
                      onTap: week < totalWeeks
                          ? () => _changeWeek(week + 1)
                          : null,
                      child: Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: week < totalWeeks
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).disabledColor,
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
                    ] else ...[
                      const SizedBox(width: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          l10n.actualCurrentWeek(config.getCurrentWeek()),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
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
}

/// A PageView wrapper that only triggers page switching when the horizontal
/// displacement is significantly larger than vertical, so vertical scrolling
/// inside the page is not accidentally intercepted.
class _SwipePageView extends StatefulWidget {
  final PageController controller;
  final int itemCount;
  final void Function(int index) onPageChanged;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const _SwipePageView({
    required this.controller,
    required this.itemCount,
    required this.onPageChanged,
    required this.itemBuilder,
  });

  @override
  State<_SwipePageView> createState() => _SwipePageViewState();
}

class _SwipePageViewState extends State<_SwipePageView> {
  double _dragStartX = 0;
  double _dragStartY = 0;
  bool? _isHorizontalDrag; // null = undecided
  int _dragStartPage = 0;

  void _onPanStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _dragStartY = details.globalPosition.dy;
    _isHorizontalDrag = null;
    _dragStartPage = (widget.controller.page ?? 0).round();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isHorizontalDrag == null) {
      final dx = (details.globalPosition.dx - _dragStartX).abs();
      final dy = (details.globalPosition.dy - _dragStartY).abs();
      if (dx > 8 || dy > 8) {
        _isHorizontalDrag = dx > dy * 1.5;
      }
    }
    if (_isHorizontalDrag == true) {
      final newOffset = (widget.controller.offset - details.delta.dx).clamp(
        0.0,
        widget.controller.position.maxScrollExtent,
      );
      widget.controller.jumpTo(newOffset);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isHorizontalDrag != true) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final dragDelta = details.globalPosition.dx - _dragStartX;
    int targetPage;
    // Flick gesture: any noticeable velocity flips the page
    if (velocity < -100) {
      targetPage = (_dragStartPage + 1).clamp(0, widget.itemCount - 1);
    } else if (velocity > 100) {
      targetPage = (_dragStartPage - 1).clamp(0, widget.itemCount - 1);
    } else if (dragDelta < -50) {
      // Dragged left far enough without much velocity
      targetPage = (_dragStartPage + 1).clamp(0, widget.itemCount - 1);
    } else if (dragDelta > 50) {
      // Dragged right far enough without much velocity
      targetPage = (_dragStartPage - 1).clamp(0, widget.itemCount - 1);
    } else {
      // Small drag, snap back
      targetPage = _dragStartPage;
    }
    widget.controller.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: PageView.builder(
        physics: const NeverScrollableScrollPhysics(),
        controller: widget.controller,
        itemCount: widget.itemCount,
        onPageChanged: widget.onPageChanged,
        itemBuilder: widget.itemBuilder,
      ),
    );
  }
}
