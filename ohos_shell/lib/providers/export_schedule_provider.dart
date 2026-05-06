import 'dart:convert';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/ics_service.dart';
import 'package:path_provider/path_provider.dart';

enum ExportAction { copy, ics, addToCalendar }

enum ExportResult { success, failed, canceled }

class ExportScheduleProvider {
  final CourseProvider _courseProvider;
  // When override fields are set, they take precedence over the current schedule.
  // This allows exporting a non-active schedule from schedule management page.
  final ScheduleConfig? _overrideConfig;
  final List<Course>? _overrideCourses;

  String? _icsContent;

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
    final jsonStr = json.encode(data);

    try {
      await Clipboard.setData(ClipboardData(text: jsonStr));
      debugPrint("[copyToClipBoard] clipboard written success");
      return ExportResult.success;
    } on PlatformException catch (e) {
      debugPrint("[copyToClipBoard] platform related exception: $e");
    } catch (e) {
      debugPrint("[copyToClipBoard] other exception: $e");
    }
    return ExportResult.failed;
  }

  // Return the semester name for ues by the file picker after .ics generation
  String genIcs(String teacherLabel) {
    _icsContent = IcsService.genIcs(
      config: _config,
      courses: _courses,
      teacherLabel: teacherLabel,
    );
    debugPrint("[genIcs] .ics generated successfully");

    final semesterName = _config.semesterName;
    // replace dangerous characters by _
    final safeSemesterName = semesterName.replaceAll(
      RegExp(r'[^\w\u4e00-\u9fff]'),
      '_',
    );
    return safeSemesterName;
  }

  Uint8List getIcsBytes() {
    return Uint8List.fromList(utf8.encode(_icsContent!));
  }

  /// Save ICS content to cache directory and return the file path.
  /// Used for Android one-click calendar import.
  Future<String> saveIcsToCache(String teacherLabel) async {
    genIcs(teacherLabel);
    final cacheDir = await getTemporaryDirectory();
    final semesterName = _config.semesterName.replaceAll(
      RegExp(r'[^\w\u4e00-\u9fff]'),
      '_',
    );
    final file = File('${cacheDir.path}/$semesterName.ics');
    await file.writeAsString(_icsContent!);
    debugPrint("[saveIcsToCache] ICS saved to ${file.path}");
    return file.path;
  }
}
