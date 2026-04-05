import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:Bugaoshan/pages/campus/models/building_model.dart';
import 'package:Bugaoshan/pages/campus/models/room_model.dart';

class CirApiService {
  static const String baseUrl = 'https://cir.scu.edu.cn';

  Future<List<BuildingModel>> fetchBuildings() async {
    final response = await http.post(
      Uri.parse('$baseUrl/cir/jxlConfig'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch buildings: ${response.statusCode}');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList
        .map((json) => BuildingModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<RoomQueryResult> fetchRoomData(String buildingLocation) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cir/XLRoomData'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'jxlname=$buildingLocation',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch room data: ${response.statusCode}');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    return RoomQueryResult.fromJson(decoded);
  }
}
