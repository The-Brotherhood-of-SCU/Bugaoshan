import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/class_schedule_inquiry_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/pages/course/widgets/course_detail_sheet.dart';
import 'package:bugaoshan/pages/course/widgets/course_grid.dart';
import 'package:bugaoshan/utils/week_parser.dart';

/// 班级课表详情页 - 以课表网格按周展示班级课程
class ClassScheduleInquiryDetailPage extends StatefulWidget {
  final ClassInfo classInfo;

  const ClassScheduleInquiryDetailPage({super.key, required this.classInfo});

  @override
  State<ClassScheduleInquiryDetailPage> createState() =>
      _ClassScheduleInquiryDetailPageState();
}

class _ClassScheduleInquiryDetailPageState
    extends State<ClassScheduleInquiryDetailPage> {
  late final ClassScheduleInquiryProvider _provider;
  late int _displayWeek;
  late int _actualWeek;
  late int _totalWeeks;

  /// 用户主课表的学期起点，用于表头日期与今天对齐；无配置时为 null。
  DateTime? _userSemesterStart;

  @override
  void initState() {
    super.initState();
    _provider = getIt<ClassScheduleInquiryProvider>();
    _initWeekState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.ensureSchedule(widget.classInfo);
    });
  }

  /// 借用用户主课表的学期配置推算当前周作为初始周次，
  /// 让轮换课（同节次不同周）只显示所选周的那一门。
  /// 查询其他学期的班级课表时，可通过切换条手动改周。
  void _initWeekState() {
    final config = getIt<CourseProvider>().scheduleConfig.value;
    _userSemesterStart = config?.semesterStartDate;
    final total = config?.totalWeeks ?? kDefaultTotalWeeks;
    _totalWeeks = total < 1 ? 1 : total;
    _actualWeek = (config?.getCurrentWeek() ?? 1).clamp(1, _totalWeeks);
    _displayWeek = _actualWeek;
  }

  void _goToWeek(int week) {
    setState(() {
      _displayWeek = week.clamp(1, _totalWeeks);
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

    // 学期起点借用用户主课表的配置，保证表头日期与今天对齐；
    // 没有配置时退回本周一（第 1 周 = 当前日历周）。
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fallbackStart = today.subtract(
      Duration(days: (today.weekday - DateTime.monday) % 7),
    );
    final gridConfig = ScheduleConfig(
      semesterStartDate: _userSemesterStart ?? fallbackStart,
      totalWeeks: _totalWeeks,
      morningSections: morningSections,
      afternoonSections: afternoonSections,
      eveningSections: eveningSections,
      timeSlots: [],
    );

    return Column(
      children: [
        _buildWeekSwitchBar(l10n),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 16),
            child: SizedBox(
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
                displayWeek: _displayWeek,
                totalWeeks: _totalWeeks,
                // 班级详情只在当前网格局部决定是否显示周末，
                // 不能改写用户主课表偏好。
                showWeekendOverride: hasWeekend,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 周次切换条：上一周 / 周数 / 本周徽章 / 下一周。
  /// 不在当前周时，点周数或徽章可回到当前周。
  Widget _buildWeekSwitchBar(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onActualWeek = _displayWeek == _actualWeek;

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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onActualWeek ? null : () => _goToWeek(_actualWeek),
              child: Text(
                l10n.currentWeek(_displayWeek),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onActualWeek ? null : () => _goToWeek(_actualWeek),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: onActualWeek
                    ? scheme.primaryContainer
                    : scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppShapes.full),
              ),
              child: Text(
                onActualWeek
                    ? l10n.thisWeek
                    : l10n.actualCurrentWeek(_actualWeek),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: onActualWeek
                      ? scheme.onPrimaryContainer
                      : scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
                ),
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
