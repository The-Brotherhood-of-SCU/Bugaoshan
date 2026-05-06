import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bugaoshan/models/course.dart';

const String _boxMetadata = 'metadata';
const String _keyCurrentScheduleId = 'currentScheduleId';
const String _keySchedules = 'schedules';
const String _keyScheduleConfig = 'scheduleConfig';

class DatabaseService {
  Box? _metadataBox;
  Box? _coursesBox;

  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    Hive.init(dir.path);

    await Hive.openBox(_boxMetadata);
    _metadataBox = Hive.box(_boxMetadata);

    var currentId =
        _metadataBox!.get(_keyCurrentScheduleId, defaultValue: 'default')
            as String;

    if (!_metadataBox!.containsKey(_keySchedules)) {
      await Hive.openBox('courses');
      final oldCoursesBox = Hive.box('courses');
      final jsonStr = oldCoursesBox.get(_keyScheduleConfig) as String?;

      ScheduleConfig defaultConfig;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          defaultConfig = ScheduleConfig.fromJson(_decodeJson(jsonStr));
          defaultConfig.id = 'default';
          if (defaultConfig.semesterName.isEmpty) {
            defaultConfig.semesterName = '默认课表';
          }
        } catch (_) {
          defaultConfig = _defaultScheduleConfig();
        }
      } else {
        defaultConfig = _defaultScheduleConfig();
      }

      await _metadataBox!.put(_keySchedules, [
        _encodeJson(defaultConfig.toJson()),
      ]);
      await _metadataBox!.put(_keyCurrentScheduleId, 'default');
      currentId = 'default';
      _coursesBox = oldCoursesBox;
    } else {
      await _switchCoursesBox(currentId);
    }
  }

  Future<void> _switchCoursesBox(String scheduleId) async {
    if (_coursesBox != null && _coursesBox!.isOpen) {
      await _coursesBox!.close();
    }
    final boxName = scheduleId == 'default' ? 'courses' : 'courses_$scheduleId';
    await Hive.openBox(boxName);
    _coursesBox = Hive.box(boxName);
  }

  String getCurrentScheduleId() {
    return _metadataBox!.get(_keyCurrentScheduleId, defaultValue: 'default')
        as String;
  }

  Future<void> switchSchedule(String scheduleId) async {
    await _metadataBox!.put(_keyCurrentScheduleId, scheduleId);
    await _switchCoursesBox(scheduleId);
  }

  List<ScheduleConfig> getAllSchedules() {
    final list = _metadataBox!.get(_keySchedules) as List<dynamic>?;
    if (list == null || list.isEmpty) return [_defaultScheduleConfig()];

    return list
        .map((e) => ScheduleConfig.fromJson(_decodeJson(e as String)))
        .toList();
  }

  ScheduleConfig getScheduleConfig() {
    final currentId = getCurrentScheduleId();
    final schedules = getAllSchedules();
    return schedules.firstWhere(
      (s) => s.id == currentId,
      orElse: () => schedules.first,
    );
  }

  Future<void> saveScheduleConfig(ScheduleConfig config) async {
    final schedules = getAllSchedules();
    final index = schedules.indexWhere((s) => s.id == config.id);
    if (index >= 0) {
      schedules[index] = config;
    } else {
      schedules.add(config);
    }
    await _saveSchedulesList(schedules);
  }

  Future<void> addSchedule(ScheduleConfig config) async {
    final schedules = getAllSchedules();
    schedules.add(config);
    await _saveSchedulesList(schedules);
  }

  Future<void> deleteSchedule(String scheduleId) async {
    final schedules = getAllSchedules()..removeWhere((s) => s.id == scheduleId);
    await _saveSchedulesList(schedules);

    final boxName = scheduleId == 'default' ? 'courses' : 'courses_$scheduleId';
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).close();
    }
    if (await Hive.boxExists(boxName)) {
      await Hive.deleteBoxFromDisk(boxName);
    }

    if (getCurrentScheduleId() == scheduleId && schedules.isNotEmpty) {
      await switchSchedule(schedules.first.id);
    }
  }

  Future<void> _saveSchedulesList(List<ScheduleConfig> schedules) async {
    final list = schedules.map((s) => _encodeJson(s.toJson())).toList();
    await _metadataBox!.put(_keySchedules, list);
  }

  List<Course> getCourses({String? scheduleId}) {
    if (scheduleId != null) {
      final boxName = scheduleId == 'default'
          ? 'courses'
          : 'courses_$scheduleId';
      if (Hive.isBoxOpen(boxName)) {
        return _coursesFromBox(Hive.box(boxName));
      }
      return [];
    }

    if (_coursesBox == null || !_coursesBox!.isOpen) return [];
    return _coursesFromBox(_coursesBox!);
  }

  Future<void> addCourse(Course course) async {
    await _coursesBox!.put(course.id, course.toJson());
  }

  Future<void> updateCourse(Course course) async {
    await _coursesBox!.put(course.id, course.toJson());
  }

  Future<void> deleteCourse(String courseId) async {
    await _coursesBox!.delete(courseId);
  }

  Future<List<Course>> getCoursesAsync({String? scheduleId}) async {
    if (scheduleId == null) return getCourses();

    final boxName = scheduleId == 'default' ? 'courses' : 'courses_$scheduleId';
    if (Hive.isBoxOpen(boxName)) {
      return getCourses(scheduleId: scheduleId);
    }

    final box = await Hive.openBox(boxName);
    final courses = _coursesFromBox(box);
    await box.close();
    return courses;
  }

  Future<bool> hasConflict(Course course, {String? excludeId}) async {
    return getCourses().any(
      (c) => c.conflictsWith(course, excludeId: excludeId),
    );
  }

  Future<void> clearAllCourseData() async {
    await _coursesBox!.clear();
  }

  List<Course> _coursesFromBox(Box box) {
    return box.values
        .whereType<Map>()
        .map((e) => Course.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  ScheduleConfig _defaultScheduleConfig() {
    final now = DateTime.now();
    return ScheduleConfig(
      id: 'default',
      semesterName: '默认课表',
      semesterStartDate: now.toMonday(),
      totalWeeks: 20,
    );
  }

  Map<String, dynamic> _decodeJson(String str) =>
      Map<String, dynamic>.from(json.decode(str) as Map);

  String _encodeJson(Map<String, dynamic> map) => json.encode(map);
}
