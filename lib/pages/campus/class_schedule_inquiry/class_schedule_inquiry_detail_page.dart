import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/course/course_grid.dart';

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

  /// 将教务系统周次描述解析为 Course 的周次参数。
  /// zcsm 格式如 "1-10周"、"1-10,12周"、"1-16(单)" 等。
  (int startWeek, int endWeek, WeekType weekType) _parseWeeks(String zcsm) {
    if (zcsm.isEmpty) return (1, 20, WeekType.every);
    final text = zcsm.replaceAll('周', '').trim();
    WeekType weekType = WeekType.every;
    if (text.contains('单')) weekType = WeekType.odd;
    if (text.contains('双')) weekType = WeekType.even;
    final numbers = text.replaceAll(RegExp(r'[^\d,\-]'), '');
    final parts = numbers.split(',');
    int startWeek = 1, endWeek = 20;
    for (final part in parts) {
      final range = part.split('-');
      if (range.length == 2) {
        final s = int.tryParse(range[0]);
        final e = int.tryParse(range[1]);
        if (s != null && e != null) {
          if (startWeek == 1 || s < startWeek) startWeek = s;
          if (endWeek == 20 || e > endWeek) endWeek = e;
        }
      }
    }
    return (startWeek, endWeek, weekType);
  }

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

    final hasWeekend = _courses.any((c) => c.dayOfWeek > 5);
    final rowHeight = getIt<AppConfigProvider>().courseRowHeight.value;
    const headerHeight = 40.0;
    const int totalPeriods = 12;
    final gridHeight = headerHeight + totalPeriods * rowHeight;

    final gridConfig = ScheduleConfig(
      semesterStartDate: DateTime(2025, 9, 1),
      showTeacherName: true,
      showLocation: true,
      showWeekend: hasWeekend,
      morningSections: 0,
      afternoonSections: 0,
      eveningSections: totalPeriods,
      timeSlots: [],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: gridHeight,
            child: CourseGrid(
              courses: _courses.map(_toCourse).toList(),
              config: gridConfig,
              displayWeek: 1,
              totalWeeks: 20,
              showAllWeeks: true,
            ),
          ),
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

  /// 将 API 课程项转为 Course 对象。
  Course _toCourse(ClassScheduleInquiryItem item) {
    final (startWeek, endWeek, weekType) = _parseWeeks(item.weeksDescription);
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
