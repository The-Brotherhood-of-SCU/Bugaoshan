import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/utils/app_shapes.dart';
import 'package:bugaoshan/utils/week_parser.dart';
import 'package:bugaoshan/widgets/course/course_grid.dart';
import 'package:bugaoshan/widgets/course/course_detail_sheet.dart';

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
  LoadErrorType? _error;

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
        _error = LoadErrorType.sessionExpired;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ClassScheduleInquiry detail load error: $e');
      if (!mounted) return;
      setState(() {
        _error = campusNetworkErrorType(LoadErrorType.loadFailed);
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
      return RetryableErrorWidget(errorType: _error!, onRetry: _loadSchedule);
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

    // showAllWeeks 模式不读取 semesterStartDate，设任意值即可
    // 显示设置（showTeacherName/showLocation/showWeekend）已迁移到 AppConfigProvider
    getIt<AppConfigProvider>().showWeekend.value = hasWeekend;
    final gridConfig = ScheduleConfig(
      semesterStartDate: DateTime(2025, 9, 1),
      morningSections: 0,
      afternoonSections: 0,
      eveningSections: totalPeriods,
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
              courses: _courses.map(_toCourse).toList(),
              config: gridConfig,
              displayWeek: 1,
              showAllWeeks: true,
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
    return colors[hash.abs() % colors.length];
  }
}
