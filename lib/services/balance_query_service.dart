import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/json_utils.dart';

class BalanceQueryService {
  static const _base = 'https://payapp.scu.edu.cn/eleFees';

  static final Map<String, String> _headers = {
    'Accept': 'application/json, text/plain, */*',
    'Content-Type': 'application/json;charset=UTF-8',
    'Origin': _base,
    'Referer': _base,
    'User-Agent': kDefaultUserAgent,
  };

  Future<List<CampusItem>> getCampus(http.Client client) async {
    final resp = await client.post(
      Uri.parse('$_base/electric/getCampus'),
      headers: _headers,
      body: '{}',
    );
    final json = parseJson(
      resp.body,
      'getCampus',
      (msg) => BalanceQueryException(msg),
    );
    if (json['respCode'] != '00') {
      throw BalanceQueryException(json['respDesc'] ?? '获取校区失败');
    }
    final datas =
        (json['data'] as Map<String, dynamic>?)?['datas'] as List? ?? [];
    return datas
        .map((e) => CampusItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BuildingItem>> getArchitecture(
    http.Client client,
    String schoolCode,
  ) async {
    final resp = await client.post(
      Uri.parse('$_base/electric/getArchitecture'),
      headers: _headers,
      body: jsonEncode({'schoolCode': schoolCode}),
    );
    final json = parseJson(
      resp.body,
      'getArchitecture',
      (msg) => BalanceQueryException(msg),
    );
    if (json['respCode'] != '00') {
      throw BalanceQueryException(json['respDesc'] ?? '获取楼栋失败');
    }
    final datas =
        (json['data'] as Map<String, dynamic>?)?['datas'] as List? ?? [];
    return datas
        .map((e) => BuildingItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UnitItem>> getUnit(
    http.Client client,
    String schoolCode,
    String regCode,
  ) async {
    final resp = await client.post(
      Uri.parse('$_base/electric/getUnit'),
      headers: _headers,
      body: jsonEncode({'schoolCode': schoolCode, 'regCode': regCode}),
    );
    final json = parseJson(
      resp.body,
      'getUnit',
      (msg) => BalanceQueryException(msg),
    );
    if (json['respCode'] != '00') {
      throw BalanceQueryException(json['respDesc'] ?? '获取单元失败');
    }
    final datas =
        (json['data'] as Map<String, dynamic>?)?['datas'] as List? ?? [];
    return datas
        .map((e) => UnitItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> verificationRoom(
    http.Client client,
    String cusNo,
    int type,
    String cusName,
    String schoolCode,
    String regCode,
    String unitCode,
    String roomNo,
  ) async {
    final resp = await client.post(
      Uri.parse('$_base/electric/verificationRoom'),
      headers: _headers,
      body: jsonEncode({
        'cusNo': cusNo,
        'type': type,
        'cusName': cusName,
        'schoolCode': schoolCode,
        'regCode': regCode,
        'unitCode': unitCode,
        'roomNo': roomNo,
      }),
    );
    final json = parseJson(
      resp.body,
      'verificationRoom',
      (msg) => BalanceQueryException(msg),
    );
    if (json['respCode'] != '00') {
      throw BalanceQueryException(json['respDesc'] ?? '验证房间失败');
    }
    return (json['data'] as Map<String, dynamic>?)?['status'] == true;
  }

  Future<RoomInfo> queryRoomInfo(
    http.Client client,
    String cusNo,
    int type,
    String cusName,
  ) async {
    final resp = await client.post(
      Uri.parse('$_base/electric/queryRoomInfo'),
      headers: _headers,
      body: jsonEncode({'cusNo': cusNo, 'type': type, 'cusName': cusName}),
    );
    final json = parseJson(
      resp.body,
      'queryRoomInfo',
      (msg) => BalanceQueryException(msg),
    );
    if (json['respCode'] != '00') {
      throw BalanceQueryException(json['respDesc'] ?? '查询失败');
    }
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw BalanceQueryException('查询数据为空');
    }
    return RoomInfo.fromJson(data);
  }
}

class CampusItem {
  final String name;
  final String code;

  CampusItem({required this.name, required this.code});

  factory CampusItem.fromJson(Map<String, dynamic> json) {
    return CampusItem(
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
    );
  }
}

class BuildingItem {
  final String name;
  final String code;

  BuildingItem({required this.name, required this.code});

  factory BuildingItem.fromJson(Map<String, dynamic> json) {
    return BuildingItem(
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
    );
  }
}

class UnitItem {
  final String name;
  final String code;

  UnitItem({required this.name, required this.code});

  factory UnitItem.fromJson(Map<String, dynamic> json) {
    return UnitItem(
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
    );
  }
}

class RoomInfo {
  final String? type;
  final String cusNo;
  final String? cusName;
  final String roomNo;
  final String schoolName;
  final String regName;
  final String unitName;
  final String price;
  final String balance;

  RoomInfo({
    this.type,
    required this.cusNo,
    this.cusName,
    required this.roomNo,
    required this.schoolName,
    required this.regName,
    required this.unitName,
    required this.price,
    required this.balance,
  });

  factory RoomInfo.fromJson(Map<String, dynamic> json) {
    return RoomInfo(
      type: json['type']?.toString(),
      cusNo: json['cusNo']?.toString() ?? '',
      cusName: json['cusName']?.toString(),
      roomNo: json['roomNo']?.toString() ?? '',
      schoolName: json['schoolName']?.toString() ?? '',
      regName: json['regName']?.toString() ?? '',
      unitName: json['unitName']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      balance: json['balance']?.toString() ?? '',
    );
  }
}

class BalanceQueryException implements Exception {
  final String message;
  BalanceQueryException(this.message);

  @override
  String toString() => message;
}

class BalanceQueryAuthException implements Exception {
  final String message;
  BalanceQueryAuthException(this.message);

  @override
  String toString() => message;
}
