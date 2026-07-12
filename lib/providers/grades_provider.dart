import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/models/scheme_score.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

const _keySchemeScores = 'grades_scheme_scores';
const _keyPassingScores = 'grades_passing_scores';

enum GradesLoadState { idle, loading, loaded, error }

class GradesProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final ZhjwApiService _zhjwApi;
  String? _userIdentity;
  int _identityGeneration = 0;

  GradesProvider(this._prefs, this._zhjwApi, {String? initialUserId})
    : _userIdentity = _normalizeIdentity(initialUserId) {
    _restoreCache();
  }

  static String? _normalizeIdentity(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  /// 仅接受与当前 token 绑定的 SCU principal 作为成绩缓存身份。
  static String? confirmedUserIdentity({
    required bool isLoggedIn,
    required String? principal,
  }) => isLoggedIn ? _normalizeIdentity(principal) : null;

  String _userCacheKey(String baseKey, String userIdentity) =>
      '${baseKey}_$userIdentity';

  void _restoreCache() {
    _schemeScores = null;
    _schemeState = GradesLoadState.idle;
    _schemeError = null;
    _passingScores = null;
    _passingState = GradesLoadState.idle;
    _passingError = null;

    final userIdentity = _userIdentity;
    if (userIdentity == null) return;

    final cachedScheme = _prefs.getString(
      _userCacheKey(_keySchemeScores, userIdentity),
    );
    if (cachedScheme != null) {
      try {
        _schemeScores = SchemeScoreSummary.fromJson(
          jsonDecode(cachedScheme) as Map<String, dynamic>,
        );
        _schemeState = GradesLoadState.loaded;
      } catch (_) {}
    }
    final cachedPassing = _prefs.getString(
      _userCacheKey(_keyPassingScores, userIdentity),
    );
    if (cachedPassing != null) {
      try {
        _passingScores = PassingScoreResult.fromJson(
          jsonDecode(cachedPassing) as Map<String, dynamic>,
        );
        _passingState = GradesLoadState.loaded;
      } catch (_) {}
    }
  }

  /// 切换已确认的 SCU 身份；身份未知时不恢复任何持久化成绩。
  void setUserIdentity(String? userId) {
    final normalized = _normalizeIdentity(userId);
    if (normalized == _userIdentity) return;
    _identityGeneration++;
    _userIdentity = normalized;
    _restoreCache();
    notifyListeners();
  }

  // --- 方案成绩 ---
  SchemeScoreSummary? _schemeScores;
  GradesLoadState _schemeState = GradesLoadState.idle;
  LoadErrorType? _schemeError;

  SchemeScoreSummary? get schemeScores => _schemeScores;
  GradesLoadState get schemeState => _schemeState;
  LoadErrorType? get schemeError => _schemeError;

  Future<void> refreshSchemeScores() async {
    if (_schemeState == GradesLoadState.loading) return;
    final generation = _identityGeneration;
    final userIdentity = _userIdentity;
    _schemeState = GradesLoadState.loading;
    _schemeError = null;
    notifyListeners();
    try {
      final data = await _zhjwApi.fetchSchemeScores();
      if (generation != _identityGeneration) return;
      _schemeScores = SchemeScoreSummary.fromJson(data);
      _schemeState = GradesLoadState.loaded;
      if (userIdentity != null) {
        await _prefs.setString(
          _userCacheKey(_keySchemeScores, userIdentity),
          jsonEncode(data),
        );
        if (generation != _identityGeneration) return;
      }
    } on UnauthenticatedException {
      if (generation != _identityGeneration) return;
      if (_schemeScores != null) {
        _schemeState = GradesLoadState.loaded;
        _schemeError = LoadErrorType.sessionExpired;
      } else {
        _schemeState = GradesLoadState.error;
        _schemeError = LoadErrorType.sessionExpired;
      }
    } catch (e) {
      if (generation != _identityGeneration) return;
      debugPrint('Scheme scores load error: $e');
      if (_schemeScores != null) {
        _schemeState = GradesLoadState.loaded;
        _schemeError = campusNetworkErrorType(LoadErrorType.loadFailed);
      } else {
        _schemeState = GradesLoadState.error;
        _schemeError = campusNetworkErrorType(LoadErrorType.loadFailed);
      }
    }
    notifyListeners();
  }

  void clearSchemeError() {
    _schemeError = null;
  }

  // --- 及格成绩 ---
  PassingScoreResult? _passingScores;
  GradesLoadState _passingState = GradesLoadState.idle;
  LoadErrorType? _passingError;

  PassingScoreResult? get passingScores => _passingScores;
  GradesLoadState get passingState => _passingState;
  LoadErrorType? get passingError => _passingError;

  Future<void> refreshPassingScores() async {
    if (_passingState == GradesLoadState.loading) return;
    final generation = _identityGeneration;
    final userIdentity = _userIdentity;
    _passingState = GradesLoadState.loading;
    _passingError = null;
    notifyListeners();
    try {
      final data = await _zhjwApi.fetchPassingScores();
      if (generation != _identityGeneration) return;
      _passingScores = PassingScoreResult.fromJson(data);
      _passingState = GradesLoadState.loaded;
      if (userIdentity != null) {
        await _prefs.setString(
          _userCacheKey(_keyPassingScores, userIdentity),
          jsonEncode(data),
        );
        if (generation != _identityGeneration) return;
      }
    } on UnauthenticatedException {
      if (generation != _identityGeneration) return;
      if (_passingScores != null) {
        _passingState = GradesLoadState.loaded;
        _passingError = LoadErrorType.sessionExpired;
      } else {
        _passingState = GradesLoadState.error;
        _passingError = LoadErrorType.sessionExpired;
      }
    } catch (e) {
      if (generation != _identityGeneration) return;
      debugPrint('Passing scores load error: $e');
      if (_passingScores != null) {
        _passingState = GradesLoadState.loaded;
        _passingError = campusNetworkErrorType(LoadErrorType.loadFailed);
      } else {
        _passingState = GradesLoadState.error;
        _passingError = campusNetworkErrorType(LoadErrorType.loadFailed);
      }
    }
    notifyListeners();
  }

  void clearPassingError() {
    _passingError = null;
  }
}
