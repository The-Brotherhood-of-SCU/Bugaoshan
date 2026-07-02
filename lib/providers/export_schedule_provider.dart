import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/ics_service.dart';
import 'package:bugaoshan/utils/calendar_export_utils.dart';

enum ExportResult { success, failed, canceled }

class ExportScheduleProvider {
  final CourseProvider _courseProvider;
  // When override fields are set, they take precedence over the current schedule.
  // This allows exporting a non-active schedule from schedule management page.
  final ScheduleConfig? _overrideConfig;
  final List<Course>? _overrideCourses;

  ExportScheduleProvider(
    this._courseProvider, {
    ScheduleConfig? overrideConfig,
    List<Course>? overrideCourses,
  }) : _overrideConfig = overrideConfig,
       _overrideCourses = overrideCourses;

  factory ExportScheduleProvider.create() =>
      ExportScheduleProvider(getIt<CourseProvider>());

  factory ExportScheduleProvider.forSchedule(
    ScheduleConfig config,
    List<Course> courses,
  ) => ExportScheduleProvider(
    getIt<CourseProvider>(),
    overrideConfig: config,
    overrideCourses: courses,
  );

  ScheduleConfig get _config =>
      _overrideConfig ?? _courseProvider.scheduleConfig.value;
  List<Course> get _courses =>
      _overrideCourses ?? _courseProvider.courses.value;

  Future<ExportResult> copyToClipBoard() async {
    final data = {
      'config': _config.toJson(),
      'courses': _courses.map((e) => e.toJson()).toList(),
    };
    final success = await CalendarExportUtils.copyJsonToClipboard(
      data,
      logTag: 'copyToClipBoard',
    );
    return success ? ExportResult.success : ExportResult.failed;
  }

  CalendarExportPayload buildCalendarPayload(String teacherLabel) {
    return IcsService.genCourseExportPayload(
      config: _config,
      courses: _courses,
      teacherLabel: teacherLabel,
    );
  }
}
