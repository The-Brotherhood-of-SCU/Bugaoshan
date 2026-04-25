import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/course_provider.dart';

enum ExportAction { copy, ics }

enum ExportResult { success, failed, canceled }

class ExportScheduleProvider {
  final CourseProvider _courseProvider;

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
}
