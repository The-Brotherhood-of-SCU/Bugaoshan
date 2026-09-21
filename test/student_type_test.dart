import 'package:bugaoshan/models/campus_item_config.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppConfigProvider.studentType 持久化', () {
    test('默认为本科生', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final provider = AppConfigProvider(preferences);
      await provider.init();

      expect(provider.studentType.value, StudentType.undergraduate);
    });

    test('切换研究生后持久化，重启恢复', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final provider = AppConfigProvider(preferences);
      await provider.init();

      provider.studentType.value = StudentType.graduate;
      expect(preferences.getInt('studentType'), StudentType.graduate.index);

      // 模拟重启：同一份持久化数据加载新实例。
      final restored = AppConfigProvider(preferences);
      await restored.init();
      expect(restored.studentType.value, StudentType.graduate);
    });

    test('越界索引回退为本科生', () async {
      SharedPreferences.setMockInitialValues({'studentType': 99});
      final preferences = await SharedPreferences.getInstance();
      final provider = AppConfigProvider(preferences);
      await provider.init();

      expect(provider.studentType.value, StudentType.undergraduate);
    });
  });

  group('campusSectionsForStudentType 按身份过滤', () {
    List<String> sectionItemIds(List<CampusSection> sections) => [
      for (final section in sections)
        for (final item in section.items) item.id,
    ];

    test('本科生模式：含全部教务功能，研究生条目隐藏', () {
      final ids = sectionItemIds(
        campusSectionsForStudentType(StudentType.undergraduate),
      );

      // 本科教务专属项全部可见。
      for (final id in [
        dockIdGrades,
        dockIdPlanCompletion,
        dockIdExamPlan,
        dockIdTrainProgram,
        dockIdClassScheduleInquiry,
        dockIdCourseCurriculum,
        dockIdClassroom,
      ]) {
        expect(ids, contains(id));
      }
      // 研究生专属项不可见。
      expect(ids, isNot(contains(dockIdGraduateGrades)));
      expect(ids, isNot(contains(dockIdGraduateTrainPlan)));
      expect(ids, isNot(contains(dockIdGraduateScheduleImport)));
    });

    test('研究生模式：教务功能隐藏，研究生条目可见', () {
      final ids = sectionItemIds(
        campusSectionsForStudentType(StudentType.graduate),
      );

      for (final id in [
        dockIdGrades,
        dockIdPlanCompletion,
        dockIdExamPlan,
        dockIdTrainProgram,
        dockIdClassScheduleInquiry,
        dockIdCourseCurriculum,
        dockIdClassroom,
      ]) {
        expect(ids, isNot(contains(id)));
      }
      // 研究生专属项全部可见：成绩、培养进度、课表导入。
      expect(
        ids,
        containsAll([
          dockIdGraduateGrades,
          dockIdGraduateTrainPlan,
          dockIdGraduateScheduleImport,
        ]),
      );
    });

    test('通用功能两种身份都可见，且过滤后无空分区', () {
      for (final type in StudentType.values) {
        final sections = campusSectionsForStudentType(type);
        expect(sections, isNotEmpty);
        for (final section in sections) {
          expect(section.items, isNotEmpty, reason: '身份 $type 下分区不应为空');
        }
        final ids = sectionItemIds(sections);
        for (final id in [
          dockIdCcyl,
          dockIdFitnessTest,
          dockIdNetworkDevice,
          dockIdBalanceQuery,
          dockIdRepair,
          dockIdAcademicCalendar,
          dockIdNotice,
          dockIdDownloadedAttachments,
        ]) {
          expect(ids, contains(id), reason: '通用项 $id 在身份 $type 下应可见');
        }
      }
    });
  });

  group('allCampusItemsForStudentType', () {
    test('dock 三项（课程/校园/我的）两种身份都在', () {
      for (final type in StudentType.values) {
        final ids = [
          for (final item in allCampusItemsForStudentType(type)) item.id,
        ];
        expect(ids, containsAll([dockIdCourse, dockIdCampus, dockIdProfile]));
      }
    });
  });
}
