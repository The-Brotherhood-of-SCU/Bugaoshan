import 'package:flutter/foundation.dart';
import 'package:bugaoshan/pages/campus/exam_plan/models/exam_info.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

enum ExamPlanLoadState { idle, loading, loaded, error }

class ExamPlanProvider extends ChangeNotifier {
  static const String _tag = 'ExamPlanProvider';

  ExamPlanProvider(this._api);

  final ZhjwApiService _api;
  List<ExamInfo> _exams = const [];
  ExamPlanLoadState _state = ExamPlanLoadState.idle;
  LoadErrorType? _error;

  List<ExamInfo> get exams => _exams;
  ExamPlanLoadState get state => _state;
  LoadErrorType? get error => _error;

  Future<void> ensureLoaded() => load();

  Future<void> refresh() => load(forceRefresh: true);

  Future<void> load({bool forceRefresh = false}) async {
    if (_state == ExamPlanLoadState.loading) return;
    if (!forceRefresh && _state == ExamPlanLoadState.loaded) return;

    _state = ExamPlanLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final exams = await _api.fetchExamPlan();
      if (_state != ExamPlanLoadState.loading) return;
      _exams = exams;
      _state = ExamPlanLoadState.loaded;
    } on UnauthenticatedException catch (e, logStackTrace) {
      AppLog.e(_tag, 'load 失败', error: e, stackTrace: logStackTrace);
      if (_state != ExamPlanLoadState.loading) return;
      _state = ExamPlanLoadState.error;
      // 未登录 → notLoggedIn 让页面展示登录引导；统一认证已登录但本科教务
      // 始终踢回登录页（研究生账号）→ undergradOnly 给针对性指引。
      _error = zhjwAuthErrorType(e, fallback: LoadErrorType.notLoggedIn);
    } catch (error, logStackTrace) {
      AppLog.e(_tag, 'load 失败', error: error, stackTrace: logStackTrace);
      if (_state != ExamPlanLoadState.loading) return;

      _state = ExamPlanLoadState.error;
      _error = campusNetworkErrorType(LoadErrorType.loadFailed);
    }
    notifyListeners();
  }

  void clear() {
    _exams = const [];
    _state = ExamPlanLoadState.idle;
    _error = null;
    notifyListeners();
  }
}
