import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/models/balance_record.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/api/balance_query_service.dart';
import 'package:bugaoshan/services/api/payapp_api_service.dart';
import 'package:bugaoshan/services/auth/payapp_auth.dart';
import 'package:bugaoshan/services/balance/balance_trend_calculator.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/utils/beijing_time.dart';

const _keyBindingInfo = 'balance_query_binding';
const _keyCurrentRoomIndex = 'balance_query_current_room';

/// 电费查询类型常量,与 SCU 缴费平台 API 一致:
///   - 1 = 照明电费
///   - 2 = 空调电费
const int kBalanceTypeElectric = 1;
const int kBalanceTypeAc = 2;

const _balanceHistoryRetention = Duration(days: 365);
const _balanceCacheDuration = Duration(minutes: 30);

/// Provider 暴露给 UI 的资源快照。
///
/// 余额、校区、楼栋和单元均由 Provider 统一维护此状态；页面只读取快照
/// 并发出「确保加载」或「强制刷新」意图，不再保存重复的数据副本。
@immutable
class BalanceResourceState<T> {
  const BalanceResourceState({
    this.value,
    this.updatedAt,
    this.isLoading = false,
    this.error,
  });

  final T? value;
  final DateTime? updatedAt;
  final bool isLoading;
  final Object? error;

  bool get hasValue => value != null;
}

class _ResourceEntry<T> {
  T? value;
  DateTime? updatedAt;
  bool isLoading = false;
  Object? error;
  Future<T>? inFlight;

  BalanceResourceState<T> get state => BalanceResourceState<T>(
    value: value,
    updatedAt: updatedAt,
    isLoading: isLoading,
    error: error,
  );
}

class _BalanceCacheKey {
  const _BalanceCacheKey(this.roomKey, this.balanceType);

  final String roomKey;
  final int balanceType;

  @override
  bool operator ==(Object other) =>
      other is _BalanceCacheKey &&
      other.roomKey == roomKey &&
      other.balanceType == balanceType;

  @override
  int get hashCode => Object.hash(roomKey, balanceType);
}

/// Provider 暴露给余额趋势页的历史记录快照。
///
/// 日期范围是查询条件的一部分，因此每个房间、余额类型和范围各自拥有一份
/// 内存状态；页面只保存范围选择等纯交互状态。
@immutable
class BalanceTrendState {
  const BalanceTrendState({
    this.records = const [],
    this.trend = const TrendResult.empty(),
    this.hasValue = false,
    this.isLoading = false,
    this.error,
  });

  final List<BalanceRecord> records;
  final TrendResult trend;
  final bool hasValue;
  final bool isLoading;
  final Object? error;
}

class _TrendCacheKey {
  const _TrendCacheKey(this.roomKey, this.balanceType, this.since, this.until);

  final String roomKey;
  final int balanceType;
  final DateTime? since;
  final DateTime? until;

  @override
  bool operator ==(Object other) =>
      other is _TrendCacheKey &&
      other.roomKey == roomKey &&
      other.balanceType == balanceType &&
      other.since == since &&
      other.until == until;

  @override
  int get hashCode => Object.hash(roomKey, balanceType, since, until);
}

class _TrendEntry {
  List<BalanceRecord>? records;
  TrendResult trend = const TrendResult.empty();
  bool isLoading = false;
  Object? error;
  Future<void>? inFlight;

  BalanceTrendState get state => BalanceTrendState(
    records: records ?? const [],
    trend: trend,
    hasValue: records != null,
    isLoading: isLoading,
    error: error,
  );
}

class BalanceQueryProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final PayAppApiService _payappApi;
  final DatabaseService _db;
  final PayAppAuth _payAppAuth;
  final AppConfigProvider _appConfig;
  final DateTime Function() _now;

  final _balanceEntries = <_BalanceCacheKey, _ResourceEntry<RoomInfo>>{};
  final _trendEntries = <_TrendCacheKey, _TrendEntry>{};
  _ResourceEntry<List<CampusItem>> _campusEntry =
      _ResourceEntry<List<CampusItem>>();
  final _buildingEntries = <String, _ResourceEntry<List<BuildingItem>>>{};
  final _unitEntries = <String, _ResourceEntry<List<UnitItem>>>{};

  bool _lastPayAppReady = false;
  bool _autoSampling = false;
  String? _userIdentity;
  int _identityGeneration = 0;
  Future<void>? _identityActivation;
  Future<void>? _legacyMigration;

  BalanceQueryProvider(
    this._prefs,
    this._payappApi,
    this._db,
    this._payAppAuth,
    this._appConfig, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _payAppAuth.addListener(_onPayAppAuthChanged);
    _lastPayAppReady = _payAppAuth.isReady;
  }

  static String? _normalizeIdentity(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  /// 仅接受与当前 token 绑定的 SCU principal 作为余额数据身份。
  static String? confirmedUserIdentity({
    required bool isLoggedIn,
    required String? principal,
  }) => isLoggedIn ? _normalizeIdentity(principal) : null;

  /// 当前激活的 SCU principal。为 null 时不暴露、也不恢复任何余额数据。
  String? get userIdentity => _userIdentity;

  /// 切换已确认的 SCU 身份；身份未知时清空所有内存余额资源。
  ///
  /// 调用方可以不 await 本方法，但在页面展示绑定前应保证当前身份已激活。
  Future<void> setUserIdentity(String? userIdentity) =>
      activateForPrincipal(userIdentity);

  /// [setUserIdentity] 的语义化别名，供认证协调层使用。
  Future<void> activateForPrincipal(String? principal) {
    final normalized = _normalizeIdentity(principal);
    if (normalized == null) {
      clear();
      return Future.value();
    }
    if (normalized == _userIdentity && _identityActivation != null) {
      return _identityActivation!;
    }

    final generation = ++_identityGeneration;
    _userIdentity = normalized;
    _resetInMemoryState();
    notifyListeners();

    final activation = _restoreBindingsFor(normalized, generation);
    _identityActivation = activation;
    return activation;
  }

  /// 使当前账号的所有内存数据和飞行请求失效。
  ///
  /// 已发出的网络或数据库操作仍会自然完成，但不会再写回 Provider 或历史记录。
  void clear() {
    _identityGeneration++;
    _userIdentity = null;
    _identityActivation = null;
    _resetInMemoryState();
    notifyListeners();
  }

  void _resetInMemoryState() {
    _bindings = [];
    _currentIndex = 0;
    _isSwitching = false;
    _autoSampling = false;
    _balanceEntries.clear();
    _trendEntries.clear();
    _campusEntry = _ResourceEntry<List<CampusItem>>();
    _buildingEntries.clear();
    _unitEntries.clear();
  }

  bool _isCurrentGeneration(int generation) =>
      generation == _identityGeneration;

  /// PayAppAuth 状态变化:isReady 由 false→true 时(登录成功或 SSO 重连),
  /// 若用户开启了"登录后自动采样"开关,且当前房间今日尚无记录,则静默采样一次。
  void _onPayAppAuthChanged() {
    final ready = _payAppAuth.isReady;
    if (ready && !_lastPayAppReady) {
      unawaited(_maybeAutoSample());
    }
    _lastPayAppReady = ready;
  }

  Future<void> _maybeAutoSample() async {
    if (_autoSampling) return;
    if (!_appConfig.autoSampleBalanceOnLogin.value) return;
    final binding = currentBinding;
    if (binding == null) return;
    final generation = _identityGeneration;

    _autoSampling = true;
    try {
      final roomKey = _roomKeyFor(binding);
      // 以北京日界为基准判定"今日已采样否",不依赖设备本地时区。
      final startOfTodayUtc = beijingStartOfTodayUtc();
      final electricRecords = await _db.getBalanceRecords(
        roomKey: roomKey,
        balanceType: kBalanceTypeElectric,
        since: startOfTodayUtc,
      );
      if (!_isCurrentGeneration(generation)) return;
      final acRecords = await _db.getBalanceRecords(
        roomKey: roomKey,
        balanceType: kBalanceTypeAc,
        since: startOfTodayUtc,
      );
      if (!_isCurrentGeneration(generation)) return;

      if (electricRecords.isEmpty) {
        try {
          await _loadBalanceFor(binding, kBalanceTypeElectric, force: true);
        } catch (e) {
          debugPrint('Auto-sample electric failed: $e');
        }
      }
      if (acRecords.isEmpty) {
        try {
          await _loadBalanceFor(binding, kBalanceTypeAc, force: true);
        } catch (e) {
          debugPrint('Auto-sample AC failed: $e');
        }
      }
    } catch (e) {
      debugPrint('Auto-sample balance failed: $e');
    } finally {
      if (_isCurrentGeneration(generation)) {
        _autoSampling = false;
      }
    }
  }

  List<RoomBinding> _bindings = [];
  List<RoomBinding> get bindings => List.unmodifiable(_bindings);

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  RoomBinding? get currentBinding =>
      _bindings.isNotEmpty && _currentIndex < _bindings.length
      ? _bindings[_currentIndex]
      : null;

  bool _isSwitching = false;
  bool get isSwitching => _isSwitching;

  BalanceResourceState<RoomInfo> balanceStateFor(int balanceType) {
    final binding = currentBinding;
    if (binding == null) return const BalanceResourceState<RoomInfo>();
    final entry = _balanceEntryFor(binding, balanceType);
    if (!_isFresh(entry, _balanceCacheDuration)) {
      // 缓存到期后 UI 不展示旧余额；随后 ensureBalance 会将其置为 loading
      // 并发起新请求。
      return BalanceResourceState<RoomInfo>(
        isLoading: entry.isLoading,
        error: entry.error,
      );
    }
    return entry.state;
  }

  RoomInfo? balanceInfoFor(int balanceType) =>
      balanceStateFor(balanceType).value;

  RoomInfo? get electricInfo => balanceInfoFor(kBalanceTypeElectric);
  RoomInfo? get acInfo => balanceInfoFor(kBalanceTypeAc);

  BalanceResourceState<List<CampusItem>> get campusState => _campusEntry.state;

  BalanceResourceState<List<BuildingItem>> buildingState(String schoolCode) =>
      _buildingEntries
          .putIfAbsent(schoolCode, _ResourceEntry<List<BuildingItem>>.new)
          .state;

  BalanceResourceState<List<UnitItem>> unitState(
    String schoolCode,
    String regCode,
  ) => _unitEntries
      .putIfAbsent(
        _unitKey(schoolCode, regCode),
        _ResourceEntry<List<UnitItem>>.new,
      )
      .state;

  Future<void> _restoreBindingsFor(String identity, int generation) async {
    await _migrateLegacyBindings();
    if (!_isCurrentGeneration(generation) || _userIdentity != identity) return;

    final json = _prefs.getString(_bindingInfoKeyFor(identity));
    var bindings = <RoomBinding>[];
    if (json != null) {
      try {
        final List<dynamic> list = jsonDecode(json);
        bindings = list
            .map((e) => RoomBinding.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Failed to load balance binding info: $e');
      }
    }
    if (!_isCurrentGeneration(generation) || _userIdentity != identity) return;

    var currentIndex = _prefs.getInt(_currentRoomIndexKeyFor(identity)) ?? 0;
    if (currentIndex < 0 || currentIndex >= bindings.length) {
      currentIndex = bindings.isEmpty ? 0 : bindings.length - 1;
    }
    _bindings = bindings;
    _currentIndex = currentIndex;
    notifyListeners();
  }

  /// 将旧版全局绑定迁移为每个 SCU principal 独立的存储区。
  ///
  /// 老记录的 [RoomBinding.cusNo] 是唯一可用的归属信息；无法归属的记录不迁移，
  /// 以避免在任意账号下展示它们。
  Future<void> _migrateLegacyBindings() {
    final pending = _legacyMigration;
    if (pending != null) return pending;

    final migration = _performLegacyBindingMigration();
    _legacyMigration = migration;
    return migration;
  }

  Future<void> _performLegacyBindingMigration() async {
    final json = _prefs.getString(_keyBindingInfo);
    if (json == null) return;

    try {
      final List<dynamic> list = jsonDecode(json);
      final bindings = list
          .map((e) => RoomBinding.fromJson(e as Map<String, dynamic>))
          .toList();
      final legacyIndex = _prefs.getInt(_keyCurrentRoomIndex) ?? 0;
      final grouped = <String, List<RoomBinding>>{};
      final selectedIndices = <String, int>{};

      for (var index = 0; index < bindings.length; index++) {
        final binding = bindings[index];
        final identity = _normalizeIdentity(binding.cusNo);
        if (identity == null) continue;
        final group = grouped.putIfAbsent(identity, () => <RoomBinding>[]);
        if (index == legacyIndex) selectedIndices[identity] = group.length;
        group.add(binding);
      }

      for (final entry in grouped.entries) {
        final identity = entry.key;
        if (_prefs.containsKey(_bindingInfoKeyFor(identity))) continue;
        await _prefs.setString(
          _bindingInfoKeyFor(identity),
          jsonEncode(entry.value.map((binding) => binding.toJson()).toList()),
        );
        final selectedIndex = selectedIndices[identity] ?? 0;
        await _prefs.setInt(_currentRoomIndexKeyFor(identity), selectedIndex);
      }

      await _prefs.remove(_keyBindingInfo);
      await _prefs.remove(_keyCurrentRoomIndex);
    } catch (e) {
      debugPrint('Failed to migrate legacy balance bindings: $e');
    }
  }

  Future<void> _saveBindingInfo({
    required String identity,
    required List<RoomBinding> bindings,
    required int currentIndex,
  }) async {
    final json = jsonEncode(bindings.map((e) => e.toJson()).toList());
    await _prefs.setString(_bindingInfoKeyFor(identity), json);
    await _prefs.setInt(_currentRoomIndexKeyFor(identity), currentIndex);
  }

  Future<void> addBinding(RoomBinding binding) async {
    final identity = _userIdentity;
    if (identity == null) throw StateError('未确认当前登录账号');
    final generation = _identityGeneration;
    _bindings.add(binding);
    _currentIndex = _bindings.length - 1;
    final bindings = List<RoomBinding>.from(_bindings);
    final currentIndex = _currentIndex;
    notifyListeners();
    await _saveBindingInfo(
      identity: identity,
      bindings: bindings,
      currentIndex: currentIndex,
    );
    if (!_isCurrentGeneration(generation) || _userIdentity != identity) return;
    ensureCurrentBalances();
  }

  Future<void> removeBinding(int index) async {
    if (index < 0 || index >= _bindings.length) return;
    final identity = _userIdentity;
    if (identity == null) return;
    final generation = _identityGeneration;
    final removed = _bindings[index];
    final roomKey = _roomKeyFor(removed);
    _bindings.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (_currentIndex >= _bindings.length) {
      _currentIndex = _bindings.isEmpty ? 0 : _bindings.length - 1;
    }
    _evictBalanceEntriesFor(removed);
    final bindings = List<RoomBinding>.from(_bindings);
    final currentIndex = _currentIndex;
    notifyListeners();
    await _saveBindingInfo(
      identity: identity,
      bindings: bindings,
      currentIndex: currentIndex,
    );
    if (!_isCurrentGeneration(generation) || _userIdentity != identity) return;
    // 同步删除该房间的历史记录,避免残留。
    try {
      await _db.deleteBalanceRecordsByRoom(roomKey);
    } catch (e) {
      debugPrint('Failed to clean balance history for removed room: $e');
    }
    if (!_isCurrentGeneration(generation) || _userIdentity != identity) return;
    ensureCurrentBalances();
  }

  Future<void> switchBinding(int index) async {
    if (index < 0 || index >= _bindings.length) return;
    final identity = _userIdentity;
    if (identity == null) return;
    final generation = _identityGeneration;
    _currentIndex = index;
    final currentIndex = _currentIndex;
    await _prefs.setInt(_currentRoomIndexKeyFor(identity), currentIndex);
    if (!_isCurrentGeneration(generation) || _userIdentity != identity) return;
    _isSwitching = true;
    notifyListeners();

    try {
      final binding = currentBinding!;
      await _payappApi.verificationRoom(
        cusNo: binding.cusNo,
        type: kBalanceTypeElectric,
        cusName: binding.cusName,
        schoolCode: binding.schoolCode,
        regCode: binding.regCode,
        unitCode: binding.unitCode,
        roomNo: binding.roomNo,
      );
    } finally {
      if (_isCurrentGeneration(generation) && _userIdentity == identity) {
        _isSwitching = false;
        notifyListeners();
        ensureCurrentBalances();
      }
    }
  }

  /// 返回当前房间+类型的内存缓存；不存在或满 30 分钟时重新请求。
  Future<RoomInfo> ensureBalance(int balanceType) async {
    _requireActiveIdentity();
    final binding = currentBinding;
    if (binding == null) throw BalanceQueryException('未绑定房间');
    return _loadBalanceFor(binding, balanceType);
  }

  /// 清空当前值并强制向服务端请求最新余额。
  Future<RoomInfo> refreshBalance(int balanceType) async {
    _requireActiveIdentity();
    final binding = currentBinding;
    if (binding == null) throw BalanceQueryException('未绑定房间');
    return _loadBalanceFor(binding, balanceType, force: true);
  }

  /// 为首次进入、切换和新增绑定发起静默加载，错误保留在 Provider 状态中。
  void ensureCurrentBalances() {
    if (currentBinding == null || _isSwitching) return;
    unawaited(_silentlyEnsureBalance(kBalanceTypeElectric));
    unawaited(_silentlyEnsureBalance(kBalanceTypeAc));
  }

  Future<void> _silentlyEnsureBalance(int balanceType) async {
    try {
      await ensureBalance(balanceType);
    } catch (_) {
      // 错误由 balanceStateFor 暴露给 UI，不让后台预热形成未处理异常。
    }
  }

  Future<RoomInfo> _loadBalanceFor(
    RoomBinding binding,
    int balanceType, {
    bool force = false,
  }) {
    final identity = _userIdentity;
    if (identity == null) {
      throw StateError('未确认当前登录账号');
    }
    final generation = _identityGeneration;
    final roomKey = _roomKeyFor(binding);
    final entry = _balanceEntries.putIfAbsent(
      _BalanceCacheKey(roomKey, balanceType),
      _ResourceEntry<RoomInfo>.new,
    );
    return _loadResource(
      entry,
      () => _payappApi.queryRoomInfo(
        cusNo: binding.cusNo,
        type: balanceType,
        cusName: binding.cusName,
      ),
      cacheDuration: _balanceCacheDuration,
      clearValueOnLoad: true,
      force: force,
      onLoaded: (info) async {
        if (!_isCurrentGeneration(generation) || _userIdentity != identity) {
          return;
        }
        if (_bindings.any((item) => _roomKeyFor(item) == roomKey)) {
          await _recordHistory(
            info,
            balanceType: balanceType,
            identity: identity,
            generation: generation,
            roomKey: roomKey,
          );
        }
      },
    );
  }

  /// 兼容现有调用：原方法语义是每次都请求，故委托强制刷新。
  Future<RoomInfo> queryElectricInfo() => refreshBalance(kBalanceTypeElectric);

  /// 兼容现有调用：原方法语义是每次都请求，故委托强制刷新。
  Future<RoomInfo> queryAcInfo() => refreshBalance(kBalanceTypeAc);

  Future<List<CampusItem>> getCampusList() {
    _requireActiveIdentity();
    return _loadResource(
      _campusEntry,
      _payappApi.getCampus,
      clearValueOnLoad: false,
    );
  }

  Future<List<BuildingItem>> getArchitectureList(String schoolCode) {
    _requireActiveIdentity();
    final entry = _buildingEntries.putIfAbsent(
      schoolCode,
      _ResourceEntry<List<BuildingItem>>.new,
    );
    return _loadResource(
      entry,
      () => _payappApi.getArchitecture(schoolCode),
      clearValueOnLoad: false,
    );
  }

  Future<List<UnitItem>> getUnitList(String schoolCode, String regCode) {
    _requireActiveIdentity();
    final entry = _unitEntries.putIfAbsent(
      _unitKey(schoolCode, regCode),
      _ResourceEntry<List<UnitItem>>.new,
    );
    return _loadResource(
      entry,
      () => _payappApi.getUnit(schoolCode, regCode),
      clearValueOnLoad: false,
    );
  }

  Future<bool> verifyRoom(
    String cusNo,
    int type,
    String cusName,
    String schoolCode,
    String regCode,
    String unitCode,
    String roomNo,
  ) {
    _requireActiveIdentity();
    return _payappApi.verificationRoom(
      cusNo: cusNo,
      type: type,
      cusName: cusName,
      schoolCode: schoolCode,
      regCode: regCode,
      unitCode: unitCode,
      roomNo: roomNo,
    );
  }

  Future<T> _loadResource<T>(
    _ResourceEntry<T> entry,
    Future<T> Function() loader, {
    Duration? cacheDuration,
    required bool clearValueOnLoad,
    bool force = false,
    Future<void> Function(T value)? onLoaded,
  }) {
    final isFresh = cacheDuration == null
        ? entry.value != null
        : _isFresh(entry, cacheDuration);
    if (!force && isFresh) return Future.value(entry.value!);

    final inFlight = entry.inFlight;
    if (inFlight != null) return inFlight;

    final generation = _identityGeneration;
    entry.isLoading = true;
    entry.error = null;
    if (clearValueOnLoad) {
      entry.value = null;
      entry.updatedAt = null;
    }
    notifyListeners();

    Future<T> execute() async {
      try {
        final loaded = await loader();
        if (_isCurrentGeneration(generation)) {
          if (onLoaded != null) await onLoaded(loaded);
          if (_isCurrentGeneration(generation)) {
            entry.value = loaded;
            entry.updatedAt = _now();
          }
        }
        return loaded;
      } catch (e) {
        if (_isCurrentGeneration(generation)) {
          entry.error = e;
        }
        rethrow;
      } finally {
        if (_isCurrentGeneration(generation)) {
          entry.isLoading = false;
          entry.inFlight = null;
          notifyListeners();
        }
      }
    }

    final future = execute();
    entry.inFlight = future;
    return future;
  }

  /// 读取当前房间和日期范围对应的趋势快照。
  BalanceTrendState trendStateFor({
    required int balanceType,
    DateTime? since,
    DateTime? until,
  }) {
    final binding = currentBinding;
    if (binding == null) return const BalanceTrendState();
    return _trendEntryFor(binding, balanceType, since, until).state;
  }

  /// 确保指定房间、余额类型和日期范围的趋势历史已加载。
  Future<void> ensureTrend({
    required int balanceType,
    DateTime? since,
    DateTime? until,
    bool force = false,
  }) async {
    final binding = currentBinding;
    final identity = _userIdentity;
    if (binding == null || identity == null) return;
    final roomKey = _roomKeyFor(binding);
    final entry = _trendEntryFor(binding, balanceType, since, until);
    if (!force && entry.records != null) return;
    final pending = entry.inFlight;
    if (pending != null) return pending;
    final generation = _identityGeneration;

    entry.isLoading = true;
    entry.error = null;
    if (force) {
      entry.records = null;
      entry.trend = const TrendResult.empty();
    }
    notifyListeners();

    final from = since ?? _now().toUtc().subtract(_balanceHistoryRetention);
    Future<void> load() async {
      try {
        final records = await _db.getBalanceRecords(
          roomKey: roomKey,
          balanceType: balanceType,
          since: from,
          until: until,
        );
        if (_isCurrentGeneration(generation) && _userIdentity == identity) {
          entry.records = List.unmodifiable(records);
          entry.trend = BalanceTrendCalculator.calculate(entry.records!);
        }
      } catch (e) {
        if (_isCurrentGeneration(generation) && _userIdentity == identity) {
          entry.error = e;
        }
        rethrow;
      } finally {
        if (_isCurrentGeneration(generation) && _userIdentity == identity) {
          entry.isLoading = false;
          entry.inFlight = null;
          notifyListeners();
        }
      }
    }

    final request = load();
    entry.inFlight = request;
    return request;
  }

  /// 拉取指定房间+类型的历史记录(默认 1 年)。
  ///
  /// 保留给非 UI 调用方兼容；趋势页面通过 [trendStateFor] 读取状态。
  Future<List<BalanceRecord>> getBalanceHistory({
    required int balanceType,
    DateTime? since,
    DateTime? until,
  }) async {
    await ensureTrend(balanceType: balanceType, since: since, until: until);
    return trendStateFor(
      balanceType: balanceType,
      since: since,
      until: until,
    ).records;
  }

  _ResourceEntry<RoomInfo> _balanceEntryFor(
    RoomBinding binding,
    int balanceType,
  ) => _balanceEntries.putIfAbsent(
    _BalanceCacheKey(_roomKeyFor(binding), balanceType),
    _ResourceEntry<RoomInfo>.new,
  );

  void _evictBalanceEntriesFor(RoomBinding binding) {
    final roomKey = _roomKeyFor(binding);
    _balanceEntries.removeWhere((key, _) => key.roomKey == roomKey);
    _trendEntries.removeWhere((key, _) => key.roomKey == roomKey);
  }

  _TrendEntry _trendEntryFor(
    RoomBinding binding,
    int balanceType,
    DateTime? since,
    DateTime? until,
  ) {
    final key = _TrendCacheKey(_roomKeyFor(binding), balanceType, since, until);
    return _trendEntries.putIfAbsent(key, _TrendEntry.new);
  }

  bool _isFresh<T>(_ResourceEntry<T> entry, Duration cacheDuration) {
    final updatedAt = entry.updatedAt;
    return entry.value != null &&
        updatedAt != null &&
        _now().difference(updatedAt) < cacheDuration;
  }

  String _roomKeyFor(RoomBinding binding) {
    final identity = _userIdentity;
    if (identity == null) {
      throw StateError('未确认当前登录账号');
    }
    return 'balance-v2:$identity:'
        '${binding.schoolCode}_${binding.regCode}_${binding.unitCode}_${binding.roomNo}';
  }

  String _unitKey(String schoolCode, String regCode) =>
      '${schoolCode}_$regCode';

  void _requireActiveIdentity() {
    if (_userIdentity == null) {
      throw StateError('未确认当前登录账号');
    }
  }

  String _bindingInfoKeyFor(String identity) => '${_keyBindingInfo}_$identity';

  String _currentRoomIndexKeyFor(String identity) =>
      '${_keyCurrentRoomIndex}_$identity';

  /// 仅在成功请求后记录一条历史快照。失败不影响主流程。
  Future<void> _recordHistory(
    RoomInfo info, {
    required int balanceType,
    required String identity,
    required int generation,
    required String roomKey,
  }) async {
    try {
      if (!_isCurrentGeneration(generation) || _userIdentity != identity) {
        return;
      }
      final now = _now().toUtc();
      final record = BalanceRecord(
        roomKey: roomKey,
        balanceType: balanceType,
        timestamp: now,
        balance: double.tryParse(info.balance) ?? 0,
        price: double.tryParse(info.price) ?? 0,
      );
      if (!_isCurrentGeneration(generation) || _userIdentity != identity) {
        return;
      }
      await _db.insertBalanceRecord(record);
      if (!_isCurrentGeneration(generation) || _userIdentity != identity) {
        return;
      }
      await _db.deleteBalanceRecordsBefore(
        now.subtract(_balanceHistoryRetention),
      );
      if (!_isCurrentGeneration(generation) || _userIdentity != identity) {
        return;
      }
      _trendEntries.removeWhere(
        (key, _) => key.roomKey == roomKey && key.balanceType == balanceType,
      );
    } catch (e) {
      debugPrint('Failed to record balance history: $e');
    }
  }

  @override
  void dispose() {
    _payAppAuth.removeListener(_onPayAppAuthChanged);
    super.dispose();
  }
}

class RoomBinding {
  final String cusNo;
  final String cusName;
  final String schoolCode;
  final String schoolName;
  final String regCode;
  final String regName;
  final String unitCode;
  final String unitName;
  final String roomNo;

  RoomBinding({
    required this.cusNo,
    required this.cusName,
    required this.schoolCode,
    required this.schoolName,
    required this.regCode,
    required this.regName,
    required this.unitCode,
    required this.unitName,
    required this.roomNo,
  });

  String get displayName => '$schoolName $regName $unitName $roomNo';

  factory RoomBinding.fromJson(Map<String, dynamic> json) {
    return RoomBinding(
      cusNo: json['cusNo']?.toString() ?? '',
      cusName: json['cusName']?.toString() ?? '',
      schoolCode: json['schoolCode']?.toString() ?? '',
      schoolName: json['schoolName']?.toString() ?? '',
      regCode: json['regCode']?.toString() ?? '',
      regName: json['regName']?.toString() ?? '',
      unitCode: json['unitCode']?.toString() ?? '',
      unitName: json['unitName']?.toString() ?? '',
      roomNo: json['roomNo']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'cusNo': cusNo,
    'cusName': cusName,
    'schoolCode': schoolCode,
    'schoolName': schoolName,
    'regCode': regCode,
    'regName': regName,
    'unitCode': unitCode,
    'unitName': unitName,
    'roomNo': roomNo,
  };
}
