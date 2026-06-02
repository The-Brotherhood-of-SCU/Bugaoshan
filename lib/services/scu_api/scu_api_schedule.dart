part of 'scu_api_service.dart';

/// 课表与学期相关的教务系统 API。
extension ScuApiSchedule on ScuApiService {
  /// 从教务系统首页获取当前教学周数
  Future<int> fetchCurrentWeek() async {
    return _authManager.scu.request((client) async {
      final resp = await client.get(
        Uri.parse('$kZhjwBase/'),
        headers: {
          'Accept': 'text/html,*/*',
          'Referer': '$kZhjwBase/',
          'User-Agent': ScuAuthService.requestHeaders['User-Agent']!,
        },
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      final match = RegExp(r'第(\d+)周').firstMatch(body);
      if (match == null) {
        throw ScuLoginException('无法获取当前周数，请检查教务系统状态');
      }
      return int.parse(match.group(1)!);
    });
  }

  /// 获取历年学期列表
  Future<List<({String value, String label})>> fetchSemesters() async {
    return _authManager.scu.request((client) async {
      final resp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/courseSelect'
          '/calendarSemesterCurriculum/index',
        ),
        headers: {
          'Accept': 'text/html,*/*',
          'Referer': '$kZhjwBase/',
          'User-Agent': ScuAuthService.requestHeaders['User-Agent']!,
        },
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      final regex = RegExp(
        r'<option[^>]+value="([^"]+)"[^>]*>(.*?)</option>',
        dotAll: true,
      );
      final matches = regex.allMatches(body);
      final semesters = matches.map((m) {
        final value = m.group(1)!.trim();
        final label = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        return (value: value, label: label);
      }).toList();
      if (semesters.isEmpty) {
        throw ScuLoginException('无法获取学期列表，请检查登录状态');
      }
      return semesters;
    });
  }

  /// 获取指定学期课表 JSON，[planCode] 如 '2025-2026-2-1'
  Future<Map<String, dynamic>> fetchJwxtSchedule({
    required String planCode,
  }) async {
    return _authManager.scu.request((client) async {
      final resp = await client.post(
        Uri.parse(
          '$kZhjwBase/student/courseSelect'
          '/thisSemesterCurriculum/ajaxStudentSchedule/callback',
        ),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Referer':
              '$kZhjwBase/student/courseSelect/calendarSemesterCurriculum/index',
          'User-Agent': ScuAuthService.requestHeaders['User-Agent']!,
          'X-Requested-With': 'XMLHttpRequest',
        },
        body: 'planCode=$planCode',
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      return parseJson(body, 'jwxt/schedule', (msg) => ScuLoginException(msg));
    });
  }
}
