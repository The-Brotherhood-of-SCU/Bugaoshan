import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/pages/campus/plan_completion/models/plan_completion.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/scu_auth_service.dart';
import 'package:bugaoshan/utils/session_expiry_handler.dart';

const _keyPlanCompletion = 'plan_completion_nodes';

enum PlanCompletionLoadState { idle, loading, loaded, error }

class PlanCompletionProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final ScuAuthProvider _authProvider;

  PlanCompletionProvider(this._prefs, this._authProvider) {
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
      final client = await _authProvider.service.bindSession();
      try {
        final resp = await client.get(
          Uri.parse(
            'http://zhjw.scu.edu.cn/student/integratedQuery/planCompletion/index',
          ),
          headers: {
            'Accept': 'text/html,*/*',
            'Referer': 'http://zhjw.scu.edu.cn/',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          },
        );

        final body = resp.body;

        // Check for rate limiting
        if (body.contains('请勿频繁刷新')) {
          if (_nodes.isNotEmpty) {
            _state = PlanCompletionLoadState.loaded;
            _error = 'rateLimited';
          } else {
            _state = PlanCompletionLoadState.error;
            _error = 'rateLimited';
          }
          return;
        }

        if (body.startsWith('<') && !body.contains('zNodes')) {
          throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
        }

        _nodes = _parseZNodes(body);
        _state = PlanCompletionLoadState.loaded;
        _error = null;
        await _saveToCache();
      } finally {
        client.close();
      }
    } on ScuLoginException catch (e) {
      if (e.sessionExpired) {
        await SessionExpiryHandler.handle(_authProvider);
      }
      if (_nodes.isNotEmpty) {
        _state = PlanCompletionLoadState.loaded;
      } else {
        _state = PlanCompletionLoadState.error;
      }
      _error = e.toString();
    } catch (e) {
      if (_nodes.isNotEmpty) {
        _state = PlanCompletionLoadState.loaded;
      } else {
        _state = PlanCompletionLoadState.error;
      }
      _error = e.toString();
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

  List<PlanCompletionNode> _parseZNodes(String html) {
    final match = RegExp(r'var\s+zNodes\s*=\s*(\[.*?\]);', dotAll: true)
        .firstMatch(html);
    if (match == null) return [];

    final jsonStr = match.group(1)!;
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((e) => PlanCompletionNode.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
