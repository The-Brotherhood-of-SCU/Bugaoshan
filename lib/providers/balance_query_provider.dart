import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/models/balance_record.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/api/payapp_api_service.dart';
import 'package:bugaoshan/services/api/balance_query_service.dart';
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

class BalanceQueryProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final PayAppApiService _payappApi;
  final DatabaseService _db;
  final PayAppAuth _payAppAuth;
  final AppConfigProvider _appConfig;

  bool _lastPayAppReady = false;
  bool _autoSampling = false;

  BalanceQueryProvider(
    this._prefs,
    this._payappApi,
    this._db,
    this._payAppAuth,
    this._appConfig,
  ) {
    _loadBindingInfo();
    _payAppAuth.addListener(_onPayAppAuthChanged);
    _lastPayAppReady = _payAppAuth.isReady;
  }

  /// PayAppAuth 状态变化:isReady 由 false→true 时(登录成功或 SSO 重连),
  /// 若用户开启了"登录后自动采样"开关,且当前房间今日尚无记录,则静默采样一次。
  void _onPayAppAuthChanged() {
    final ready = _payAppAuth.isReady;
    if (ready && !_lastPayAppReady) {
      _maybeAutoSample();
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

      // 检查今天是否已有电费或空调记录;任一缺失就补采
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
          _electricInfo = await _payappApi.queryRoomInfo(
            cusNo: binding.cusNo,
            type: kBalanceTypeElectric,
            cusName: binding.cusName,
          );
          await _recordHistory(_electricInfo!, binding, kBalanceTypeElectric);
        } catch (e) {
          debugPrint('Auto-sample electric failed: $e');
        }
      }
      if (acRecords.isEmpty) {
        try {
          _acInfo = await _payappApi.queryRoomInfo(
            cusNo: binding.cusNo,
            type: kBalanceTypeAc,
            cusName: binding.cusName,
          );
          await _recordHistory(_acInfo!, binding, kBalanceTypeAc);
        } catch (e) {
          debugPrint('Auto-sample AC failed: $e');
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Auto-sample balance failed: $e');
    } finally {
      _autoSampling = false;
    }
  }

  List<RoomBinding> _bindings = [];
  List<RoomBinding> get bindings => _bindings;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  RoomBinding? get currentBinding =>
      _bindings.isNotEmpty && _currentIndex < _bindings.length
      ? _bindings[_currentIndex]
      : null;

  String? _error;
  String? get error => _error;

  RoomInfo? _electricInfo;
  RoomInfo? get electricInfo => _electricInfo;

  RoomInfo? _acInfo;
  RoomInfo? get acInfo => _acInfo;

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
    notifyListeners();
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
    _electricInfo = null;
    _acInfo = null;
    await _saveBindingInfo();
    // 同步删除该房间的历史记录,避免残留
    try {
      await _db.deleteBalanceRecordsByRoom(_roomKeyFor(removed));
    } catch (e) {
      debugPrint('Failed to clean balance history for removed room: $e');
    }
    notifyListeners();
  }

  bool _isSwitching = false;
  bool get isSwitching => _isSwitching;

  Future<void> switchBinding(int index) async {
    if (index < 0 || index >= _bindings.length) return;
    _currentIndex = index;
    await _prefs.setInt(_keyCurrentRoomIndex, _currentIndex);
    _electricInfo = null;
    _acInfo = null;
    _isSwitching = true;
    notifyListeners();

    try {
      final binding = currentBinding!;
      await _payappApi.verificationRoom(
        cusNo: binding.cusNo,
        type: 1,
        cusName: binding.cusName,
        schoolCode: binding.schoolCode,
        regCode: binding.regCode,
        unitCode: binding.unitCode,
        roomNo: binding.roomNo,
      );
    } finally {
      _isSwitching = false;
      notifyListeners();
    }
  }

  Future<List<CampusItem>> getCampusList() async {
    return await _payappApi.getCampus();
  }

  Future<List<BuildingItem>> getArchitectureList(String schoolCode) async {
    return await _payappApi.getArchitecture(schoolCode);
  }

  Future<List<UnitItem>> getUnitList(String schoolCode, String regCode) async {
    return await _payappApi.getUnit(schoolCode, regCode);
  }

  Future<bool> verifyRoom(
    String cusNo,
    int type,
    String cusName,
    String schoolCode,
    String regCode,
    String unitCode,
    String roomNo,
  ) async {
    return await _payappApi.verificationRoom(
      cusNo: cusNo,
      type: type,
      cusName: cusName,
      schoolCode: schoolCode,
      regCode: regCode,
      unitCode: unitCode,
      roomNo: roomNo,
    );
  }

  Future<RoomInfo> queryElectricInfo() async {
    final binding = currentBinding;
    if (binding == null) throw BalanceQueryException('未绑定房间');

    _electricInfo = await _payappApi.queryRoomInfo(
      cusNo: binding.cusNo,
      type: kBalanceTypeElectric,
      cusName: binding.cusName,
    );
    await _recordHistory(_electricInfo!, binding, kBalanceTypeElectric);
    notifyListeners();
    return _electricInfo!;
  }

  Future<RoomInfo> queryAcInfo() async {
    final binding = currentBinding;
    if (binding == null) throw BalanceQueryException('未绑定房间');

    _acInfo = await _payappApi.queryRoomInfo(
      cusNo: binding.cusNo,
      type: kBalanceTypeAc,
      cusName: binding.cusName,
    );
    await _recordHistory(_acInfo!, binding, kBalanceTypeAc);
    notifyListeners();
    return _acInfo!;
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
    final from =
        since ?? DateTime.now().toUtc().subtract(_balanceHistoryRetention);
    return _db.getBalanceRecords(
      roomKey: _roomKeyFor(binding),
      balanceType: balanceType,
      since: from,
      until: until,
    );
  }

  String _roomKeyFor(RoomBinding binding) {
    return '${binding.schoolCode}_${binding.regCode}_${binding.unitCode}_${binding.roomNo}';
  }

  /// 仅在用户主动查询成功后记录一条历史快照。
  /// 失败仅 debugPrint,不影响主流程。
  Future<void> _recordHistory(
    RoomInfo info,
    RoomBinding binding,
    int balanceType,
  ) async {
    try {
      final record = BalanceRecord(
        roomKey: _roomKeyFor(binding),
        balanceType: balanceType,
        timestamp: DateTime.now().toUtc(),
        balance: double.tryParse(info.balance) ?? 0,
        price: double.tryParse(info.price) ?? 0,
      );
      await _db.insertBalanceRecord(record);
      // 惰性清理过期数据(不阻塞主流程)
      await _db.deleteBalanceRecordsBefore(
        DateTime.now().toUtc().subtract(_balanceHistoryRetention),
      );
    } catch (e) {
      debugPrint('Failed to record balance history: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
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
