import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/models/scheme_score.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/scu_auth_service.dart';
import 'package:bugaoshan/utils/session_expiry_handler.dart';

const _keySchemeScores = 'grades_scheme_scores';
const _keyPassingScores = 'grades_passing_scores';

enum GradesLoadState { idle, loading, loaded, error }

class GradesProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final ScuAuthProvider _authProvider;

  GradesProvider(this._prefs, this._authProvider) {
    final cachedScheme = _prefs.getString(_keySchemeScores);
    if (cachedScheme != null) {
      try {
        _schemeScores = SchemeScoreSummary.fromJson(
          jsonDecode(cachedScheme) as Map<String, dynamic>,
        );
        _schemeState = GradesLoadState.loaded;
      } catch (_) {}
    }
    final cachedPassing = _prefs.getString(_keyPassingScores);
    if (cachedPassing != null) {
      try {
        _passingScores = PassingScoreResult.fromJson(
          jsonDecode(cachedPassing) as Map<String, dynamic>,
        );
        _passingState = GradesLoadState.loaded;
      } catch (_) {}
    }
  }

  // --- 方案成绩 ---
  SchemeScoreSummary? _schemeScores;
  GradesLoadState _schemeState = GradesLoadState.idle;
  String? _schemeError;

  SchemeScoreSummary? get schemeScores => _schemeScores;
  GradesLoadState get schemeState => _schemeState;
  String? get schemeError => _schemeError;

  Future<void> refreshSchemeScores() async {
    if (_schemeState == GradesLoadState.loading) return;
    _schemeState = GradesLoadState.loading;
    _schemeError = null;
    notifyListeners();
    try {
      final data = await _authProvider.service.fetchSchemeScores();
      _schemeScores = SchemeScoreSummary.fromJson(data);
      _schemeState = GradesLoadState.loaded;
      await _prefs.setString(_keySchemeScores, jsonEncode(data));
    } on ScuLoginException catch (e) {
      if (e.sessionExpired) {
        await SessionExpiryHandler.handle(_authProvider);
      }
      if (_schemeScores != null) {
        _schemeState = GradesLoadState.loaded;
        _schemeError = 'sessionExpired';
      } else {
        _schemeState = GradesLoadState.error;
        _schemeError = 'sessionExpired';
      }
    } catch (e) {
      debugPrint('Scheme scores load error: $e');
      if (_schemeScores != null) {
        _schemeState = GradesLoadState.loaded;
        _schemeError = 'gradesLoadFailed';
      } else {
        _schemeState = GradesLoadState.error;
        _schemeError = 'gradesLoadFailed';
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
  String? _passingError;

  PassingScoreResult? get passingScores => _passingScores;
  GradesLoadState get passingState => _passingState;
  String? get passingError => _passingError;

  Future<void> refreshPassingScores() async {
    if (_passingState == GradesLoadState.loading) return;
    _passingState = GradesLoadState.loading;
    _passingError = null;
    notifyListeners();
    try {
      final data = await _authProvider.service.fetchPassingScores();
      _passingScores = PassingScoreResult.fromJson(data);
      _passingState = GradesLoadState.loaded;
      await _prefs.setString(_keyPassingScores, jsonEncode(data));
    } on ScuLoginException catch (e) {
      if (e.sessionExpired) {
        await SessionExpiryHandler.handle(_authProvider);
      }
      if (_passingScores != null) {
        _passingState = GradesLoadState.loaded;
        _passingError = 'sessionExpired';
      } else {
        _passingState = GradesLoadState.error;
        _passingError = 'sessionExpired';
      }
    } catch (e) {
      debugPrint('Passing scores load error: $e');
      if (_passingScores != null) {
        _passingState = GradesLoadState.loaded;
        _passingError = 'gradesLoadFailed';
      } else {
        _passingState = GradesLoadState.error;
        _passingError = 'gradesLoadFailed';
      }
    }
    notifyListeners();
  }

  void clearPassingError() {
    _passingError = null;
  }
}
