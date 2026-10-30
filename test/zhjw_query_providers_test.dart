import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/pages/campus/exam_plan/models/exam_info.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/pages/campus/models/classroom_model.dart';
import 'package:bugaoshan/providers/class_schedule_inquiry_provider.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/campus/classroom_pods.dart';
import 'package:bugaoshan/providers/exam_plan_provider.dart';
import 'package:bugaoshan/scu_backend/zhjw/zhjw_api_service.dart';

void main() {
  test(
    'ClassroomAvailabilityNotifier caches availability by building and date',
    () async {
      final api = _FakeZhjwApiService();
      final container = ProviderContainer(
        overrides: [zhjwApiServiceBridge.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final res1 = await container.read(
        classroomAvailabilityProvider(
          campusNumber: 'A',
          buildingNumber: '1',
          searchDate: '2026-01-01',
        ).future,
      );
      final res2 = await container.read(
        classroomAvailabilityProvider(
          campusNumber: 'A',
          buildingNumber: '1',
          searchDate: '2026-01-01',
        ).future,
      );
      final res3 = await container.read(
        classroomAvailabilityProvider(
          campusNumber: 'A',
          buildingNumber: '1',
          searchDate: '2026-01-02',
        ).future,
      );

      expect(api.availabilityCalls, 2);
      expect(res1.classrooms, isNotEmpty);
      expect(res2.classrooms, isNotEmpty);
      expect(res3.classrooms, isNotEmpty);
    },
  );

  test('ClassroomAvailabilityNotifier refreshes a cached query', () async {
    final api = _ControllableClassroomApi();
    final container = ProviderContainer(
      overrides: [zhjwApiServiceBridge.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    final initialQuery = container.read(
      classroomAvailabilityProvider(
        campusNumber: 'A',
        buildingNumber: '1',
        searchDate: '2026-01-01',
      ).future,
    );
    api.requests.single.complete(_classroomResult('old'));
    final initialResult = await initialQuery;
    expect(initialResult.classrooms.single.classroomName, 'old');

    final refresh = container
        .read(
          classroomAvailabilityProvider(
            campusNumber: 'A',
            buildingNumber: '1',
            searchDate: '2026-01-01',
          ).notifier,
        )
        .refresh(
          campusNumber: 'A',
          buildingNumber: '1',
          searchDate: '2026-01-01',
        );
    expect(api.requests, hasLength(2));
    api.requests.last.complete(_classroomResult('new'));
    await refresh;

    final updated = await container.read(
      classroomAvailabilityProvider(
        campusNumber: 'A',
        buildingNumber: '1',
        searchDate: '2026-01-01',
      ).future,
    );
    expect(updated.classrooms.single.classroomName, 'new');
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

ClassroomQueryResult _classroomResult(String name) => ClassroomQueryResult(
  classrooms: [
    ClassroomInfo(
      classroomName: name,
      classroomStatusCode: '',
      classroomTypeCode: '',
      campusNumber: 'campus',
      classroomNumber: name,
      teachingBuildingNumber: name,
      placeNum: 0,
      remark: '',
      sfkjy: '',
    ),
  ],
  classroomTime: const [],
  date: '2026-01-01',
  jxzc: 1,
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
      classrooms: [
        ClassroomInfo(
          classroomName: 'A101',
          classroomStatusCode: '1',
          classroomTypeCode: '01',
          campusNumber: campusNumber,
          classroomNumber: '101',
          teachingBuildingNumber: buildingNumber,
          placeNum: 50,
          remark: '',
          sfkjy: '1',
        ),
      ],
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

class _ControllableClassroomApi implements ZhjwApiService {
  final requests = <Completer<ClassroomQueryResult>>[];

  @override
  Future<ClassroomQueryResult> fetchClassroomAvailability({
    required String campusNumber,
    required String buildingNumber,
    String classroomType = '',
    String classroomName = '',
    String seatFrom = '',
    String seatTo = '',
    String searchDate = '',
  }) {
    final completer = Completer<ClassroomQueryResult>();
    requests.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
