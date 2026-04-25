import 'dart:convert';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/ics_service.dart';

enum ExportAction { copy, ics }

enum ExportResult { success, failed, canceled }

class ExportScheduleProvider {
  final CourseProvider _courseProvider;
  // When override fields are set, they take precedence over the current schedule.
  // This allows exporting a non-active schedule from schedule management page.
  final ScheduleConfig? _overrideConfig;
  final List<Course>? _overrideCourses;

  File? _tempFile;

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

  // Return the semester name for ues by the file picker while writing a temporary file
  // Return null if failed to write a temp file
  Future<String?> saveIcsToTempFile(String teacherLabel) async {
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (e) {
      debugPrint("[saveIcsToTempFile] failed find temp dir: $e");
      return null;
    }
    final tempFileName =
        'course_schedule_${DateTime.now().millisecondsSinceEpoch}.ics';
    final tempFile = File('${tempDir.path}/$tempFileName');

    final icsContent = IcsService.genIcs(
      config: _config,
      courses: _courses,
      teacherLabel: teacherLabel,
    );

    try {
      await tempFile.writeAsString(icsContent);
    } catch (e) {
      debugPrint("[saveIcsToTempFile] failed to write temp file: $e");
      return null;
    }
    _tempFile = tempFile;
    debugPrint("[saveIcsToTempFile] temp file saved to ${tempFile.path}");

    final semesterName = _config.semesterName;
    // replace dangerous characters by _
    final safeSemesterName = semesterName.replaceAll(
      RegExp(r'[^\w\u4e00-\u9fff]'),
      '_',
    );
    return safeSemesterName;
  }

  Future<ExportResult> moveTempToDestination(String destinationPath) async {
    try {
      await _tempFile!.copy(destinationPath);
      debugPrint("[moveTempToDestination] temp moved to $destinationPath");
      await cleanTempFile();
    } catch (e) {
      debugPrint("[moveTempToDestination] $e");
      await cleanTempFile();
      return ExportResult.failed;
    }
    return ExportResult.success;
  }

  Future<void> cleanTempFile() async {
    try {
      await _tempFile?.delete();
      debugPrint("[cleanTempFile] temp cleaned");
    } catch (e) {
      debugPrint("[cleanTempFile] $e");
    }
    _tempFile = null;
  }
}
