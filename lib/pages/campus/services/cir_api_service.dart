import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:bugaoshan/pages/campus/models/building_model.dart';
import 'package:bugaoshan/pages/campus/models/room_model.dart';

class CampusNetworkException implements Exception {}

class CirApiService {
  static const String baseUrl = 'https://cir.scu.edu.cn';

  Future<List<BuildingModel>> fetchBuildings() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/cir/jxlConfig'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      developer.log(
        'fetchBuildings status: ${response.statusCode}',
        name: 'CirApi',
      );
      developer.log('fetchBuildings body: ${response.body}', name: 'CirApi');

      if (response.statusCode == 483) {
        throw CampusNetworkException();
      }
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch buildings: ${response.statusCode}');
      }

      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList
          .map((json) => BuildingModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      developer.log(
        'fetchBuildings error: $e',
        name: 'CirApi',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<RoomQueryResult> fetchRoomData(String buildingLocation) async {
    try {
      developer.log(
        'fetchRoomData location: $buildingLocation',
        name: 'CirApi',
      );
      final response = await http
          .post(
            Uri.parse('$baseUrl/cir/XLRoomData'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'jxlname=${Uri.encodeComponent(buildingLocation)}',
          )
          .timeout(const Duration(seconds: 15));

      developer.log(
        'fetchRoomData status: ${response.statusCode}',
        name: 'CirApi',
      );
      developer.log('fetchRoomData body: ${response.body}', name: 'CirApi');

      if (response.statusCode == 483) {
        throw CampusNetworkException();
      }
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch room data: ${response.statusCode}');
      }

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return RoomQueryResult.fromJson(decoded);
    } catch (e, stack) {
      developer.log(
        'fetchRoomData error: $e',
        name: 'CirApi',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
