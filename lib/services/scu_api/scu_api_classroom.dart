part of 'scu_api_service.dart';

/// 教室查询相关的教务系统 API。
extension ScuApiClassroom on ScuApiService {
  /// 获取教室查询页面的校区和教学楼列表
  Future<({List<ClassroomCampus> campuses, List<ClassroomBuilding> buildings})>
  fetchClassroomIndex() async {
    return _authManager.scu.request((client) async {
      final resp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/teachingResources/classroomUseStatus/index',
        ),
        headers: {
          'Accept': 'text/html,*/*',
          'Referer': '$kZhjwBase/',
          'User-Agent': ScuAuthService.requestHeaders['User-Agent']!,
        },
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      final xqMatch = RegExp(
        r"""<input[^>]+id="xqList"[^>]+value='([^']+)'""",
      ).firstMatch(body);
      if (xqMatch == null) {
        throw ScuLoginException('无法解析校区列表');
      }
      final xqList = (jsonDecode(xqMatch.group(1)!) as List)
          .map((e) => ClassroomCampus.fromJson(e as Map<String, dynamic>))
          .toList();

      final jxlMatch = RegExp(
        r"""<input[^>]+id="jxlList"[^>]+value='([^']+)'""",
      ).firstMatch(body);
      if (jxlMatch == null) {
        throw ScuLoginException('无法解析教学楼列表');
      }
      final jxlList = (jsonDecode(jxlMatch.group(1)!) as List)
          .map((e) => ClassroomBuilding.fromJson(e as Map<String, dynamic>))
          .toList();

      return (campuses: xqList, buildings: jxlList);
    });
  }

  /// 获取教学楼的教室类型列表
  Future<List<ClassroomType>> fetchClassroomTypes({
    required String campusNumber,
    required String buildingNumber,
    required String campusName,
    required String buildingName,
  }) async {
    return _authManager.scu.request((client) async {
      final resp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/teachingResources/classroomUseStatus'
          '/$campusNumber/$buildingNumber'
          '/${Uri.encodeComponent(campusName)}/${Uri.encodeComponent(buildingName)}',
        ),
        headers: {
          'Accept': 'text/html,*/*',
          'Referer': '$kZhjwBase/',
          'User-Agent': ScuAuthService.requestHeaders['User-Agent']!,
        },
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      final match = RegExp(
        r"""<input[^>]+id="classroomTypes"[^>]+value='([^']+)'""",
      ).firstMatch(body);
      if (match == null) return <ClassroomType>[];
      return (jsonDecode(match.group(1)!) as List)
          .map((e) => ClassroomType.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// 查询教室使用情况
  Future<ClassroomQueryResult> fetchClassroomAvailability({
    required String campusNumber,
    required String buildingNumber,
    String classroomType = '',
    String classroomName = '',
    String seatFrom = '',
    String seatTo = '',
    String searchDate = '',
  }) async {
    return _authManager.scu.request((client) async {
      final resp = await client.post(
        Uri.parse(
          '$kZhjwBase/student/teachingResources/classroomUseStatus/jasInfo',
        ),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Referer':
              '$kZhjwBase/student/teachingResources/classroomUseStatus/index',
          'User-Agent': ScuAuthService.requestHeaders['User-Agent']!,
          'X-Requested-With': 'XMLHttpRequest',
        },
        body:
            'xqh=${Uri.encodeComponent(campusNumber)}'
            '&jxlh=${Uri.encodeComponent(buildingNumber)}'
            '&jslx=${Uri.encodeComponent(classroomType)}'
            '&jasm=${Uri.encodeComponent(classroomName)}'
            '&zwFrom=${Uri.encodeComponent(seatFrom)}'
            '&zwTo=${Uri.encodeComponent(seatTo)}'
            '&searchDate=${Uri.encodeComponent(searchDate)}',
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      return ClassroomQueryResult.fromJson(
        parseJson(
          body,
          'classroomUseStatus/jasInfo',
          (msg) => ScuLoginException(msg),
        ),
      );
    });
  }
}
