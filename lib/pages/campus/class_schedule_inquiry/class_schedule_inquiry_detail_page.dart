import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/course/course_card.dart';

/// 班级课表详情页 - 以课表网格展示班级课程
class ClassScheduleInquiryDetailPage extends StatefulWidget {
  final ClassInfo classInfo;

  const ClassScheduleInquiryDetailPage({super.key, required this.classInfo});

  @override
  State<ClassScheduleInquiryDetailPage> createState() =>
      _ClassScheduleInquiryDetailPageState();
}

class _ClassScheduleInquiryDetailPageState
    extends State<ClassScheduleInquiryDetailPage> {
  late final ZhjwApiService _zhjwApi;
  List<ClassScheduleInquiryItem> _courses = [];
  bool _isLoading = true;
  String? _error;

  static const List<String> _dayLabels = [
    '',
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  @override
  void initState() {
    super.initState();
    _zhjwApi = getIt<ZhjwApiService>();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final courses = await _zhjwApi.fetchClassSchedule(
        planCode: widget.classInfo.planCode,
        classCode: widget.classInfo.classCode,
      );
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } on UnauthenticatedException catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'sessionExpired';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ClassScheduleInquiry detail load error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'loadFailed';
        _isLoading = false;
      });
    }
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
      body: _buildBody(context, l10n),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error == 'sessionExpired'
                  ? l10n.sessionExpired
                  : l10n.loadFailed,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadSchedule, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    if (_courses.isEmpty) {
      return Center(
        child: Text(
          l10n.classScheduleInquiryNoSchedule,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScheduleGrid(context),
          const SizedBox(height: 24),
          Text(
            l10n.classScheduleInquiryDetail,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildCourseList(context),
        ],
      ),
    );
  }

  Widget _buildScheduleGrid(BuildContext context) {
    final theme = Theme.of(context);

    // 检测是否有周末课程，决定显示5天还是7天
    final hasWeekend = _courses.any((c) => c.dayOfWeek > 5);
    final dayCount = hasWeekend ? 7 : 5;

    // Build a map: dayOfWeek -> (startPeriod -> [courses])
    final Map<int, Map<int, List<ClassScheduleInquiryItem>>> gridMap = {};
    for (final course in _courses) {
      gridMap.putIfAbsent(course.dayOfWeek, () => {});
      for (
        int p = course.startPeriod;
        p < course.startPeriod + course.duration;
        p++
      ) {
        gridMap[course.dayOfWeek]!.putIfAbsent(p, () => []);
        if (gridMap[course.dayOfWeek]![p]!.length < 2) {
          gridMap[course.dayOfWeek]![p]!.add(course);
        }
      }
    }

    const double sectionWidth = 35;
    const double rowHeight = 72;
    const int totalPeriods = 12;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header row
        SizedBox(
          height: 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: sectionWidth,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ),
              ...List.generate(dayCount, (dayIndex) {
                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        right: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _dayLabels[dayIndex + 1],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        // Grid content: section column + dayCount day stacks
        SizedBox(
          height: totalPeriods * rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionColumn(
                context,
                totalPeriods,
                sectionWidth,
                rowHeight,
              ),
              Expanded(
                child: Row(
                  children: List.generate(dayCount, (dayIndex) {
                    return Expanded(
                      child: _buildDayColumn(
                        context,
                        dayIndex + 1,
                        gridMap,
                        totalPeriods,
                        rowHeight,
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionColumn(
    BuildContext context,
    int totalPeriods,
    double sectionWidth,
    double rowHeight,
  ) {
    final theme = Theme.of(context);
    return SizedBox(
      width: sectionWidth,
      child: Column(
        children: List.generate(totalPeriods, (i) {
          final period = i + 1;
          return Container(
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: Center(
              child: Text(
                '$period',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    int dayOfWeek,
    Map<int, Map<int, List<ClassScheduleInquiryItem>>> gridMap,
    int totalPeriods,
    double rowHeight,
  ) {
    final theme = Theme.of(context);

    // Collect unique courses for this day
    final dayCourses = <ClassScheduleInquiryItem>{};
    for (int p = 1; p <= totalPeriods; p++) {
      final courses = gridMap[dayOfWeek]?[p] ?? [];
      dayCourses.addAll(courses);
    }

    return SizedBox(
      height: totalPeriods * rowHeight,
      child: Stack(
        children: [
          // Grid lines
          ...List.generate(totalPeriods, (i) {
            return Positioned(
              top: i * rowHeight,
              left: 0,
              right: 0,
              height: rowHeight,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                      width: 0.5,
                    ),
                    right: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            );
          }),
          // Course cards
          ...dayCourses.map((course) {
            final top = (course.startPeriod - 1) * rowHeight;
            final courseHeight = course.duration * rowHeight - 2;
            return Positioned(
              top: top + 1,
              left: 1,
              right: 1,
              height: courseHeight,
              child: _buildCourseCell(context, course),
            );
          }),
        ],
      ),
    );
  }

  /// 将 API 课程项转为 Course 对象供 CourseCard 使用。
  /// 班级课表不涉及周次切换，固定 1-20 周 + every 即可保证始终可见。
  Course _toCourse(ClassScheduleInquiryItem item) {
    return Course(
      name: item.courseName,
      teacher: item.teacherName,
      location: [
        item.building,
        item.classroom,
      ].where((s) => s.isNotEmpty).join(' '),
      startWeek: 1,
      endWeek: 20,
      dayOfWeek: item.dayOfWeek,
      startSection: item.startPeriod,
      endSection: item.startPeriod + item.duration - 1,
      colorValue: _getCourseColor(item.courseCode).toARGB32(),
      weekType: WeekType.every,
    );
  }

  Widget _buildCourseCell(BuildContext context, ClassScheduleInquiryItem item) {
    final course = _toCourse(item);
    // semesterStartDate 不影响显示：displayWeek=1 且 weekType=every 时
    // CourseCard 不依赖实际日期计算，保持无状态即可。
    final config = ScheduleConfig(
      semesterStartDate: DateTime(2025, 9, 1),
      showTeacherName: true,
      showLocation: true,
    );
    return Padding(
      padding: const EdgeInsets.all(1),
      child: CourseCard(course: course, config: config, displayWeek: 1),
    );
  }

  Widget _buildCourseList(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: _courses.asMap().entries.map((entry) {
        final course = entry.value;
        final color = _getCourseColor(course.courseCode);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.courseName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${course.courseCode} · ${course.courseSeq}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        Icons.person_outline,
                        course.teacherName,
                        theme,
                      ),
                      _buildInfoRow(
                        Icons.date_range,
                        course.weeksDescription,
                        theme,
                      ),
                      if (course.classroom.isNotEmpty)
                        _buildInfoRow(
                          Icons.room_outlined,
                          [
                            course.campus,
                            course.building,
                            course.classroom,
                          ].where((s) => s.isNotEmpty).join(' '),
                          theme,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, ThemeData theme) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
