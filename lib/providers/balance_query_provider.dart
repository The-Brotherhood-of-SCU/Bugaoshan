import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/balance_query_service.dart';

const _keyBindingInfo = 'balance_query_binding';
const _keyCurrentRoomIndex = 'balance_query_current_room';

class BalanceQueryProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final BalanceQueryService _service = BalanceQueryService();

  BalanceQueryProvider(this._prefs) {
    _loadBindingInfo();
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

  http.Client? _client;
  http.Client? get client => _client;

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
    _bindings.removeAt(index);
    if (_currentIndex >= _bindings.length) {
      _currentIndex = _bindings.isEmpty ? 0 : _bindings.length - 1;
    }
    await _saveBindingInfo();
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
    notifyListeners(); // 先通知 UI 切换房间名、显示加载状态

    try {
      final binding = currentBinding!;
      final client = await _ensureClient();
      await _service.verificationRoom(
        client,
        binding.cusNo,
        1,
        binding.cusName,
        binding.schoolCode,
        binding.regCode,
        binding.unitCode,
        binding.roomNo,
      );
    } finally {
      _isSwitching = false;
      notifyListeners(); // 验证完成，通知 BalanceCard 可以查询余额了
    }
  }

  Future<List<CampusItem>> getCampusList() async {
    final client = await _ensureClient();
    return await _service.getCampus(client);
  }

  Future<List<BuildingItem>> getArchitectureList(String schoolCode) async {
    final client = await _ensureClient();
    return await _service.getArchitecture(client, schoolCode);
  }

  Future<List<UnitItem>> getUnitList(String schoolCode, String regCode) async {
    final client = await _ensureClient();
    return await _service.getUnit(client, schoolCode, regCode);
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
    final client = await _ensureClient();
    return await _service.verificationRoom(
      client,
      cusNo,
      type,
      cusName,
      schoolCode,
      regCode,
      unitCode,
      roomNo,
    );
  }

  Future<RoomInfo> queryElectricInfo() async {
    final binding = currentBinding;
    if (binding == null) throw BalanceQueryException('未绑定房间');

    final client = await _ensureClient();
    _electricInfo = await _service.queryRoomInfo(
      client,
      binding.cusNo,
      1,
      binding.cusName,
    );
    notifyListeners();
    return _electricInfo!;
  }

  Future<RoomInfo> queryAcInfo() async {
    final binding = currentBinding;
    if (binding == null) throw BalanceQueryException('未绑定房间');

    final client = await _ensureClient();
    _acInfo = await _service.queryRoomInfo(
      client,
      binding.cusNo,
      2,
      binding.cusName,
    );
    notifyListeners();
    return _acInfo!;
  }

  Future<http.Client> _ensureClient() async {
    if (_client != null) return _client!;
    _client = await _service.getAuthenticatedClient();
    return _client!;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _client?.close();
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
