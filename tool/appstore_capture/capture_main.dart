// Screenshot-only entry point. Never use this target for a distributed build.
import 'package:bugaoshan/main.dart' as production;
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/widgets/eula_content.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  enableFlutterDriverExtension(enableTextEntryEmulation: false);
  WidgetsApp.debugAllowBannerOverride = false;

  // Ordinary persisted preferences in a fresh, disposable simulator. No auth.
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString('locale', 'zh-CN');
  await preferences.setBool('firstLaunchWizardCompleted', true);
  await preferences.setInt('acceptedEulaVersion', currentEulaVersion);
  await preferences.setBool('useGoogleFonts', false);
  await preferences.setBool('campusGridView', true);
  await preferences.setBool('showWeekend', false);
  await preferences.setInt('themeColorMode', 2);
  await preferences.setInt('themeColor', 0xFF3B82F6);

  final database = DatabaseService();
  await database.init();
  // This target runs only on newly created simulators and owns all sample data.
  await database.clearAllCourseData();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  const scheduleId = 'appstore-fictional-example';
  await database.addSchedule(
    ScheduleConfig(
      id: scheduleId,
      semesterName: '示例课表（虚构数据）',
      semesterStartDate: monday.subtract(const Duration(days: 7)),
      totalWeeks: 20,
    ),
  );
  await database.switchSchedule(scheduleId);
  final examples = <(String, int, int, int)>[
    ('高等数学', 1, 1, 0xFF4F83CC),
    ('大学物理', 2, 3, 0xFFAA70C6),
    ('程序设计', 3, 1, 0xFF459D83),
    ('大学英语', 4, 3, 0xFFD19749),
    ('数据结构', 5, 1, 0xFF558BB9),
    ('大学写作', 1, 5, 0xFFB56B88),
    ('体育', 2, 7, 0xFF579E8B),
    ('线性代数', 3, 5, 0xFF767CB9),
    ('创新实践', 4, 7, 0xFFB58353),
    ('通识研讨', 5, 5, 0xFF668F93),
  ];
  for (var index = 0; index < examples.length; index++) {
    final (name, day, section, color) = examples[index];
    await database.addCourse(
      Course(
        id: 'fictional-course-$index',
        name: name,
        teacher: '示例教师',
        location: '示例楼${101 + index}',
        startWeek: 1,
        endWeek: 20,
        dayOfWeek: day,
        startSection: section,
        endSection: section + 1,
        colorValue: color,
      ),
    );
  }
  // All pages, providers, layouts and native plugins below are the real app.
  await production.main();
}
