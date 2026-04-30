import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';

class WidgetUpdateService {
  final CourseProvider _courseProvider;
  final AppConfigProvider _appConfig;

  static const _widgetProviders = [
    'CourseWidgetProviderSmall',
    'CourseWidgetProviderMedium',
    'CourseWidgetProviderLarge',
  ];

  WidgetUpdateService(this._courseProvider, this._appConfig);

  Future<void> updateWidgetData() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _writeTodayCourses();
      await _triggerWidgetUpdate();
    } catch (e) {
      debugPrint('WidgetUpdateService: failed to update widget: $e');
    }
  }

  Future<void> _writeTodayCourses() async {
    final config = _courseProvider.scheduleConfig.value;
    final allCourses = _courseProvider.courses.value;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeek = config.getCurrentWeek();
    final dayOfWeek = now.weekday; // 1=Mon ... 7=Sun

    // Filter courses for today
    final todayCourses = allCourses
        .where((c) => c.dayOfWeek == dayOfWeek && c.isActiveInWeek(currentWeek))
        .toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));

    // Build JSON array with resolved time strings
    final coursesJson = todayCourses.map((c) {
      final startTime = _formatTime(config.timeSlots, c.startSection);
      final endTime = _formatTime(config.timeSlots, c.endSection);
      return {
        'name': c.name,
        'teacher': c.teacher,
        'location': c.location,
        'startSection': c.startSection,
        'endSection': c.endSection,
        'startTime': startTime,
        'endTime': endTime,
        'colorValue': c.colorValue,
      };
    }).toList();

    // Localized strings
    final locale = _appConfig.locale.value;
    final isZh = locale != null && locale.languageCode == 'zh';
    final dayNames = isZh
        ? ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = dayNames[dayOfWeek - 1];
    final weekPrefix = isZh ? '第' : 'W';
    final weekSuffix = isZh ? '周' : '';
    final noCoursesText = isZh ? '今天没有课程' : 'No courses today';
    final sectionPrefix = isZh ? '第' : '';
    final sectionSuffix = isZh ? '节' : '';
    final headerTitle = isZh ? '不高山上' : 'Bugaoshan';

    final dateText = '${now.month}/$now.day $dayName';
    final weekText = '$weekPrefix$currentWeek$weekSuffix';

    // Save all data
    await Future.wait([
      HomeWidget.saveWidgetData('widget_courses_json', jsonEncode(coursesJson)),
      HomeWidget.saveWidgetData('widget_current_week', currentWeek),
      HomeWidget.saveWidgetData(
          'widget_theme_color', _appConfig.themeColor.value.toARGB32()),
      HomeWidget.saveWidgetData('widget_schedule_name', config.semesterName),
      HomeWidget.saveWidgetData('widget_date_text', dateText),
      HomeWidget.saveWidgetData('widget_week_text', weekText),
      HomeWidget.saveWidgetData('widget_no_courses_text', noCoursesText),
      HomeWidget.saveWidgetData('widget_section_prefix', sectionPrefix),
      HomeWidget.saveWidgetData('widget_section_suffix', sectionSuffix),
      HomeWidget.saveWidgetData('widget_header_title', headerTitle),
    ]);
  }

  String _formatTime(List<TimeSlot> timeSlots, int section) {
    if (section < 1 || section > timeSlots.length) return '--:--';
    final slot = timeSlots[section - 1];
    return '${slot.startTime.hour.toString().padLeft(2, '0')}:'
        '${slot.startTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _triggerWidgetUpdate() async {
    for (final provider in _widgetProviders) {
      await HomeWidget.updateWidget(
        qualifiedAndroidName:
            'io.github.the_brotherhood_of_scu.bugaoshan.$provider',
      );
    }
  }
}
