import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/services/api/payapp_api_service.dart';
import 'package:bugaoshan/services/balance/balance_query_service.dart';

const _keyBindingInfo = 'balance_query_binding';
const _keyCurrentRoomIndex = 'balance_query_current_room';

class BalanceQueryProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final PayAppApiService _payappApi;

  BalanceQueryProvider(this._prefs, this._payappApi) {
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
      type: 1,
      cusName: binding.cusName,
    );
    notifyListeners();
    return _electricInfo!;
  }

  Future<RoomInfo> queryAcInfo() async {
    final binding = currentBinding;
    if (binding == null) throw BalanceQueryException('未绑定房间');

    _acInfo = await _payappApi.queryRoomInfo(
      cusNo: binding.cusNo,
      type: 2,
      cusName: binding.cusName,
    );
    notifyListeners();
    return _acInfo!;
  }

  void clearError() {
    _error = null;
    notifyListeners();
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
