import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/api/api_request.dart';
import 'package:bugaoshan/services/api/service_form_models.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/service_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/utils/constants.dart';

/// 网上办事大厅 API Service（第1层）
///
/// service.scu.edu.cn 的请假申请业务 API。认证通过 [ServiceAuth]
/// （CAS 会话 cookie `vjuid`），请求由 [CookieClient] 自动携带。
///
/// # 真实接口（已通过抓包确认）
///
/// 请假事项（app_id=350 "离校请假"）：
/// - 表单 schema：`GET /site/form/start-data?app_id=350`
/// - 流程信息：  `GET /site/process/start-info?app_id=350`
/// - 流程变量：  `GET /site/process/variables?app_id=350`
/// - 发起人部门：`GET /site/user/select-department?app_id=350`
/// - **提交申请**：`POST /site/apps/launch`
/// - 我的申请：  `GET /site/process/inst-list`
///
/// 提交体结构（来自真实抓包，[ServiceLeaveSubmit]）：
/// `data={"app_id":"350","node_id":"","form_data":{"1419":{...}},"userview":1}&step=0&agent_uid=&starter_depart_id=395876`
class ServiceApiService {
  final ServiceAuth _auth;
  final AuthLogger _log;
  ServiceApiService(this._auth) : _log = getIt<AuthLogger>();

  static const String _base = 'https://service.scu.edu.cn';

  /// 请假事项 id（办事大厅"离校请假"，matter/start?id=350）
  static const String leaveAppId = '350';

  /// 接口路径（已通过抓包确认）。
  static const Map<String, String> paths = {
    'formStartData': '/site/form/start-data',
    'processStartInfo': '/site/process/start-info',
    'processVariables': '/site/process/variables',
    'selectDepartment': '/site/user/select-department',
    'dataSourceDetail': '/site/data-source/detail',
    'attachUpload': '/site/attach/auth-upload',
    'provinceDict': '/api/dictionary/province',
    'launch': '/site/apps/launch',
    'instList': '/site/process/inst-list',
  };

  /// DataSource_85（辅导员数据源）的配置 id（来自抓包 curl：id=8）。
  static const String tutorDataSourceId = '8';

  /// 接口已用真实抓包确认。提交/查询可直接调用。
  static const bool verified = true;

  Future<T> _request<T>(Future<T> Function(CookieClient client) fn) {
    return retryOnUnauthenticated(
      _auth.getClient,
      fn,
      invalidate: _auth.invalidate,
    );
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json, text/plain, */*',
    'Content-Type': 'application/x-www-form-urlencoded',
    'Origin': _base,
    'Referer': _base,
    'User-Agent': kDefaultUserAgent,
    'X-Requested-With': 'XMLHttpRequest',
  };

  Map<String, String> get _jsonHeaders => {
    'Accept': 'application/json, text/plain, */*',
    'Content-Type': 'application/json;charset=UTF-8',
    'Origin': _base,
    'Referer': _base,
    'User-Agent': kDefaultUserAgent,
    'X-Requested-With': 'XMLHttpRequest',
  };

  void _checkSessionExpiry(String body, int statusCode) {
    if (statusCode == 302 ||
        statusCode == 401 ||
        statusCode == 403 ||
        body.trim().isEmpty) {
      throw const UnauthenticatedException();
    }
  }

