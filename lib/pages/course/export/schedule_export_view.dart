import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/widgets/course_grid_body.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/widgets/common/background_image_view.dart';

/// 课表导出图片的逻辑宽度。
const double kScheduleImageLogicalWidth = 420;

/// 课表导出数据封装。
@immutable
class ScheduleExportData {
  ScheduleExportData({
    required this.config,
    required List<Course> courses,
    required this.targetWeek,
  }) : courses = List<Course>.unmodifiable(courses);

  final ScheduleConfig config;
  final List<Course> courses;
  final int targetWeek;

  /// [targetWeek] 在 [1, max(1, totalWeeks)] 且 [courses] 非空。
  bool get isValid {
    final maxWeeks = math.max(1, config.totalWeeks);
    return courses.isNotEmpty && targetWeek >= 1 && targetWeek <= maxWeeks;
  }
}

/// 解析导出目标周次。
///
/// [visibleWeek] != null 时 clamp 到 [1, max(1, totalWeeks)]；
/// 否则取 [config.getCurrentWeek] 并同样 clamp 到 [1, max(1, totalWeeks)]。
int resolveExportTargetWeek(ScheduleConfig config, {int? visibleWeek}) {
  final maxWeeks = math.max(1, config.totalWeeks);
  if (visibleWeek != null) {
    return visibleWeek.clamp(1, maxWeeks);
  }
  return config.getCurrentWeek().clamp(1, maxWeeks);
}

/// 专用于离屏绘制导出的课表纯静态视图。
///
/// 特性：
/// 1) 无 SingleChildScrollView / 滚动条 / viewport 裁剪，完全自适应内容高度；
/// 2) 显式固定逻辑宽度为 [kScheduleImageLogicalWidth]；
/// 3) 交互回调全部不传，保持只读静态视图。
class ScheduleExportView extends ConsumerWidget {
  const ScheduleExportView({
    super.key,
    required this.data,
    this.backgroundImagePath,
  });

  final ScheduleExportData data;
  final String? backgroundImagePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crop = ref.watch(backgroundImageCropSettingProvider);
    final overlayOpacity = ref.watch(backgroundImageOpacitySettingProvider);
    final showWeekend = ref.watch(showWeekendSettingProvider);
    final showNonCurrentWeekCourses =
        ref.watch(showNonCurrentWeekCoursesSettingProvider);
    final rowHeight = ref.watch(courseRowHeightSettingProvider);
    final showCourseGrid = ref.watch(showCourseGridSettingProvider);

    return SizedBox(
      width: kScheduleImageLogicalWidth,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topLeft,
        children: [
          // 1) 保证 PNG 背景不透明
          Positioned.fill(
            child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
          ),

          // 2) 背景图（如果存在且已预热解码成功）
          if (backgroundImagePath != null)
            Positioned.fill(
              child: BackgroundImageView(
                path: backgroundImagePath!,
                crop: crop,
                overlayOpacity: overlayOpacity,
              ),
            ),

          // 3) 唯一的 non-positioned 子节点，决定 Stack 整体尺寸
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CourseGridHeader(
                config: data.config,
                displayWeek: data.targetWeek,
                hasBackground: backgroundImagePath != null,
                showWeekend: showWeekend,
                showAllWeeks: false,
                showHeaderDates: true,
              ),
              CourseGridBody(
                courses: data.courses,
                config: data.config,
                displayWeek: data.targetWeek,
                showWeekend: showWeekend,
                showNonCurrentWeekCourses: showNonCurrentWeekCourses,
                rowHeight: rowHeight,
                showCourseGrid: showCourseGrid,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
