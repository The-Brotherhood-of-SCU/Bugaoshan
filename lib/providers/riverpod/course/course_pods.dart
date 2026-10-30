import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';

part 'course_pods.g.dart';

@Riverpod(keepAlive: true)
class CourseNotifier extends _$CourseNotifier {
  @override
  bool updateShouldNotify(CourseProvider previous, CourseProvider next) => true;

  @override
  CourseProvider build() {
    final CourseProvider provider;
    if (getIt.isRegistered<CourseProvider>()) {
      provider = getIt<CourseProvider>();
    } else {
      final db = ref.watch(databaseServiceBridge);
      provider = CourseProvider(db);
    }

    void onCourseChange() {
      state = provider;
    }

    provider.courses.addListener(onCourseChange);
    provider.scheduleConfig.addListener(onCourseChange);
    provider.allSchedules.addListener(onCourseChange);
    provider.isLoading.addListener(onCourseChange);

    ref.onDispose(() {
      provider.courses.removeListener(onCourseChange);
      provider.scheduleConfig.removeListener(onCourseChange);
      provider.allSchedules.removeListener(onCourseChange);
      provider.isLoading.removeListener(onCourseChange);
    });

    return provider;
  }
}

/// 当前课表课程列表
@Riverpod(keepAlive: true)
List<Course> coursesList(Ref ref) {
  final provider = ref.watch(courseProvider);
  return provider.courses.value;
}

/// 当前课表配置
@Riverpod(keepAlive: true)
ScheduleConfig? currentScheduleConfig(Ref ref) {
  final provider = ref.watch(courseProvider);
  return provider.scheduleConfig.value;
}

/// 所有课表配置列表
@Riverpod(keepAlive: true)
List<ScheduleConfig> allSchedules(Ref ref) {
  final provider = ref.watch(courseProvider);
  return provider.allSchedules.value;
}

/// 课表加载状态
@Riverpod(keepAlive: true)
bool courseIsLoading(Ref ref) {
  final provider = ref.watch(courseProvider);
  return provider.isLoading.value;
}

/// 是否存在课表
@Riverpod(keepAlive: true)
bool hasSchedule(Ref ref) {
  final schedules = ref.watch(allSchedulesProvider);
  return schedules.isNotEmpty;
}
