import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/pages/campus/train_program/models/train_program.dart';
import 'package:bugaoshan/providers/train_program_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stale program detail cannot overwrite the latest request', () async {
    final api = _ControllableZhjwApiService();
    final provider = TrainProgramProvider(api);

    final staleRequest = provider.fetchProgramDetail('old');
    provider.clearDetail();
    final latestRequest = provider.fetchProgramDetail('new');

    api.programRequests['new']!.complete(_programDetail('new'));
    await latestRequest;
    expect(provider.currentDetail?.title, 'new');
    expect(provider.detailState, TrainProgramLoadState.loaded);

    api.programRequests['old']!.complete(_programDetail('old'));
    await staleRequest;
    expect(provider.currentDetail?.title, 'new');
    expect(provider.detailState, TrainProgramLoadState.loaded);
  });

  test('stale course detail cannot overwrite the latest request', () async {
    final api = _ControllableZhjwApiService();
    final provider = TrainProgramProvider(api);

    final staleRequest = provider.fetchCourseDetail('/old');
    provider.clearCourseDetail();
    final latestRequest = provider.fetchCourseDetail('/new');

    api.courseRequests['/new']!.complete(_courseDetail('new'));
    await latestRequest;
    expect(provider.currentCourseDetail?.kc.kcm, 'new');
    expect(provider.courseDetailState, TrainProgramLoadState.loaded);

    api.courseRequests['/old']!.complete(_courseDetail('old'));
    await staleRequest;
    expect(provider.currentCourseDetail?.kc.kcm, 'new');
    expect(provider.courseDetailState, TrainProgramLoadState.loaded);
  });
}

TrainProgramDetail _programDetail(String title) =>
    TrainProgramDetail.fromJson({'title': title});

CourseDetail _courseDetail(String name) => CourseDetail.fromJson({
  'flag': '1',
  'kc': {'kcm': name},
});

class _ControllableZhjwApiService implements ZhjwApiService {
  final programRequests = <String, Completer<TrainProgramDetail>>{};
  final courseRequests = <String, Completer<CourseDetail>>{};

  @override
  Future<TrainProgramDetail> fetchProgramDetail(String fajhh) {
    final completer = Completer<TrainProgramDetail>();
    programRequests[fajhh] = completer;
    return completer.future;
  }

  @override
  Future<CourseDetail> fetchCourseDetail(String urlPath) {
    final completer = Completer<CourseDetail>();
    courseRequests[urlPath] = completer;
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
