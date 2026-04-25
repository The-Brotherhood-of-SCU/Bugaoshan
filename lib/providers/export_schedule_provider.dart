import 'dart:convert';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/ics_service.dart';

enum ExportAction { copy, ics }

enum ExportResult { success, failed, canceled }

class ExportScheduleProvider {
  final CourseProvider _courseProvider;
  File? _tempFile;

  ExportScheduleProvider(this._courseProvider);

  factory ExportScheduleProvider.create() =>
      ExportScheduleProvider(getIt<CourseProvider>());

  Future<ExportResult> copyToClipBoard() async {
    final config = _courseProvider.scheduleConfig.value;
    final allCourses = _courseProvider.courses.value;

    final data = {
      'config': config.toJson(),
      'courses': allCourses.map((e) => e.toJson()).toList(),
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

    final config = _courseProvider.scheduleConfig.value;
    final courses = _courseProvider.courses.value;
    final icsContent = IcsService.genIcs(
      config: config,
      courses: courses,
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

    final semesterName = _courseProvider.scheduleConfig.value.semesterName;
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
