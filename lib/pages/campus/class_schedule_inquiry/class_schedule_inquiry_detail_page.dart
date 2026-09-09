import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/pages/course/main/course_page_swipe_page_view.dart';
import 'package:bugaoshan/pages/course/widgets/course_detail_sheet.dart';
import 'package:bugaoshan/pages/course/widgets/course_grid.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/class_schedule_inquiry_provider.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/utils/week_parser.dart';

/// 班级课表详情页 - 以课表网格按周展示班级课程。
///
/// 查询面向历年学期，日期与「当前周」无意义：固定从第 1 周开始，
/// 隐去表头日期，通过左右滑动或顶部箭头切换周次。
class ClassScheduleInquiryDetailPage extends StatefulWidget {
  final ClassInfo classInfo;

  const ClassScheduleInquiryDetailPage({super.key, required this.classInfo});

  @override
  State<ClassScheduleInquiryDetailPage> createState() =>
      _ClassScheduleInquiryDetailPageState();
}

class _ClassScheduleInquiryDetailPageState
    extends State<ClassScheduleInquiryDetailPage> {
  static const int _totalWeeks = kDefaultTotalWeeks;
  static const Duration _pageTransitionDuration = Duration(milliseconds: 250);

  late final ClassScheduleInquiryProvider _provider;
  late final PageController _pageController;
  int _displayWeek = 1;

  @override
  void initState() {
    super.initState();
    _provider = getIt<ClassScheduleInquiryProvider>();
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.ensureSchedule(widget.classInfo);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToWeek(int week) {
    final target = week.clamp(1, _totalWeeks);
    if (target == _displayWeek) return;
    _pageController.animateToPage(
      target - 1,
      duration: _pageTransitionDuration,
      curve: AppCurves.quick,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.classInfo.className),
            Text(
              widget.classInfo.planName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) => _buildBody(context, l10n),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final detail = _provider.detailStateFor(widget.classInfo);
    if (detail.state == ClassScheduleInquiryLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (detail.error != null) {
      return RetryableErrorWidget(
        errorType: detail.error!,
        onRetry: () => _provider.refreshSchedule(widget.classInfo),
      );
    }

    if (detail.courses.isEmpty) {
      return Center(
        child: Text(
          l10n.classScheduleInquiryNoSchedule,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final hasWeekend = detail.courses.any((c) => c.dayOfWeek > 5);
    final rowHeight = getIt<AppConfigProvider>().courseRowHeight.value;
    const headerHeight = 40.0;
    const int totalPeriods = 12;
    final gridHeight = headerHeight + totalPeriods * rowHeight;

    // 川大标准时段 4-5-3：CourseGrid 依据这三个值在第 4、9 节后
    // 绘制加粗分隔线，区分上午 / 下午 / 晚上。
    const int morningSections = 4;
    const int afternoonSections = 5;
    final int eveningSections =
        totalPeriods - morningSections - afternoonSections;

    // 学期起点仅占位：查询页隐去日期表头，不参与任何日期计算。
    final gridConfig = ScheduleConfig(
      semesterStartDate: DateTime(2025, 9, 1),
      morningSections: morningSections,
      afternoonSections: afternoonSections,
      eveningSections: eveningSections,
      timeSlots: [],
    );

    return Column(
      children: [
        _buildWeekSwitchBar(l10n),
        Expanded(
          child: CourseSwipePageView(
            controller: _pageController,
            itemCount: _totalWeeks,
            animationDuration: _pageTransitionDuration,
            onPageChanged: (index) {
              setState(() => _displayWeek = index + 1);
            },
            itemBuilder: (context, index) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(2, 2, 2, 16),
                child: SizedBox(
                  height: gridHeight,
                  child: CourseGrid(
                    onCourseTap: _showCourseDetail,
                    courses: detail.courses.map(_toCourse).toList(),
                    config: gridConfig,
                    displayWeek: index + 1,
                    totalWeeks: _totalWeeks,
                    // 历年学期日期无意义，用仅周几的最小表头。
                    showHeaderDates: false,
                    // 班级详情只在网格局部决定是否显示周末，
                    // 不能改写用户主课表偏好。
                    showWeekendOverride: hasWeekend,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCourseDetail(Course course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppShapes.largeIncreased),
        ),
      ),
      builder: (context) => CourseDetailSheet(course: course),
    );
  }

  /// 周次切换条：上一周 / 周数 / 下一周，配合网格左右滑动翻页。
  Widget _buildWeekSwitchBar(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _displayWeek > 1
                ? () => _goToWeek(_displayWeek - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Expanded(
            child: Text(
              l10n.currentWeek(_displayWeek),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: _displayWeek < _totalWeeks
                ? () => _goToWeek(_displayWeek + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  /// 将 API 课程项转为 Course 对象。
  Course _toCourse(ClassScheduleInquiryItem item) {
    final (startWeek, endWeek, weekType) = parseWeeks(item.weeksDescription);
    return Course(
      name: item.courseName,
      teacher: item.teacherName,
      location: [
        item.building,
        item.classroom,
      ].where((s) => s.isNotEmpty).join(' '),
      startWeek: startWeek,
      endWeek: endWeek,
      dayOfWeek: item.dayOfWeek,
      startSection: item.startPeriod,
      endSection: item.startPeriod + item.duration - 1,
      colorValue: _getCourseColor(item.courseCode).toARGB32(),
      weekType: weekType,
    );
  }

  Color _getCourseColor(String courseCode) {
    final hash = courseCode.hashCode;
    final colors = [
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.indigo,
      Colors.green,
      Colors.deepOrange,
      Colors.cyan,
      Colors.brown,
    ];
    return colors[hash.abs() % colors.length];
  }
}
