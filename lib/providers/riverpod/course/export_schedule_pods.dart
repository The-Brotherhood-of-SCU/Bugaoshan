import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/export_schedule_provider.dart' as legacy;
import 'package:bugaoshan/providers/riverpod/course/course_pods.dart';

part 'export_schedule_pods.g.dart';

@riverpod
legacy.ExportScheduleProvider exportSchedule(
  Ref ref, {
  ScheduleConfig? overrideConfig,
  List<Course>? overrideCourses,
}) {
  final courseProv = ref.watch(courseProvider);
  return legacy.ExportScheduleProvider(
    courseProv,
    overrideConfig: overrideConfig,
    overrideCourses: overrideCourses,
  );
}
