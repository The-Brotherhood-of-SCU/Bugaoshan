import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;

class CcylService {
  static const _base = 'https://dekt.scu.edu.cn';
  static const _apiBase = 'https://dekt.scu.edu.cn/ccyl-api';

  static final Map<String, String> _headers = {
    'Accept': 'application/json, text/plain, */*',
    'Content-Type': 'application/json;charset=UTF-8',
    'Origin': _base,
    'Referer': _base,
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0',
  };

  String? _token;
  String? get token => _token;

  CcylUser? _currentUser;
  CcylUser? get currentUser => _currentUser;

  bool get isLoggedIn => _token != null;

  Future<void> login(String oauthCode) async {
    final resp = await http.post(
      Uri.parse('$_apiBase/app/auth/loginByUc'),
      headers: _headers,
      body: jsonEncode({'code': oauthCode}),
    );
    dev.log('[CCYL] login response: ${resp.body}', name: 'CcylService');

    final json = _parseJson(resp.body, 'loginByUc');
    if (json['code'] != 0) {
      final msg = json['msg']?.toString() ?? '登录失败';
      throw CcylException(msg);
    }

    final token = json['token']?.toString();
    if (token == null) {
      throw CcylException('Token 字段缺失: ${resp.body}');
    }

    _token = token;
    _currentUser = CcylUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  Map<String, String> _authHeaders() {
    if (_token == null) throw CcylException('未登录');
    return {..._headers, 'token': _token!};
  }

  Future<List<CyclActivity>> searchActivities({
    int pageNum = 1,
    int pageSize = 10,
    String name = '',
    String level = '',
    String scoreType = '',
    String org = '',
    String order = '',
    String status = '',
    String quality = '',
  }) async {
    final resp = await http.post(
      Uri.parse('$_apiBase/app/activity/list-activity-library'),
      headers: _authHeaders(),
      body: jsonEncode({
        'pn': pageNum,
        'time': DateTime.now().millisecondsSinceEpoch.toString(),
        'ps': pageSize,
        'name': name,
        'level': level,
        'scoreType': scoreType,
        'org': org,
        'order': order,
        'status': status,
        'quality': quality,
      }),
    );
    dev.log(
      '[CCYL] search activities response: ${resp.body}',
      name: 'CcylService',
    );

    final json = _parseJson(resp.body, 'list-activity-library');
    if (json['code'] != 0) {
      final msg = json['msg']?.toString() ?? '获取活动列表失败';
      throw CcylException(msg);
    }

    final list = json['list'] as List<dynamic>?;
    if (list == null) return [];

    return list
        .map((e) => CyclActivity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CyclActivity>> getMyActivities({
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    final resp = await http.post(
      Uri.parse('$_apiBase/app/activity/list-mine'),
      headers: _authHeaders(),
      body: jsonEncode({
        'pn': pageNum,
        'time': DateTime.now().millisecondsSinceEpoch.toString(),
        'ps': pageSize,
      }),
    );
    dev.log('[CCYL] my activities response: ${resp.body}', name: 'CcylService');

    final json = _parseJson(resp.body, 'list-mine');
    if (json['code'] != 0) {
      final msg = json['msg']?.toString() ?? '获取我参与的活动失败';
      throw CcylException(msg);
    }

    final content = json['content'] as List<dynamic>?;
    if (content == null) return [];

    return content
        .map((e) => CyclActivity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CyclActivity>> getOrderedActivities({
    int pageNum = 1,
    int pageSize = 10,
    String name = '',
  }) async {
    final resp = await http.post(
      Uri.parse('$_apiBase/app/activity/list-ordered-activity-library'),
      headers: _authHeaders(),
      body: jsonEncode({
        'pn': pageNum,
        'time': DateTime.now().millisecondsSinceEpoch.toString(),
        'ps': pageSize,
        'name': name,
      }),
    );
    dev.log(
      '[CCYL] ordered activities response: ${resp.body}',
      name: 'CcylService',
    );

    final json = _parseJson(resp.body, 'list-ordered-activity-library');
    if (json['code'] != 0) {
      final msg = json['msg']?.toString() ?? '获取预约的活动失败';
      throw CcylException(msg);
    }

    final list = json['list'] as List<dynamic>?;
    if (list == null) return [];

    return list
        .map((e) => CyclActivity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CyclOrg>> getAllOrgs() async {
    final resp = await http.post(
      Uri.parse('$_apiBase/app/org/list-all'),
      headers: _authHeaders(),
      body: '{}',
    );
    dev.log('[CCYL] orgs response: ${resp.body}', name: 'CcylService');

    final json = _parseJson(resp.body, 'list-all');
    if (json['code'] != 0) {
      final msg = json['msg']?.toString() ?? '获取组织列表失败';
      throw CcylException(msg);
    }

    final list = json['list'] as List<dynamic>?;
    if (list == null) return [];

    return list
        .map((e) => CyclOrg.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, List<CyclDict>>> getDicts(List<String> groupCodes) async {
    final results = <String, List<CyclDict>>{};

    for (final code in groupCodes) {
      final resp = await http.post(
        Uri.parse('$_apiBase/app/dict/query-by-group-code'),
        headers: _authHeaders(),
        body: jsonEncode({'groupCode': code}),
      );

      final json = _parseJson(resp.body, 'dict/$code');
      if (json['code'] == 0) {
        final list = json['list'] as List<dynamic>?;
        if (list != null) {
          results[code] = list
              .map((e) => CyclDict.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    }

    return results;
  }

  void logout() {
    _token = null;
    _currentUser = null;
  }

  void restoreToken(String token) {
    _token = token;
  }

  static Map<String, dynamic> _parseJson(String body, String api) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw CcylException('[$api] JSON 解析失败: $body');
    }
  }
}

class CyclActivity {
  final String activityLibraryId;
  final String orgNo;
  final String name;
  final String activityName;
  final String level;
  final String star;
  final List<String> quality;
  final double classHour;
  final String? describe;
  final String poster;
  final String? startTime;
  final String? endTime;
  final String? enrollStartTime;
  final String? enrollEndTime;
  final int quota;
  final String activityTarget;
  final String isSignIn;
  final String isSignOut;
  final String? mobile;
  final String? activityAddress;
  final String? activityLon;
  final String? activityLat;
  final String status;
  final String? statusName;
  final String orgName;
  final String? levelName;
  final String? starName;
  final String? qualityName;
  final bool doing;
  final bool subscribed;

  CyclActivity({
    required this.activityLibraryId,
    required this.orgNo,
    required this.name,
    required this.activityName,
    required this.level,
    required this.star,
    required this.quality,
    required this.classHour,
    this.describe,
    required this.poster,
    this.startTime,
    this.endTime,
    this.enrollStartTime,
    this.enrollEndTime,
    required this.quota,
    required this.activityTarget,
    required this.isSignIn,
    required this.isSignOut,
    this.mobile,
    this.activityAddress,
    this.activityLon,
    this.activityLat,
    required this.status,
    this.statusName,
    required this.orgName,
    this.levelName,
    this.starName,
    this.qualityName,
    required this.doing,
    required this.subscribed,
  });

  factory CyclActivity.fromJson(Map<String, dynamic> json) {
    return CyclActivity(
      activityLibraryId: json['activityLibraryId']?.toString() ?? '',
      orgNo: json['orgNo']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      activityName: json['activityName']?.toString() ?? '',
      level: json['level']?.toString() ?? '',
      star: json['star']?.toString() ?? '',
      quality:
          (json['quality'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      classHour: (json['classHour'] as num?)?.toDouble() ?? 0.0,
      describe: json['describe']?.toString(),
      poster: json['poster']?.toString() ?? '',
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      enrollStartTime: json['enrollStartTime']?.toString(),
      enrollEndTime: json['enrollEndTime']?.toString(),
      quota: json['quota'] is int
          ? json['quota']
          : int.tryParse(json['quota']?.toString() ?? '0') ?? 0,
      activityTarget: json['activityTarget']?.toString() ?? '',
      isSignIn: json['isSignIn']?.toString() ?? '0',
      isSignOut: json['isSignOut']?.toString() ?? '0',
      mobile: json['mobile']?.toString(),
      activityAddress: json['activityAddress']?.toString(),
      activityLon: json['activityLon']?.toString(),
      activityLat: json['activityLat']?.toString(),
      status: json['status']?.toString() ?? '',
      statusName: json['statusName']?.toString(),
      orgName: json['orgName']?.toString() ?? '',
      levelName: json['levelName']?.toString(),
      starName: json['starName']?.toString(),
      qualityName: json['qualityName']?.toString(),
      doing: json['doing'] == true,
      subscribed: json['subscribed'] == true,
    );
  }
}

class CyclOrg {
  final String orgNo;
  final String orgName;
  final String? parentNo;

  CyclOrg({required this.orgNo, required this.orgName, this.parentNo});

  factory CyclOrg.fromJson(Map<String, dynamic> json) {
    return CyclOrg(
      orgNo: json['orgNo']?.toString() ?? '',
      orgName: json['orgName']?.toString() ?? '',
      parentNo: json['parentNo']?.toString(),
    );
  }
}

class CyclDict {
  final String code;
  final String name;
  final String? groupCode;

  CyclDict({required this.code, required this.name, this.groupCode});

  factory CyclDict.fromJson(Map<String, dynamic> json) {
    return CyclDict(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      groupCode: json['groupCode']?.toString(),
    );
  }
}

class CcylUser {
  final String id;
  final String userName;
  final String realname;
  final String orgName;
  final String? mobile;
  final String? headImgUrl;
  final String? majorName;
  final String? classes;
  final String? grade;

  CcylUser({
    required this.id,
    required this.userName,
    required this.realname,
    required this.orgName,
    this.mobile,
    this.headImgUrl,
    this.majorName,
    this.classes,
    this.grade,
  });

  factory CcylUser.fromJson(Map<String, dynamic> json) {
    return CcylUser(
      id: json['id']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      realname: json['realname']?.toString() ?? '',
      orgName: json['orgName']?.toString() ?? '',
      mobile: json['mobile']?.toString(),
      headImgUrl: json['headImgUrl']?.toString(),
      majorName: json['majorName']?.toString(),
      classes: json['classes']?.toString(),
      grade: json['grade']?.toString(),
    );
  }
}

class CcylException implements Exception {
  final String message;
  const CcylException(this.message);
  @override
  String toString() => message;
}
