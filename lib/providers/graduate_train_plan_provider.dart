import 'package:flutter/foundation.dart';

import 'package:bugaoshan/models/graduate_train_plan.dart';
import 'package:bugaoshan/services/api/gs_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';

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
/// 数据链（2026-09-21 应用抓包定案，见 wdpyjhapp index.js 与模拟机实测）：
/// - `wdxx.do` → 方案基本信息（方案名/方案代码/培养层次/审核状态）；
/// - `wdkclbtj.do` → 分类学分统计：`reMapData` 给总计（已选 YXXF / 要求
///   ZDXF / 方案内 FANYXXF / 方案外 FAWYXXF），`reListData` 给每类
///   （已选 YXXF / 要求 ZDXF / 已选门数 YXMS）；
/// - `wdfakcxx.do` → 方案内课程明细（按课程类别分组的fakcxx[]）。
/// 全部为 GET 无参零信封（success/reListData/reMapData），走 _getZeroJson
/// 自愈链。
class GraduateTrainPlanProvider extends ChangeNotifier {
  GraduateTrainPlanProvider(this._gsApi);

  final GsApiService _gsApi;

  GraduateTrainPlanLoadState _state = GraduateTrainPlanLoadState.idle;
  GraduateTrainPlanErrorKind? _errorKind;
  String? _errorMessage;
  int _generation = 0;

  GraduateTrainPlanInfo? _info;
  GraduateTrainPlanCreditStats? _creditStats;
  List<GraduateTrainPlanCategoryProgress> _categories = const [];
  List<GraduateTrainPlanCourse> _courses = const [];

  GraduateTrainPlanLoadState get state => _state;
  GraduateTrainPlanErrorKind? get errorKind => _errorKind;
  String? get errorMessage => _errorMessage;
  GraduateTrainPlanInfo? get info => _info;
  GraduateTrainPlanCreditStats? get creditStats => _creditStats;
  List<GraduateTrainPlanCategoryProgress> get categories => _categories;
  List<GraduateTrainPlanCourse> get courses => _courses;

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
      final courses = await _gsApi.fetchTrainPlanCourses();
      if (generation != _generation) return;
      _info = info;
      _creditStats = stats;
      _categories = categories;
      _courses = courses;
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
    _categories = const [];
    _courses = const [];
    _state = GraduateTrainPlanLoadState.idle;
    _errorKind = null;
    _errorMessage = null;
    notifyListeners();
  }
}
