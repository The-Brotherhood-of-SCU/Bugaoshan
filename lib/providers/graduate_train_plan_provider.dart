import 'package:flutter/foundation.dart';

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
/// 骨架阶段端点未定案（待抓包）：[refresh] 只复位状态、不发无效请求，
/// 页面呈现「暂无培养进度数据」空态；端点、模型与解析随后一并补上。
/// 文案已锁定目标 UI（graduateTrainPlan* 全套 l10n）：培养进度总览
/// 「已修 X / 要求 Y 学分」+ 各模块「已修/要求」+ 模块课程列表。
class GraduateTrainPlanProvider extends ChangeNotifier {
  GraduateTrainPlanLoadState _state = GraduateTrainPlanLoadState.idle;
  GraduateTrainPlanErrorKind? _errorKind;
  String? _errorMessage;
  int _generation = 0;

  GraduateTrainPlanLoadState get state => _state;
  GraduateTrainPlanErrorKind? get errorKind => _errorKind;
  String? get errorMessage => _errorMessage;

  Future<void> ensureLoaded() => refresh();

  Future<void> refresh() async {
    if (_state == GraduateTrainPlanLoadState.loading) return;
    final generation = ++_generation;
    _state = GraduateTrainPlanLoadState.loading;
    _errorKind = null;
    _errorMessage = null;
    notifyListeners();

    // TODO(gs-api): 培养进度 .do 端点定案后，在这里走 GsApiService
    // （_postForm 自愈链）取数、解析并填充模块进度；骨架阶段不发无效
    // 请求，直接回到 loaded 空态。
    if (generation != _generation) return;
    _state = GraduateTrainPlanLoadState.loaded;
    notifyListeners();
  }

  /// 登出时复位缓存。
  void clear() {
    _generation++;
    _state = GraduateTrainPlanLoadState.idle;
    _errorKind = null;
    _errorMessage = null;
    notifyListeners();
  }
}