  Map<String, dynamic> _decodeResponse(String body, int statusCode) {
    _checkSessionExpiry(body, statusCode);
    // 诊断日志：记录非 2xx/非 JSON 的响应，便于定位服务端拒绝原因
    if (statusCode < 200 || statusCode >= 300) {
      debugPrint(
        'ServiceApi non-2xx: status=$statusCode body=${body.length > 500 ? body.substring(0, 500) : body}',
      );
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    // e:10042 表示未登录（vjuid cookie 缺失/失效），交给认证层重试
    if (json['e']?.toString() == '10042') {
      throw const UnauthenticatedException('办事大厅会话已失效');
    }
    // 业务错误记录到 AuthLogger，导出 auth log 可直接查看 e/m
    if (json['e']?.toString() != '0') {
      final msg = '业务错误 e=${json['e']} m=${json['m']} status=$statusCode';
      debugPrint('ServiceApi business error: $msg');
      _log.w('SERVICE', msg);
    }
    return json;
  }

  /// 获取请假事项的表单定义（字段 key、权限、已填数据）。
  Future<ServiceFormDefinition> fetchLeaveFormSchema() async {
    final json = await _request((client) async {
      final uri = Uri.parse('$_base${paths['formStartData']}').replace(
        queryParameters: {
          'app_id': leaveAppId,
          'node_id': '',
          'userview': '1',
          'agent_uid': '',
          'starter_depart_id': '395876',
        },
      );
      final resp = await client.get(uri, headers: _jsonHeaders);
      return _decodeResponse(resp.body, resp.statusCode);
    });
    if (json['e'] == 0 && json['d'] != null) {
      return ServiceFormDefinition.fromJson(
        json['d'] as Map<String, dynamic>,
      );
    }
    throw ServiceException(json['m'] ?? '获取表单定义失败');
  }

  /// 获取辅导员（DataSource_85 数据源）。
  ///
  /// 网页端发起页通过 `POST /site/data-source/detail` 拉取辅导员列表，
  /// 选中的辅导员填入 `Input_84`（姓名）与 `DataSource_85`（`{"list": name}`）。
  /// 参数来自真实抓包 curl（id=8, form_version_id=2357）。
  ///
  /// 返回辅导员姓名；失败返回 null（由调用方决定是否阻塞提交）。
  Future<String?> fetchTutor() async {
    final json = await _request((client) async {
      final body = Uri(
        queryParameters: {
          'id': tutorDataSourceId,
          'inst_id': '0',
          'app_id': leaveAppId,
          'form_version_id': '2357',
          'component': 'DataSource_85',
          'params[formId]': '1419',
          'params[pluginKey]': 'DataSource_85',
          'agent_uid': '',
          'starter_depart_id': '395876',
        },
      ).query;
      final resp = await client.post(
        Uri.parse('$_base${paths['dataSourceDetail']}'),
        headers: _headers,
        body: body,
      );
      return _decodeResponse(resp.body, resp.statusCode);
    });
    if (json['e'] != 0 || json['d'] == null) {
      _log.w('SERVICE', 'fetchTutor 失败 e=${json['e']} m=${json['m']}');
      return null;
    }
    final d = json['d'];
    debugPrint('ServiceApi fetchTutor response: ${jsonEncode(d)}');
    final tutor = _extractTutorName(d);
    _log.i('SERVICE', 'fetchTutor -> ${tutor ?? '(null)'}');
    return tutor;
  }

  /// 获取省市区字典（去往地址 Region_80）。
  ///
  /// 接口：`GET /api/dictionary/province?agent_uid=&starter_depart_id=395876`
  /// 返回 `d` 字段的原始列表（可能为树形或扁平，由调用方按真实结构解析）。
  Future<List<dynamic>> fetchProvinces() async {
    final json = await _request((client) async {
      final uri = Uri.parse('$_base${paths['provinceDict']}').replace(
        queryParameters: {
          'agent_uid': '',
          'starter_depart_id': '395876',
        },
      );
      final resp = await client.get(uri, headers: _jsonHeaders);
      return _decodeResponse(resp.body, resp.statusCode);
    });
    if (json['e'] != 0 || json['d'] == null) {
      _log.w('SERVICE', 'fetchProvinces 失败 e=${json['e']} m=${json['m']}');
      return const [];
    }
    final d = json['d'];
    if (d is List) return d;
    if (d is Map && d['list'] is List) return d['list'] as List;
    if (d is Map && d['children'] is List) return d['children'] as List;
    _log.w('SERVICE', 'fetchProvinces 未知结构: $d');
    return const [];
  }

  /// 从 data-source/detail 的响应中提取辅导员姓名。
  ///
  /// 真实响应：`{"e":0,"m":"操作成功","d":{"list":"张美成"}}`
  /// `d.list` 是辅导员姓名字符串（非数组）。兜底兼容 `d.list` 为数组 / `d.name` 等结构。
  String? _extractTutorName(dynamic d) {
    if (d is Map) {
      final listVal = d['list'];
      if (listVal is String && listVal.trim().isNotEmpty) {
        return listVal.trim();
      }
      if (listVal is List) {
        for (final item in listVal) {
          if (item is Map) {
            final name = item['name'] ?? item['realname'] ?? item['user_name'];
            if (name != null && name.toString().isNotEmpty) return name.toString();
          }
        }
        return null;
      }
      for (final k in ['name', 'realname', 'user_name']) {
        final v = d[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
    } else if (d is List) {
      for (final item in d) {
        if (item is Map) {
          final name = item['name'] ?? item['realname'] ?? item['user_name'];
          if (name != null && name.toString().isNotEmpty) return name.toString();
        }
      }
    }
    return null;
  }

  /// 上传附件（File_71 上传证明）。
  ///
  /// 接口：`POST /site/attach/auth-upload?category=all&inst_id=0`
  /// FormData 字段名 `upfile`。返回上传后的附件信息，用于组装 `File_71`：
  /// `[{"name": 文件名, "url": "…/auth-download?file_id=<id>", "id": <id>}]`
  ///
  /// [file] 本地图片文件。[fileName] 上传后的显示名（默认取文件 basename）。
  Future<ServiceAttachment> uploadAttachment(
    File file, {
    String? fileName,
  }) async {
    return _request((client) async {
      final uri = Uri.parse(
        '$_base${paths['attachUpload']}?category=all&inst_id=0',
      );
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'Accept': 'application/json, text/plain, */*',
          'Origin': _base,
          'Referer': '$_base/v2/matter/start?id=$leaveAppId',
          'User-Agent': kDefaultUserAgent,
          'X-Requested-With': 'XMLHttpRequest',
        })
        ..files.add(
          await http.MultipartFile.fromPath(
            'upfile',
            file.path,
            filename: fileName ?? file.uri.pathSegments.last,
          ),
        );

      final streamed = await client.send(request);
      final body = await streamed.stream.bytesToString();
      _checkSessionExpiry(body, streamed.statusCode);
      // 上传接口响应是 `{url, size, title, original, state, type, id}` 结构，
      // **没有 `e` 字段**！不能用 _decodeResponse（会误判业务错误），也不能用
      // `json['e'] != 0` 判断（null 恒为 true）。这里直接用 url/state/id 判断。
      final Map<String, dynamic> json;
      try {
        // 上传接口可能返回"JSON 字符串"（body 形如 `"{\"url\":...}"`），
        // 需解一层。也可能是直接的对象。这里统一先 decode，再处理 String 包裹。
        var decoded = jsonDecode(body);
        if (decoded is String) {
          decoded = jsonDecode(decoded);
        }
        json = decoded as Map<String, dynamic>;
      } catch (e) {
        _log.w('SERVICE', 'uploadAttachment 响应非 JSON: $body');
        throw ServiceException('上传失败');
      }
      final uploadOk = json['url'] != null || json['state']?.toString() == 'SUCCESS';
      if (!uploadOk || json['id'] == null) {
        _log.w('SERVICE', 'uploadAttachment 失败: $json');
        throw ServiceException('上传失败');
      }
      final id = json['id']?.toString() ?? '';
      final original = (json['original'] ?? '').toString();
      final uploadPath = paths['attachUpload'] ?? '/site/attach/auth-upload';
      final downloadPath = uploadPath.replaceAll('auth-upload', 'auth-download');
      final attachment = ServiceAttachment(
        name: original.isEmpty ? (fileName ?? 'attachment') : original,
        url: '$_base$downloadPath?file_id=$id',
        id: id,
      );
      _log.i('SERVICE', 'uploadAttachment -> id=$id name=$original');
      return attachment;
    });
  }

  /// 提交请假申请。
  ///
  /// [formData] 是 `form_data` 的完整字段 Map（key 为表单 id，如 "1419"）。
  /// [starterDepartId] 发起人部门 id（当前用户为 395876）。
  Future<void> submitLeave(
    Map<String, dynamic> formData, {
    String starterDepartId = '395876',
  }) async {
    final data = {
      'app_id': leaveAppId,
      'node_id': '',
      'form_data': formData,
      'userview': 1,
    };
    final body = Uri(
      queryParameters: {
        'data': jsonEncode(data),
        'step': '0',
        'agent_uid': '',
        'starter_depart_id': starterDepartId,
      },
    ).query;
    await _request((client) async {
      final resp = await client.post(
        Uri.parse('$_base${paths['launch']}'),
        headers: _headers,
        body: body,
      );
      final json = _decodeResponse(resp.body, resp.statusCode);
      if (json['e'] != 0) {
        throw ServiceException(json['m'] ?? '提交失败');
      }
    });
  }

  /// 查询"我的申请"列表。
  ///
  /// [status] 的真实语义（抓包确认）：
  /// - `0`（默认）：全部（服务端查 status in [0,1,2,4,7]）
  /// - `1`：进行中 + 草稿（status in [0,7]）
  /// - `3`：已完成（status in [4]）
  ///
  /// 注意：历史记录的实际 `status` 值为 2（已完成），`inst_status` 为中文状态
  /// （如"已完成"）。列表项含 `app_name`（事项名）、`created`（提交时间）等字段。
  Future<List<Map<String, dynamic>>> fetchMyApplications({
    int status = 0,
    int page = 1,
  }) async {
    final json = await _request((client) async {
      final uri = Uri.parse('$_base${paths['instList']}').replace(
        queryParameters: {
          'p': '$page',
          'page_size': '20',
          'status': '$status',
          'keyword': '',
          'time_lower': '',
          'time_upper': '',
          'y': '',
          'task_name': '',
        },
      );
      final resp = await client.get(uri, headers: _jsonHeaders);
      return _decodeResponse(resp.body, resp.statusCode);
    });
    if (json['e'] == 0 && json['d'] != null) {
      final d = json['d'];
      if (d is Map && d['list'] is List) {
        return (d['list'] as List).cast<Map<String, dynamic>>();
      }
      if (d is List) return d.cast<Map<String, dynamic>>();
    }
    return const [];
  }
}

/// 上传附件信息（对应 File_71 数组元素）。
///
/// 真实结构：`{"name": "图片1.png", "url": "https://service.scu.edu.cn/site/attach/auth-download?file_id=1774464", "id": 1774464}`
class ServiceAttachment {
  final String name;
  final String url;
  final String id;

  const ServiceAttachment({
    required this.name,
    required this.url,
    required this.id,
  });

  /// 组装成 File_71 提交数组元素。
  Map<String, dynamic> toFormData() => {'name': name, 'url': url, 'id': id};
}

