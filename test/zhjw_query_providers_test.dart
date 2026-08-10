import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/pages/campus/exam_plan/models/exam_info.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/pages/campus/models/classroom_model.dart';
import 'package:bugaoshan/providers/class_schedule_inquiry_provider.dart';
import 'package:bugaoshan/providers/classroom_provider.dart';
import 'package:bugaoshan/providers/exam_plan_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';

void main() {
  test('ClassroomProvider caches availability by building and date', () async {
    final api = _FakeZhjwApiService();
    final provider = ClassroomProvider(api);
    final building = ClassroomBuilding(
      campusNumber: 'A',
      teachingBuildingNumber: '1',
      teachingBuildingName: '一教',
    );

    await provider.queryAvailability(
      building: building,
      searchDate: '2026-01-01',
    );
    await provider.queryAvailability(
      building: building,
      searchDate: '2026-01-01',
    );
    await provider.queryAvailability(
      building: building,
      searchDate: '2026-01-02',
    );

    expect(api.availabilityCalls, 2);
    expect(provider.queryState, ClassroomLoadState.loaded);
  });

  test('ClassScheduleInquiryProvider ignores stale search result', () async {
    final api = _ControllableClassListApi();
    final provider = ClassScheduleInquiryProvider(api);

    final oldSearch = provider.search();
    await Future<void>.delayed(Duration.zero);
    await provider.setSelectedGrade('2025');
    final latestSearch = provider.search();
    await Future<void>.delayed(Duration.zero);

    api.requests[1].complete((classes: [_classInfo('new')], totalCount: 1));
    await latestSearch;
    api.requests[0].complete((classes: [_classInfo('old')], totalCount: 1));
    await oldSearch;

    expect(provider.classes.single.className, 'new');
    expect(provider.classesState, ClassScheduleInquiryLoadState.loaded);
  });

  test(
    'ExamPlanProvider coalesces load and refresh replaces cached value',
    () async {
      final api = _FakeZhjwApiService();
      final provider = ExamPlanProvider(api);

      await Future.wait([provider.ensureLoaded(), provider.ensureLoaded()]);
      expect(api.examCalls, 1);

      await provider.refresh();
      expect(api.examCalls, 2);
      expect(provider.state, ExamPlanLoadState.loaded);
    },
  );
}

ClassInfo _classInfo(String name) => ClassInfo(
  planCode: 'plan',
  classCode: name,
  planName: '培养方案',
  className: name,
  departmentName: '学院',
  subjectName: '专业',
);

class _FakeZhjwApiService implements ZhjwApiService {
  int availabilityCalls = 0;
  int examCalls = 0;

  @override
  Future<ClassroomQueryResult> fetchClassroomAvailability({
    required String campusNumber,
    required String buildingNumber,
    String classroomType = '',
    String classroomName = '',
    String seatFrom = '',
    String seatTo = '',
    String searchDate = '',
  }) async {
    availabilityCalls++;
    return ClassroomQueryResult(
      classrooms: const [],
      classroomTime: const [],
      date: searchDate,
      jxzc: 1,
    );
  }

  @override
  Future<List<ExamInfo>> fetchExamPlan() async {
    examCalls++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControllableClassListApi implements ZhjwApiService {
  final requests = <Completer<({List<ClassInfo> classes, int totalCount})>>[];

  @override
  Future<({List<ClassInfo> classes, int totalCount})> fetchClassList({
    int pageNum = 1,
    int pageSize = 30,
    String executiveEducationPlanNum = '',
    String yearNum = '',
    String departmentNum = '',
    String subjectNum = '',
    String classNum = '',
  }) {
    final completer = Completer<({List<ClassInfo> classes, int totalCount})>();
    requests.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
