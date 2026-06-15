import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/pages/campus/plan_completion/models/plan_completion.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/campus_network_required_widget.dart';

const _keyPlanCompletion = 'plan_completion_nodes';

enum PlanCompletionLoadState { idle, loading, loaded, error }

class PlanCompletionProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final ZhjwApiService _zhjwApi;

  PlanCompletionProvider(this._prefs, this._zhjwApi) {
    final cached = _prefs.getString(_keyPlanCompletion);
    if (cached != null) {
      try {
        final list = jsonDecode(cached) as List<dynamic>;
        _nodes = list
            .map((e) => PlanCompletionNode.fromJson(e as Map<String, dynamic>))
            .toList();
        _state = PlanCompletionLoadState.loaded;
      } catch (_) {}
    }
  }

  List<PlanCompletionNode> _nodes = [];
  PlanCompletionLoadState _state = PlanCompletionLoadState.idle;
  String? _error;

  List<PlanCompletionNode> get nodes => _nodes;
  PlanCompletionLoadState get state => _state;
  String? get error => _error;

  List<PlanCompletionNode> get rootNodes =>
      _nodes.where((n) => n.pId == '-1').toList();

  List<PlanCompletionNode> getChildren(String parentId) =>
      _nodes.where((n) => n.pId == parentId).toList();

  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Future<void> fetchPlanCompletion({bool forceRefresh = false}) async {
    if (_state == PlanCompletionLoadState.loading) return;

    // Use cache if already loaded and not forcing refresh
    if (!forceRefresh && _state == PlanCompletionLoadState.loaded) return;

    _state = PlanCompletionLoadState.loading;
    _error = null;
    _safeNotify();

    try {
      _nodes = await _zhjwApi.fetchPlanCompletion();
      _state = PlanCompletionLoadState.loaded;
      _error = null;
      await _saveToCache();
    } on RateLimitedException catch (_) {
      if (_nodes.isNotEmpty) {
        _state = PlanCompletionLoadState.loaded;
      } else {
        _state = PlanCompletionLoadState.error;
      }
      _error = 'rateLimited';
    } on ServiceException catch (_) {
      if (_nodes.isNotEmpty) {
        _state = PlanCompletionLoadState.loaded;
        _error = campusNetworkErrorKey('loadFailed');
      } else {
        _state = PlanCompletionLoadState.error;
        _error = campusNetworkErrorKey('loadFailed');
      }
    } on UnauthenticatedException {
      if (_nodes.isNotEmpty) {
        _state = PlanCompletionLoadState.loaded;
      } else {
        _state = PlanCompletionLoadState.error;
      }
      _error = 'sessionExpired';
    } catch (_) {
      if (_nodes.isNotEmpty) {
        _state = PlanCompletionLoadState.loaded;
      } else {
        _state = PlanCompletionLoadState.error;
      }
      _error = campusNetworkErrorKey('loadFailed');
    }
    _safeNotify();
  }

  Future<void> _saveToCache() async {
    final json = jsonEncode(_nodes.map((n) => _nodeToJson(n)).toList());
    await _prefs.setString(_keyPlanCompletion, json);
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
    _nodes = [];
    _state = PlanCompletionLoadState.idle;
    _error = null;
    await _prefs.remove(_keyPlanCompletion);
  }
}
