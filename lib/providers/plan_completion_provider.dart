import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/pages/campus/plan_completion/models/plan_completion.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

const _keyPlanCompletion = 'plan_completion_nodes';

enum PlanCompletionLoadState { idle, loading, loaded, error }

class PlanCompletionProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final ZhjwApiService _zhjwApi;
  int _requestGeneration = 0;

  PlanCompletionProvider(this._prefs, this._zhjwApi) {
    final cached = _prefs.getString(_keyPlanCompletion);
    if (cached != null) {
      try {
        final list = jsonDecode(cached) as List<dynamic>;
        _plans = _decodeCached(list);
        _state = PlanCompletionLoadState.loaded;
      } catch (e) {
        debugPrint('PlanCompletionProvider cache decode error: $e');
      }
    }
  }

  List<PlanCompletionPlan> _plans = [];
  int _currentPlanIndex = 0;
  PlanCompletionLoadState _state = PlanCompletionLoadState.idle;
  LoadErrorType? _error;

  /// 全部培养方案（单方案时为 1 个元素；无方案时为空列表）。
  List<PlanCompletionPlan> get plans => _plans;

  /// 当前方案索引（多方案滑动切换后更新，用于页面方案名指示）。
  int get currentPlanIndex => _currentPlanIndex;

  /// 当前方案的节点列表（无方案时为空）。
  List<PlanCompletionNode> get nodes =>
      _plans.isEmpty ? const [] : _plans[_currentPlanIndex].nodes;

  PlanCompletionLoadState get state => _state;
  LoadErrorType? get error => _error;

  List<PlanCompletionNode> get rootNodes =>
      nodes.where((n) => n.pId == '-1').toList();

  List<PlanCompletionNode> getChildren(String parentId) =>
      nodes.where((n) => n.pId == parentId).toList();

  /// 切换当前方案（越界忽略）。
  void selectPlan(int index) {
    if (index < 0 || index >= _plans.length) return;
    if (index == _currentPlanIndex) return;
    _currentPlanIndex = index;
    _safeNotify();
  }

  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Future<void> fetchPlanCompletion({bool forceRefresh = false}) async {
    if (_state == PlanCompletionLoadState.loading) return;

    // Use cache if already loaded and not forcing refresh
    if (!forceRefresh && _state == PlanCompletionLoadState.loaded) return;
    final generation = ++_requestGeneration;

    _state = PlanCompletionLoadState.loading;
    _error = null;
    _safeNotify();

    try {
      final plans = await _zhjwApi.fetchPlanCompletion();
      if (generation != _requestGeneration) return;
      _plans = plans;
      // 若已滑到最后一个方案且刷新后方案变少，回退到 0，避免越界。
      if (_currentPlanIndex >= _plans.length) _currentPlanIndex = 0;
      _state = PlanCompletionLoadState.loaded;
      _error = null;
      await _saveToCache();
      if (generation != _requestGeneration) return;
    } on RateLimitedException catch (_) {
      if (generation != _requestGeneration) return;
      if (_plans.isNotEmpty) {
        _state = PlanCompletionLoadState.loaded;
      } else {
        _state = PlanCompletionLoadState.error;
      }
      _error = LoadErrorType.rateLimited;
    } on ServiceException catch (_) {
      if (generation != _requestGeneration) return;
      if (_plans.isNotEmpty) {
        _state = PlanCompletionLoadState.loaded;
        _error = campusNetworkErrorType(LoadErrorType.loadFailed);
      } else {
        _state = PlanCompletionLoadState.error;
        _error = campusNetworkErrorType(LoadErrorType.loadFailed);
      }
    } on UnauthenticatedException {
      if (generation != _requestGeneration) return;
      if (_plans.isNotEmpty) {
        _state = PlanCompletionLoadState.loaded;
      } else {
        _state = PlanCompletionLoadState.error;
      }
      _error = LoadErrorType.sessionExpired;
    } catch (_) {
      if (generation != _requestGeneration) return;
      if (_plans.isNotEmpty) {
        _state = PlanCompletionLoadState.loaded;
      } else {
        _state = PlanCompletionLoadState.error;
      }
      _error = campusNetworkErrorType(LoadErrorType.loadFailed);
    }
    _safeNotify();
  }

  Future<void> _saveToCache() async {
    final json = jsonEncode(
      _plans
          .map(
            (p) => {
              'id': p.id,
              'name': p.name,
              'nodes': p.nodes.map((n) => _nodeToJson(n)).toList(),
            },
          )
          .toList(),
    );
    await _prefs.setString(_keyPlanCompletion, json);
  }

  /// 缓存解析：优先按新格式（元素含 id/name/nodes 字段）。
  /// 兼容旧格式（元素本身是节点对象）——将整个列表视为单方案，
  /// 避免旧缓存全量失效。
  List<PlanCompletionPlan> _decodeCached(List<dynamic> list) {
    if (list.isEmpty) return const [];
    final isNewFormat = list.every(
      (e) => e is Map<String, dynamic> && e['nodes'] is List,
    );
    if (isNewFormat) {
      return list.map((e) {
        final map = e as Map<String, dynamic>;
        final nodes = (map['nodes'] as List)
            .map((n) => PlanCompletionNode.fromJson(n as Map<String, dynamic>))
            .toList();
        return PlanCompletionPlan(
          id: map['id'] as String? ?? '',
          name: map['name'] as String? ?? '',
          nodes: nodes,
        );
      }).toList();
    }
    // 旧缓存：直接是节点数组，包装为单个方案
    final nodes = list
        .map((e) => PlanCompletionNode.fromJson(e as Map<String, dynamic>))
        .toList();
    return [PlanCompletionPlan(id: '', name: '', nodes: nodes)];
  }

  Map<String, dynamic> _nodeToJson(PlanCompletionNode node) => {
    'id': node.id,
    'pId': node.pId,
    'flagId': node.flagId,
    'flagType': node.flagType,
    'name': node.rawName,
    'sfwc': node.completed ? '是' : '否',
    'yxxf': node.earnedCredits,
    'zsxf': node.requiredCredits,
  };

  Future<void> clearCache() async {
    _requestGeneration++;
    _plans = [];
    _currentPlanIndex = 0;
    _state = PlanCompletionLoadState.idle;
    _error = null;
    _safeNotify();
    await _prefs.remove(_keyPlanCompletion);
  }
}
