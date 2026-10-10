import 'package:flutter/foundation.dart';
import 'package:bugaoshan/models/graduate_grades.dart';
import 'package:bugaoshan/services/api/gs_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/graduate_grades_parser.dart';

/// 研究生成绩加载状态。
enum GraduateGradesLoadState { idle, loading, loaded, error }

/// 研究生成绩失败原因，决定错误态的文案与动作。
enum GraduateGradesErrorKind {
  /// 统一认证未登录，或研教务会话已过期（自愈重试后仍失败）。
  unauthenticated,

  /// 网络 / 接口 / 解析等其它错误，[GraduateGradesProvider.errorMessage]
  /// 带接口层原文。
  failed,
}

/// 研究生成绩（GraduateGradesPage）状态。
///
/// 数据链：[GsApiService.fetchGrades]（`_postForm` 自愈链）→
/// [graduateGradeRowsFromJson] → [graduateGradesStatsFromRows]。
class GraduateGradesProvider extends ChangeNotifier {
  GraduateGradesProvider(this._gsApi);

  final GsApiService _gsApi;

  GraduateGradesLoadState _state = GraduateGradesLoadState.idle;
  GraduateGradesErrorKind? _errorKind;
  String? _errorMessage;
  List<GraduateGradeRow> _rows = const [];
  GraduateGradesStats? _stats;
  int _generation = 0;

  GraduateGradesLoadState get state => _state;
  GraduateGradesErrorKind? get errorKind => _errorKind;
  String? get errorMessage => _errorMessage;

  /// 原始成绩行（明细列表后续接入时用）。
  List<GraduateGradeRow> get rows => _rows;

  GraduateGradesStats? get stats => _stats;

  Future<void> ensureLoaded() => refresh();

  Future<void> refresh() async {
    if (_state == GraduateGradesLoadState.loading) return;
    final generation = ++_generation;
    _state = GraduateGradesLoadState.loading;
    _errorKind = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final rows = await _gsApi.fetchGrades();
      if (generation != _generation) return;
      _rows = rows;
      _stats = graduateGradesStatsFromRows(rows);
      _state = GraduateGradesLoadState.loaded;
    } on UnauthenticatedException {
      if (generation != _generation) return;
      _state = GraduateGradesLoadState.error;
      _errorKind = GraduateGradesErrorKind.unauthenticated;
    } catch (e) {
      if (generation != _generation) return;
      AppLog.e('GraduateGradesProvider', 'Load error: $e');
      _state = GraduateGradesLoadState.error;
      _errorKind = GraduateGradesErrorKind.failed;
      _errorMessage = e is ServiceException ? e.message : null;
    }
    notifyListeners();
  }

  /// 登出时复位缓存。
  void clear() {
    _generation++;
    _rows = const [];
    _stats = null;
    _state = GraduateGradesLoadState.idle;
    _errorKind = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// 仅供测试：直接注入统计，驱动统计分支的 UI 验证。
  @visibleForTesting
  void debugSeedStats(GraduateGradesStats stats) {
    _rows = const [];
    _stats = stats;
    _state = GraduateGradesLoadState.loaded;
    notifyListeners();
  }
}
