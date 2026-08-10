import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/models/balance_record.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/api/balance_query_service.dart';
import 'package:bugaoshan/services/api/payapp_api_service.dart';
import 'package:bugaoshan/services/auth/payapp_auth.dart';
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

class BalanceQueryProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final PayAppApiService _payappApi;
  final DatabaseService _db;
  final PayAppAuth _payAppAuth;
  final AppConfigProvider _appConfig;
  final DateTime Function() _now;

  final _balanceEntries = <_BalanceCacheKey, _ResourceEntry<RoomInfo>>{};
  final _campusEntry = _ResourceEntry<List<CampusItem>>();
  final _buildingEntries = <String, _ResourceEntry<List<BuildingItem>>>{};
  final _unitEntries = <String, _ResourceEntry<List<UnitItem>>>{};

  bool _lastPayAppReady = false;
  bool _autoSampling = false;

  BalanceQueryProvider(
    this._prefs,
    this._payappApi,
    this._db,
    this._payAppAuth,
    this._appConfig, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _loadBindingInfo();
    _payAppAuth.addListener(_onPayAppAuthChanged);
    _lastPayAppReady = _payAppAuth.isReady;
  }

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
      final acRecords = await _db.getBalanceRecords(
        roomKey: roomKey,
        balanceType: kBalanceTypeAc,
        since: startOfTodayUtc,
      );

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
      _autoSampling = false;
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

  void _loadBindingInfo() {
    final json = _prefs.getString(_keyBindingInfo);
    if (json != null) {
      try {
        final List<dynamic> list = jsonDecode(json);
        _bindings = list
            .map((e) => RoomBinding.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Failed to load binding info: $e');
      }
    }
    _currentIndex = _prefs.getInt(_keyCurrentRoomIndex) ?? 0;
    if (_currentIndex >= _bindings.length) {
      _currentIndex = _bindings.isEmpty ? 0 : _bindings.length - 1;
    }
  }

  Future<void> _saveBindingInfo() async {
    final json = jsonEncode(_bindings.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyBindingInfo, json);
    await _prefs.setInt(_keyCurrentRoomIndex, _currentIndex);
  }

  Future<void> addBinding(RoomBinding binding) async {
    _bindings.add(binding);
    _currentIndex = _bindings.length - 1;
    await _saveBindingInfo();
    notifyListeners();
    ensureCurrentBalances();
  }

  Future<void> removeBinding(int index) async {
    if (index < 0 || index >= _bindings.length) return;
    final removed = _bindings[index];
    _bindings.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (_currentIndex >= _bindings.length) {
      _currentIndex = _bindings.isEmpty ? 0 : _bindings.length - 1;
    }
    _evictBalanceEntriesFor(removed);
    await _saveBindingInfo();
    // 同步删除该房间的历史记录,避免残留。
    try {
      await _db.deleteBalanceRecordsByRoom(_roomKeyFor(removed));
    } catch (e) {
      debugPrint('Failed to clean balance history for removed room: $e');
    }
    notifyListeners();
    ensureCurrentBalances();
  }

  Future<void> switchBinding(int index) async {
    if (index < 0 || index >= _bindings.length) return;
    _currentIndex = index;
    await _prefs.setInt(_keyCurrentRoomIndex, _currentIndex);
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
      _isSwitching = false;
      notifyListeners();
      ensureCurrentBalances();
    }
  }

  /// 返回当前房间+类型的内存缓存；不存在或满 30 分钟时重新请求。
  Future<RoomInfo> ensureBalance(int balanceType) async {
    final binding = currentBinding;
    if (binding == null) throw BalanceQueryException('未绑定房间');
    return _loadBalanceFor(binding, balanceType);
  }

  /// 清空当前值并强制向服务端请求最新余额。
  Future<RoomInfo> refreshBalance(int balanceType) async {
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
    final entry = _balanceEntryFor(binding, balanceType);
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
        if (_bindings.any(
          (item) => _roomKeyFor(item) == _roomKeyFor(binding),
        )) {
          await _recordHistory(info, binding, balanceType);
        }
      },
    );
  }

  /// 兼容现有调用：原方法语义是每次都请求，故委托强制刷新。
  Future<RoomInfo> queryElectricInfo() => refreshBalance(kBalanceTypeElectric);

  /// 兼容现有调用：原方法语义是每次都请求，故委托强制刷新。
  Future<RoomInfo> queryAcInfo() => refreshBalance(kBalanceTypeAc);

  Future<List<CampusItem>> getCampusList() => _loadResource(
    _campusEntry,
    _payappApi.getCampus,
    clearValueOnLoad: false,
  );

  Future<List<BuildingItem>> getArchitectureList(String schoolCode) {
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
        if (onLoaded != null) await onLoaded(loaded);
        entry.value = loaded;
        entry.updatedAt = _now();
        return loaded;
      } catch (e) {
        entry.error = e;
        rethrow;
      } finally {
        entry.isLoading = false;
        entry.inFlight = null;
        notifyListeners();
      }
    }

    final future = execute();
    entry.inFlight = future;
    return future;
  }

  /// 拉取指定房间+类型的历史记录(默认 1 年)。
  /// 若 [since] 为 null 则取 [_balanceHistoryRetention] 之前到现在。
  /// [until] 为 null 表示不设上界(到现在)。
  Future<List<BalanceRecord>> getBalanceHistory({
    required int balanceType,
    DateTime? since,
    DateTime? until,
  }) async {
    final binding = currentBinding;
    if (binding == null) return const [];
    final from = since ?? _now().toUtc().subtract(_balanceHistoryRetention);
    return _db.getBalanceRecords(
      roomKey: _roomKeyFor(binding),
      balanceType: balanceType,
      since: from,
      until: until,
    );
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
  }

  bool _isFresh<T>(_ResourceEntry<T> entry, Duration cacheDuration) {
    final updatedAt = entry.updatedAt;
    return entry.value != null &&
        updatedAt != null &&
        _now().difference(updatedAt) < cacheDuration;
  }

  String _roomKeyFor(RoomBinding binding) {
    return '${binding.schoolCode}_${binding.regCode}_${binding.unitCode}_${binding.roomNo}';
  }

  String _unitKey(String schoolCode, String regCode) =>
      '${schoolCode}_$regCode';

  /// 仅在成功请求后记录一条历史快照。失败不影响主流程。
  Future<void> _recordHistory(
    RoomInfo info,
    RoomBinding binding,
    int balanceType,
  ) async {
    try {
      final now = _now().toUtc();
      final record = BalanceRecord(
        roomKey: _roomKeyFor(binding),
        balanceType: balanceType,
        timestamp: now,
        balance: double.tryParse(info.balance) ?? 0,
        price: double.tryParse(info.price) ?? 0,
      );
      await _db.insertBalanceRecord(record);
      await _db.deleteBalanceRecordsBefore(
        now.subtract(_balanceHistoryRetention),
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
