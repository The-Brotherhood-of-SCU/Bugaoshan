import 'package:flutter/foundation.dart';

import 'package:bugaoshan/models/graduate_train_plan.dart';
import 'package:bugaoshan/services/api/gs_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/graduate_train_plan_progress.dart';

/// 研究生培养方案/培养进度加载状态。
enum GraduateTrainPlanLoadState { idle, loading, loaded, error }

/// 研究生培养进度失败原因，决定错误态的文案与动作。
enum GraduateTrainPlanErrorKind {
  /// 统一认证未登录，或研教务会话已过期（自愈重试后仍失败）。
  unauthenticated,

  /// 网络 / 接口 / 解析等其它错误，[GraduateTrainPlanProvider.errorMessage]
  /// 带接口层原文。
  failed,
}

/// 研究生培养进度（GraduateTrainPlanPage）状态。
///
/// 数据链（2026-09-21 抓包定案，见 graduate_train_plan_progress.dart）：
/// - `wdxx.do` → 方案基本信息（方案名/方案代码/培养层次/审核状态）；
/// - `wdkclbtj.do` → 方案要求：总计要求学分 ZDXF + 每课程类别要求；
/// - `wdfakcxx.do` → 方案课程明细（KCDM → 课程类别归属）；
/// - `xscjcx.do` → 成绩行，**及格且有效**的课视为已修（重修去重）。
/// 总进度分子 = 方案内已修（graduateTrainPlanEarnedInPlan），与分母
/// ZDXF 同口径；方案外单列展示不计入分子。
/// 前三个为 GET 无参零信封（success/reListData/reMapData），走
/// _getZeroJson 自愈链；成绩走信封分页链。
class GraduateTrainPlanProvider extends ChangeNotifier {
  GraduateTrainPlanProvider(this._gsApi);

  final GsApiService _gsApi;

  GraduateTrainPlanLoadState _state = GraduateTrainPlanLoadState.idle;
  GraduateTrainPlanErrorKind? _errorKind;
  String? _errorMessage;
  int _generation = 0;

  GraduateTrainPlanInfo? _info;
  GraduateTrainPlanCreditStats? _creditStats;
  List<TrainPlanProgressSection> _sections = const [];
  double _earnedInPlan = 0.0;

  GraduateTrainPlanLoadState get state => _state;
  GraduateTrainPlanErrorKind? get errorKind => _errorKind;
  String? get errorMessage => _errorMessage;
  GraduateTrainPlanInfo? get info => _info;
  GraduateTrainPlanCreditStats? get creditStats => _creditStats;
  List<TrainPlanProgressSection> get sections => _sections;

  /// 方案内已修学分（与 [GraduateTrainPlanCreditStats.requiredCredits]
  /// 同口径，作总进度分子；方案外单列展示不计入）。
  double get earnedInPlan => _earnedInPlan;

  Future<void> ensureLoaded() => refresh();

  Future<void> refresh() async {
    if (_state == GraduateTrainPlanLoadState.loading) return;
    final generation = ++_generation;
    _state = GraduateTrainPlanLoadState.loading;
    _errorKind = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final info = await _gsApi.fetchTrainPlanInfo();
      if (generation != _generation) return;
      final (stats, categories) = await _gsApi.fetchTrainPlanCreditStats();
      if (generation != _generation) return;
      final planCourses = await _gsApi.fetchTrainPlanCourses();
      if (generation != _generation) return;
      final gradeRows = await _gsApi.fetchGrades();
      if (generation != _generation) return;

      final sections = graduateTrainPlanSections(
        categories: categories,
        planCourses: planCourses,
        gradeRows: gradeRows,
      );
      _info = info;
      _creditStats = stats;
      _sections = sections;
      _earnedInPlan = graduateTrainPlanEarnedInPlan(sections);
      _state = GraduateTrainPlanLoadState.loaded;
      _errorKind = null;
      _errorMessage = null;
    } on UnauthenticatedException {
      if (generation != _generation) return;
      _state = GraduateTrainPlanLoadState.error;
      _errorKind = GraduateTrainPlanErrorKind.unauthenticated;
    } catch (e) {
      if (generation != _generation) return;
      _state = GraduateTrainPlanLoadState.error;
      _errorKind = GraduateTrainPlanErrorKind.failed;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// 登出时复位缓存。
  void clear() {
    _generation++;
    _info = null;
    _creditStats = null;
    _sections = const [];
    _earnedInPlan = 0.0;
    _state = GraduateTrainPlanLoadState.idle;
    _errorKind = null;
    _errorMessage = null;
    notifyListeners();
  }
}
