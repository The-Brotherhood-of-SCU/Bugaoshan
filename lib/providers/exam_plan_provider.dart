import 'package:flutter/foundation.dart';
import 'package:bugaoshan/pages/campus/exam_plan/models/exam_info.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

enum ExamPlanLoadState { idle, loading, loaded, error }

class ExamPlanProvider extends ChangeNotifier {
  ExamPlanProvider(this._api);

  final ZhjwApiService _api;
  List<ExamInfo> _exams = const [];
  ExamPlanLoadState _state = ExamPlanLoadState.idle;
  LoadErrorType? _error;
  int _generation = 0;

  List<ExamInfo> get exams => _exams;
  ExamPlanLoadState get state => _state;
  LoadErrorType? get error => _error;

  Future<void> ensureLoaded() => load();

  Future<void> refresh() => load(forceRefresh: true);

  Future<void> load({bool forceRefresh = false}) async {
    if (_state == ExamPlanLoadState.loading) return;
    if (!forceRefresh && _state == ExamPlanLoadState.loaded) return;

    final generation = ++_generation;
    _state = ExamPlanLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final exams = await _api.fetchExamPlan();
      if (generation != _generation) return;
      _exams = exams;
      _state = ExamPlanLoadState.loaded;
    } on UnauthenticatedException {
      if (generation != _generation) return;
      _state = ExamPlanLoadState.error;
      // 与其它 Provider 不同，这里用 notLoggedIn 以便页面在未登录时
      // 直接展示登录引导（LoginRequiredWidget），而非仅提示会话过期。
      _error = LoadErrorType.notLoggedIn;
    } catch (error) {
      if (generation != _generation) return;
      debugPrint('Exam plan load error: $error');
      _state = ExamPlanLoadState.error;
      _error = campusNetworkErrorType(LoadErrorType.loadFailed);
    }
    notifyListeners();
  }

  void clear() {
    _generation++;
    _exams = const [];
    _state = ExamPlanLoadState.idle;
    _error = null;
    notifyListeners();
  }
}
