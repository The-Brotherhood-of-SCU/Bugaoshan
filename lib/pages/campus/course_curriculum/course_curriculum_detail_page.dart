import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/campus/models/course_curriculum_model.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_curriculum_provider.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/pages/course/widgets/course_detail_sheet.dart';
import 'package:bugaoshan/pages/course/widgets/course_grid.dart';
import 'package:bugaoshan/utils/week_parser.dart';

/// 课程课表详情页 - 以课表网格展示某门课程（教学班）的排课
class CourseCurriculumDetailPage extends StatefulWidget {
  final CourseSectionInfo courseInfo;

  const CourseCurriculumDetailPage({super.key, required this.courseInfo});

  @override
  State<CourseCurriculumDetailPage> createState() =>
      _CourseCurriculumDetailPageState();
}

class _CourseCurriculumDetailPageState
    extends State<CourseCurriculumDetailPage> {
  late final CourseCurriculumProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = getIt<CourseCurriculumProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.ensureSchedule(widget.courseInfo);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.courseInfo.courseName),
            Text(
              '${widget.courseInfo.planName} · ${widget.courseInfo.courseSeq}',
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
    final detail = _provider.detailStateFor(widget.courseInfo);
    if (detail.state == CourseCurriculumLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (detail.error != null) {
      return RetryableErrorWidget(
        errorType: detail.error!,
        onRetry: () => _provider.refreshSchedule(widget.courseInfo),
      );
    }

    if (detail.courses.isEmpty) {
      return Center(
        child: Text(
          l10n.courseCurriculumNoSchedule,
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

    // showAllWeeks 模式不读取 semesterStartDate，设任意值即可。
    // 课程详情只在当前网格局部决定是否显示周末，不能改写用户主课表偏好。
    final gridConfig = ScheduleConfig(
      semesterStartDate: DateTime(2025, 9, 1),
      morningSections: morningSections,
      afternoonSections: afternoonSections,
      eveningSections: eveningSections,
      timeSlots: [],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: gridHeight,
            child: CourseGrid(
              onCourseTap: (course) {
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
              },
              courses: detail.courses.map(_toCourse).toList(),
              config: gridConfig,
              displayWeek: 1,
              showAllWeeks: true,
              showWeekendOverride: hasWeekend,
            ),
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
    // hashCode 为 int 最小负数时 abs() 溢出仍为负，取模得负索引会越界，
    // 用掩码清符号位保证非负。
    return colors[(hash & 0x7fffffff) % colors.length];
  }
}
