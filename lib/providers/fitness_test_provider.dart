import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/pages/campus/fitness_test/models/fitness_models.dart';
import 'package:bugaoshan/services/api/fitness_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

const kFitnessTestSelectedYearKey = 'fitness_test_selected_year';

enum FitnessTestLoadState { idle, loading, loaded, error }

/// 体测页面的领域状态。
///
/// 远端通知和当前选中年份的成绩只保存在此处；页面仅根据资源状态渲染，并通过
/// [ensureLoaded]、[refresh] 和 [selectYear] 表达加载意图。
class FitnessTestProvider extends ChangeNotifier {
  FitnessTestProvider(this._prefs, this._api) {
    _selectedYear =
        _prefs.getInt(kFitnessTestSelectedYearKey) ?? DateTime.now().year;
  }

  final SharedPreferences _prefs;
  final FitnessTestApi _api;

  int _epoch = 0;
  int _noticesGeneration = 0;
  int _scoreGeneration = 0;
  Future<void>? _noticesInFlight;
  Future<void>? _scoreInFlight;
  int? _scoreInFlightYear;

  int _selectedYear = DateTime.now().year;
  int get selectedYear => _selectedYear;

  List<FitnessNotice> _notices = const [];
  List<FitnessNotice> get notices => List.unmodifiable(_notices);
  FitnessTestLoadState _noticesState = FitnessTestLoadState.idle;
  FitnessTestLoadState get noticesState => _noticesState;
  Object? _noticesError;
  Object? get noticesError => _noticesError;

  FitnessScore? _scoreData;
  FitnessScore? get scoreData => _scoreData;
  FitnessTestLoadState _scoreState = FitnessTestLoadState.idle;
  FitnessTestLoadState get scoreState => _scoreState;
  Object? _scoreError;
  Object? get scoreError => _scoreError;

  bool get isLoading =>
      _noticesState == FitnessTestLoadState.loading ||
      _scoreState == FitnessTestLoadState.loading;

  /// 仅在尚无对应资源时加载。并发调用会复用同一请求。
  Future<void> ensureLoaded() async {
    await Future.wait([ensureNotices(), ensureScore()]);
  }

  Future<void> ensureNotices() {
    if (_noticesState == FitnessTestLoadState.loaded) {
      return Future.value();
    }
    return _loadNotices();
  }

  Future<void> ensureScore() {
    if (_scoreState == FitnessTestLoadState.loaded) {
      return Future.value();
    }
    return _loadScore();
  }

  /// 显式刷新通知和当前年份成绩，忽略现有内存缓存。
  Future<void> refresh() async {
    await Future.wait([_loadNotices(force: true), _loadScore(force: true)]);
  }

  Future<void> refreshNotices() => _loadNotices(force: true);

  Future<void> refreshScore() => _loadScore(force: true);

  /// 更新当前年份并持久化选择；旧年份的飞行请求不会回写新状态。
  Future<void> selectYear(int year) async {
    if (year == _selectedYear) return;
    _selectedYear = year;
    _scoreData = null;
    _scoreError = null;
    _scoreState = FitnessTestLoadState.idle;
    _scoreGeneration++;
    notifyListeners();

    await _prefs.setInt(kFitnessTestSelectedYearKey, year);
    await _loadScore(force: true);
  }

  Future<void> _loadNotices({bool force = false}) {
    if (!force && _noticesInFlight != null) return _noticesInFlight!;
    if (!force && _noticesState == FitnessTestLoadState.loaded) {
      return Future.value();
    }

    final epoch = _epoch;
    final generation = ++_noticesGeneration;
    _noticesState = FitnessTestLoadState.loading;
    _noticesError = null;
    notifyListeners();

    late final Future<void> request;
    request = () async {
      try {
        final notices = await _api.fetchNotices();
        if (!_isNoticesCurrent(epoch, generation)) return;
        _notices = notices;
        _noticesState = FitnessTestLoadState.loaded;
      } catch (error) {
        if (!_isNoticesCurrent(epoch, generation)) return;
        _noticesState = FitnessTestLoadState.error;
        _noticesError = _noticeError(error);
      } finally {
        if (_noticesInFlight == request) _noticesInFlight = null;
        if (_isNoticesCurrent(epoch, generation)) notifyListeners();
      }
    }();
    _noticesInFlight = request;
    return request;
  }

  Future<void> _loadScore({bool force = false}) {
    final inFlight = _scoreInFlight;
    if (!force && inFlight != null && _scoreInFlightYear == _selectedYear) {
      return inFlight;
    }
    if (!force && _scoreState == FitnessTestLoadState.loaded) {
      return Future.value();
    }

    final year = _selectedYear;
    final epoch = _epoch;
    final generation = ++_scoreGeneration;
    _scoreState = FitnessTestLoadState.loading;
    _scoreError = null;
    _scoreData = null;
    notifyListeners();

    late final Future<void> request;
    request = () async {
      try {
        final score = await _api.fetchScore(year);
        if (!_isScoreCurrent(epoch, generation, year)) return;
        _scoreData = score;
        _scoreState = FitnessTestLoadState.loaded;
      } catch (error) {
        if (!_isScoreCurrent(epoch, generation, year)) return;
        _scoreState = FitnessTestLoadState.error;
        _scoreError = _scoreLoadError(error);
      } finally {
        if (_scoreInFlight == request) {
          _scoreInFlight = null;
          _scoreInFlightYear = null;
        }
        if (_isScoreCurrent(epoch, generation, year)) {
          notifyListeners();
        }
      }
    }();
    _scoreInFlight = request;
    _scoreInFlightYear = year;
    return request;
  }

  bool _isNoticesCurrent(int epoch, int generation) =>
      epoch == _epoch && generation == _noticesGeneration;

  bool _isScoreCurrent(int epoch, int generation, int year) =>
      epoch == _epoch &&
      generation == _scoreGeneration &&
      year == _selectedYear;

  Object _noticeError(Object error) {
    if (error is UnauthenticatedException) return LoadErrorType.sessionExpired;
    if (error is ServiceException) return error.message;
    return campusNetworkErrorType(LoadErrorType.networkError);
  }

  Object _scoreLoadError(Object error) {
    if (error is UnauthenticatedException) return LoadErrorType.sessionExpired;
    if (error is ServiceException) return error.message;
    return campusNetworkErrorType(LoadErrorType.networkError);
  }

  /// 登出或账号切换时调用，丢弃全部会话内数据及飞行请求结果。
  void clear() {
    _epoch++;
    _noticesGeneration++;
    _scoreGeneration++;
    _noticesInFlight = null;
    _scoreInFlight = null;
    _scoreInFlightYear = null;
    _notices = const [];
    _noticesState = FitnessTestLoadState.idle;
    _noticesError = null;
    _scoreData = null;
    _scoreState = FitnessTestLoadState.idle;
    _scoreError = null;
    notifyListeners();
  }
}
