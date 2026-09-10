import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/pages/campus/models/course_curriculum_model.dart';
import 'package:bugaoshan/providers/class_schedule_inquiry_provider.dart';
import 'package:bugaoshan/providers/course_curriculum_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';

void main() {
  test('CourseCurriculumProvider loadMore 失败后重试仍请求同一页', () async {
    final api = _FakeCurriculumApi(totalCount: 60, failPages: {2});
    final provider = CourseCurriculumProvider(api);

    await provider.search();
    expect(provider.courses, hasLength(30));
    expect(provider.hasMore, isTrue);

    // 第 2 页请求失败：列表与页码都保持不动，等待重试。
    await provider.loadMore();
    expect(api.requestedPages, [1, 2]);
    expect(provider.courses, hasLength(30));
    expect(provider.coursesError, isNotNull);
    expect(provider.hasMore, isTrue);

    // 重试时不应跳过第 2 页。
    await provider.loadMore();
    expect(api.requestedPages, [1, 2, 2]);
    expect(provider.courses, hasLength(60));
    expect(provider.coursesState, CourseCurriculumLoadState.loaded);
    expect(provider.coursesError, isNull);
    expect(provider.hasMore, isFalse);
  });

  test('CourseCurriculumProvider isLoadingMore 区分首页与加载更多', () async {
    final api = _ControllableCurriculumApi();
    final provider = CourseCurriculumProvider(api);

    final searchFuture = provider.search();
    expect(provider.isLoadingMore, isFalse);
    api.requests.single.complete((courses: _courses(30), totalCount: 60));
    await searchFuture;

    final moreFuture = provider.loadMore();
    expect(provider.isLoadingMore, isTrue);
    api.requests.last.complete((courses: _courses(30), totalCount: 60));
    await moreFuture;
    expect(provider.isLoadingMore, isFalse);
  });

  test('CourseCurriculumProvider 详情缓存按 LRU 淘汰', () async {
    final api = _FakeCurriculumApi();
    final provider = CourseCurriculumProvider(api);
    final courses = List.generate(51, (i) => _course(code: 'C$i'));

    for (var i = 0; i < 50; i++) {
      await provider.loadSchedule(courses[i]);
    }
    // 访问最早加载的 courses[0]，使其成为最近使用的条目。
    provider.detailStateFor(courses[0]);
    // 第 51 个条目触发淘汰，被淘汰的应是最久未使用的 courses[1]。
    await provider.loadSchedule(courses[50]);

    expect(
      provider.detailStateFor(courses[0]).state,
      CourseCurriculumLoadState.loaded,
    );
    expect(
      provider.detailStateFor(courses[1]).state,
      CourseCurriculumLoadState.idle,
    );
    expect(
      provider.detailStateFor(courses[50]).state,
      CourseCurriculumLoadState.loaded,
    );
  });

  test('ClassScheduleInquiryProvider loadMore 失败后重试仍请求同一页', () async {
    final api = _FakeInquiryApi(totalCount: 60, failPages: {2});
    final provider = ClassScheduleInquiryProvider(api);

    await provider.search();
    expect(provider.classes, hasLength(30));

    await provider.loadMore();
    expect(api.requestedPages, [1, 2]);
    expect(provider.classes, hasLength(30));
    expect(provider.classesError, isNotNull);

    await provider.loadMore();
    expect(api.requestedPages, [1, 2, 2]);
    expect(provider.classes, hasLength(60));
    expect(provider.classesState, ClassScheduleInquiryLoadState.loaded);
  });
}

CourseSectionInfo _course({String code = 'C001'}) => CourseSectionInfo(
  planCode: '2026-2027-1-1',
  planName: '',
  courseCode: code,
  courseName: '课程$code',
  courseSeq: '01',
  credits: '',
  category: '',
  examType: '',
  department: '',
  teachers: '',
);

List<CourseSectionInfo> _courses(int count) =>
    List.generate(count, (i) => _course(code: 'C$i'));

class _FakeCurriculumApi implements ZhjwApiService {
  _FakeCurriculumApi({this.totalCount = 0, this.failPages = const {}});

  final int totalCount;

  /// 每个页码只失败一次，模拟瞬时网络错误，重试可恢复。
  final Set<int> failPages;
  final _failedOnce = <int>{};
  final requestedPages = <int>[];

  @override
  Future<({List<CourseSectionInfo> courses, int totalCount})> fetchCourseList({
    int pageNum = 1,
    int pageSize = 30,
    String semester = '',
    String department = '',
    String courseName = '',
    String courseCode = '',
    String courseSeq = '',
    String category = '',
  }) async {
    requestedPages.add(pageNum);
    if (failPages.contains(pageNum) && _failedOnce.add(pageNum)) {
      throw Exception('模拟加载失败');
    }
    return (courses: _courses(pageSize), totalCount: totalCount);
  }

  @override
  Future<List<ClassScheduleInquiryItem>> fetchCourseSchedule({
    required String planCode,
    required String courseCode,
    required String courseSequenceCode,
  }) async {
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControllableCurriculumApi implements ZhjwApiService {
  final requests =
      <Completer<({List<CourseSectionInfo> courses, int totalCount})>>[];

  @override
  Future<({List<CourseSectionInfo> courses, int totalCount})> fetchCourseList({
    int pageNum = 1,
    int pageSize = 30,
    String semester = '',
    String department = '',
    String courseName = '',
    String courseCode = '',
    String courseSeq = '',
    String category = '',
  }) {
    final completer =
        Completer<({List<CourseSectionInfo> courses, int totalCount})>();
    requests.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInquiryApi implements ZhjwApiService {
  _FakeInquiryApi({this.totalCount = 0, this.failPages = const {}});

  final int totalCount;

  /// 每个页码只失败一次，模拟瞬时网络错误，重试可恢复。
  final Set<int> failPages;
  final _failedOnce = <int>{};
  final requestedPages = <int>[];

  @override
  Future<({List<ClassInfo> classes, int totalCount})> fetchClassList({
    int pageNum = 1,
    int pageSize = 30,
    String executiveEducationPlanNum = '',
    String yearNum = '',
    String departmentNum = '',
    String subjectNum = '',
    String classNum = '',
  }) async {
    requestedPages.add(pageNum);
    if (failPages.contains(pageNum) && _failedOnce.add(pageNum)) {
      throw Exception('模拟加载失败');
    }
    return (
      classes: List.generate(
        pageSize,
        (i) => ClassInfo(
          planCode: '2026-2027-1-1',
          classCode: 'K$i',
          planName: '',
          className: '班级$i',
          departmentName: '',
          subjectName: '',
        ),
      ),
      totalCount: totalCount,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
