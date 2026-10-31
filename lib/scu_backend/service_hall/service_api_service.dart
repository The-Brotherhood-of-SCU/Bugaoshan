import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/scu_backend/core/api_request.dart';
import 'package:bugaoshan/scu_backend/core/api_session.dart';
import 'package:bugaoshan/scu_backend/service_hall/service_form_models.dart';
import 'package:bugaoshan/scu_backend/service_hall/service_plugin_models.dart';
import 'package:bugaoshan/scu_backend/core/cookie_client.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/scu_backend/service_hall/service_auth.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:bugaoshan/utils/constants.dart';

/// 网上办事大厅 API Service（第1层）
///
/// service.scu.edu.cn 的动态表单事项 API。认证通过 [ServiceAuth]
/// （CAS 会话 cookie `vjuid`），请求由 [ApiSession] 统一调度。
class ServiceApiService {
  static const String _tag = 'ServiceApiService';

  final ServiceAuth _auth;
  final AppLogger _log;
  late final ApiSession _session;

  ServiceApiService(this._auth, {ApiSession? session, AppLogger? logger})
    : _log = logger ?? getIt<AppLogger>() {
    _session =
        session ??
        ApiSession(
          getClient: _auth.getClient,
          invalidate: _auth.invalidate,
          baseUrl: Uri.parse(_base),
          logTag: _tag,
          defaultHeaders: const {'Origin': _base, 'Referer': _base},
          sessionExpiryChecker: _checkSessionExpiry,
        );
  }

  static const String _base = 'https://service.scu.edu.cn';

  /// 离校请假事项 id（办事大厅"离校请假"，matter/start?id=350）
  static const String leaveAppId = '350';

  /// 返校报备事项 id。
  static const String returnReportAppId = '337';

  /// 暑假离校事项 id。
  static const String summerLeaveAppId = '356';

  /// 留校登记事项 id。
  static const String stayRegisterAppId = '357';

  /// 默认发起人部门 id（350 抓包值；select-department 接口确认前作为兜底）。
  static const String kDefaultStarterDepartId = '395876';

  /// 接口路径（350 已通过抓包确认；get-formv 来自前端代码分析）。
  static const Map<String, String> paths = {
    'formStartData': '/site/form/start-data',
    'processStartInfo': '/site/process/start-info',
    'processVariables': '/site/process/variables',
    'selectDepartment': '/site/user/select-department',
    'dataSourceDetail': '/site/data-source/detail',
    'attachUpload': '/site/attach/auth-upload',
    'provinceDict': '/api/dictionary/province',
    'formPlugins': '/site/form/get-formv',
    'launch': '/site/apps/launch',
    'instList': '/site/process/inst-list',
  };

  /// DataSource_85（辅导员数据源）的配置 id（来自抓包 curl：id=8）。
  static const String tutorDataSourceId = '8';

  Future<T> _request<T>(Future<T> Function(CookieClient client) fn) {
    return _session.run(fn);
  }

  /// GET 解码 JSON：会话校验与重试由 [ApiSession] 统一处理，
  /// 这里保留站点特有的诊断日志与非 JSON 行为。
  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, dynamic>? query,
    String? apiName,
  }) {
    return _request((client) async {
      final resp = await client.get(
        _session.resolveUri(path, query),
        headers: _jsonHeaders,
      );
      _logResponseDiagnostics(resp);
      _session.checkResponse(resp, apiName: apiName ?? path);
      return _decodeResponse(resp.body, resp.statusCode);
    });
  }

  /// POST 表单并解码 JSON（认证重试由 [ApiSession] 统一处理）。
  Future<Map<String, dynamic>> _postFormJson(
    String path,
    Map<String, String> fields, {
    Map<String, dynamic>? query,
    String? apiName,
  }) {
    return _request((client) async {
      final resp = await client.post(
        _session.resolveUri(path, query),
        headers: _headers,
        body: fields,
      );
      _logResponseDiagnostics(resp);
      _session.checkResponse(resp, apiName: apiName ?? path);
      return _decodeResponse(resp.body, resp.statusCode);
    });
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
      final title = responseTitleForLog(body);
      if (title != null) {
        _log.w(
          _tag,
          '会话响应 HTTP $statusCode title=$title',
          category: LogCategory.business,
        );
      }
      throw const UnauthenticatedException();
    }
  }

  /// 记录非 2xx / HTML 响应的脱敏诊断（只记长度与标题，不记正文）。
  ///
  /// 302/401/403 的诊断由 [ApiSession] 的会话检查负责，避免重复。
  void _logResponseDiagnostics(http.Response resp) {
    final statusCode = resp.statusCode;
    if (statusCode == 302 || statusCode == 401 || statusCode == 403) return;
    final title = responseTitleForLog(resp.body);
    if (statusCode < 200 || statusCode >= 300) {
      AppLog.e(
        _tag,
        'non-2xx: status=$statusCode bodyLength=${resp.body.length}'
        '${title == null ? '' : ' title=$title'}',
      );
    } else if (title != null) {
      AppLog.e(
        _tag,
        '响应非 JSON: status=$statusCode bodyLength=${resp.body.length} title=$title',
      );
    }
  }

  /// 解码业务信封。调用前须已通过 [_logResponseDiagnostics] 与
  /// `_session.checkResponse`（非 2xx 已统一转为 [ServiceException]）。
  Map<String, dynamic> _decodeResponse(String body, int statusCode) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    // e:10042 表示未登录（vjuid cookie 缺失/失效），交给认证层重试
    if (json['e']?.toString() == '10042') {
      throw const UnauthenticatedException('办事大厅会话已失效');
    }
    // 业务错误按 business 分类记录，导出运行日志可查看 e/m
    if (json['e']?.toString() != '0') {
      final msg = '业务错误 e=${json['e']} m=${json['m']} status=$statusCode';
      _log.e(_tag, msg, category: LogCategory.business);
    }
    return json;
  }

  /// 获取事项的表单定义（字段 key、权限、已填数据）。
  Future<ServiceFormDefinition> fetchFormSchema(
    String appId, {
    String starterDepartId = kDefaultStarterDepartId,
  }) async {
    final json = await _getJson(
      paths['formStartData']!,
      query: {
        'app_id': appId,
        'node_id': '',
        'userview': '1',
        'agent_uid': '',
        'starter_depart_id': starterDepartId,
      },
      apiName: 'fetchFormSchema',
    );
    if (json['e'] == 0 && json['d'] != null) {
      return ServiceFormDefinition.fromJson(json['d'] as Map<String, dynamic>);
    }
    throw ServiceException(json['m'] ?? '获取表单定义失败');
  }

  /// 获取请假事项的表单定义（[fetchFormSchema] 的 350 委托，保持原行为）。
  Future<ServiceFormDefinition> fetchLeaveFormSchema() =>
      fetchFormSchema(leaveAppId);

  /// 获取事项的流程信息（`start-info`）。
  ///
  /// 返回原始 `d` 字段：含 `bpmn_id`、`type`、`nodes` 与 `form`（数组，
  /// 每个 form 带 `form_id` / `version_id` / `plugins` JSON 字符串，
  /// 插件描述字段标签、类型、选项、排序、数据源配置）。
  /// 由 [ServiceFormSchema.build] 解析。
  Future<Map<String, dynamic>> fetchStartInfo(String appId) async {
    final json = await _getJson(
      paths['processStartInfo']!,
      query: {'app_id': appId},
      apiName: 'fetchStartInfo',
    );
    if (json['e'] == 0 && json['d'] is Map<String, dynamic>) {
      return json['d'] as Map<String, dynamic>;
    }
    throw ServiceException(json['m'] ?? '获取流程信息失败');
  }

  /// 获取表单插件定义（`get-formv`——插件定义的**主来源**；
  /// start-info 的 form 列表只有 form_id/version_id，不含插件）。
  ///
  /// 前端发起页通过 `GET /site/form/get-formv?id=Y&bpmn_id=X&sess_id=0&report_id=0`
  /// 拉取（被动抓包确认），返回 `d.plugins`（JSON 字符串，
  /// 解码后为 `{nowNum, plugins: {<key>: <plugin>}, rtplugins}`）。
  /// 返回原始 `d` 字段。
  Future<Map<String, dynamic>> fetchFormPlugins({
    required String bpmnId,
    required String formId,
    String starterDepartId = kDefaultStarterDepartId,
  }) async {
    final json = await _getJson(
      paths['formPlugins']!,
      query: {
        'id': formId,
        'bpmn_id': bpmnId,
        'sess_id': '0',
        'report_id': '0',
        'agent_uid': '',
        'starter_depart_id': starterDepartId,
      },
      apiName: 'fetchFormPlugins',
    );
    if (json['e'] == 0 && json['d'] is Map<String, dynamic>) {
      return json['d'] as Map<String, dynamic>;
    }
    throw ServiceException(json['m'] ?? '获取表单插件失败');
  }

  /// 获取当前用户的发起人部门 id（`select-department`）。
  ///
  /// 真实响应（被动抓包确认）：
  /// `d.depart[]` 为候选列表，前端取 `select==1` 项的 **college** 字段
  /// 作为后续所有请求的 starter_depart_id（如 395876）。
  /// 解析不出时返回 null，由调用方回退 [kDefaultStarterDepartId]。
  Future<String?> fetchStarterDepartId(String appId) async {
    final json = await _getJson(
      paths['selectDepartment']!,
      query: {'app_id': appId},
      apiName: 'fetchStarterDepartId',
    );
    if (json['e'] != 0 || json['d'] == null) return null;
    return _extractDepartId(json['d']);
  }

  /// 从 select-department 响应中提取部门 id：
  /// `d.depart` 列表中 select==1 项的 college；兜底首项 college / 各候选键。
  String? _extractDepartId(dynamic d) {
    String? pickCollege(dynamic item) {
      if (item is! Map) return null;
      for (final k in const [
        'college',
        'depart_id',
        'department_id',
        'value',
        'id',
      ]) {
        final v = item[k];
        if (v != null && v.toString().isNotEmpty && v.toString() != '0') {
          return v.toString();
        }
      }
      return null;
    }

    if (d is Map) {
      final depart = d['depart'];
      if (depart is List && depart.isNotEmpty) {
        for (final item in depart) {
          if (item is Map && _toIntSelect(item['select']) == 1) {
            final id = pickCollege(item);
            if (id != null) return id;
          }
        }
        return pickCollege(depart.first);
      }
      final direct = pickCollege(d);
      if (direct != null) return direct;
      final list = d['list'] ?? d['data'];
      if (list is List && list.isNotEmpty) return pickCollege(list.first);
    } else if (d is List && d.isNotEmpty) {
      return pickCollege(d.first);
    }
    return null;
  }

  int _toIntSelect(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? -1;
    return -1;
  }

  /// 获取 DataSource 字段的原始结果（如辅导员）。
  ///
  /// 网页端发起页通过 `POST /site/data-source/detail` 拉取（被动抓包确认：
  /// urlencoded body，参数形态与本实现一致），响应 `d.list`——
  /// 单值数据源（如辅导员 id=8）为字符串；多列数据源（如 337 的
  /// id=11 年级和返校日期）为对象 `{grade: ..., back_date: ...}`，
  /// 由 [ServiceDataSourceRef.mapConfig] 分发。
  ///
  /// 返回原始 `d` 字段（Map）；失败返回 null（由调用方决定是否阻塞提交）。
  Future<Map<String, dynamic>?> fetchDataSourceValue({
    required String appId,
    required ServiceDataSourceRef ref,
    String starterDepartId = kDefaultStarterDepartId,
  }) async {
    final params = <String, String>{
      'id': ref.id,
      'inst_id': '0',
      'app_id': appId,
      'form_version_id': ref.formVersionId,
      'component': ref.component,
      'params[formId]': ref.formId,
      'params[pluginKey]': ref.component,
      'agent_uid': '',
      'starter_depart_id': starterDepartId,
      // 插件 sourceConfig 里的附加参数（前端以 configure[key] 形式发送）
      for (final entry in ref.configure.entries)
        'configure[${entry.key}]': entry.value,
    };
    final json = await _postFormJson(
      paths['dataSourceDetail']!,
      params,
      apiName: 'fetchDataSourceValue',
    );
    if (json['e'] != 0 || json['d'] == null) {
      _log.e(
        _tag,
        'fetchDataSourceValue 失败 e=${json['e']} m=${json['m']}',
        category: LogCategory.business,
      );
      return null;
    }
    final d = json['d'];
    _log.i(
      _tag,
      'fetchDataSourceValue(${ref.component}) -> type=${d.runtimeType}',
      category: LogCategory.business,
    );
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return Map<String, dynamic>.from(d);
    return null;
  }

  /// 获取省市区字典（去往地址 Region_80）。
  ///
  /// 接口：`GET /api/dictionary/province?agent_uid=&starter_depart_id=395876`
  /// 返回 `d` 字段的原始列表（可能为树形或扁平，由调用方按真实结构解析）。
  Future<List<dynamic>> fetchProvinces() async {
    final json = await _getJson(
      paths['provinceDict']!,
      query: {'agent_uid': '', 'starter_depart_id': '395876'},
      apiName: 'fetchProvinces',
    );
    if (json['e'] != 0 || json['d'] == null) {
      _log.e(
        _tag,
        'fetchProvinces 失败 e=${json['e']} m=${json['m']}',
        category: LogCategory.business,
      );
      return const [];
    }
    final d = json['d'];
    if (d is List) return d;
    if (d is Map && d['list'] is List) return d['list'] as List;
    if (d is Map && d['children'] is List) return d['children'] as List;
    _log.e(
      _tag,
      'fetchProvinces 未知结构: ${d.runtimeType}',
      category: LogCategory.business,
    );
    return const [];
  }

  /// 上传附件（File 字段，如 350 的 File_71 上传证明）。
  ///
  /// 接口：`POST /site/attach/auth-upload?category=all&inst_id=0`
  /// FormData 字段名 `upfile`。返回上传后的附件信息，用于组装 File 字段：
  /// `[{"name": 文件名, "url": "…/auth-download?file_id=<id>", "id": <id>}]`
  ///
  /// [file] 本地图片文件。[fileName] 上传后的显示名（默认取文件 basename）。
  /// [appId] 仅用于 Referer 头（模拟对应事项的发起页）。
  Future<ServiceAttachment> uploadAttachment(
    File file, {
    String? fileName,
    String appId = leaveAppId,
  }) async {
    return _request((client) async {
      final uri = Uri.parse(
        '$_base${paths['attachUpload']}?category=all&inst_id=0',
      );
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'Accept': 'application/json, text/plain, */*',
          'Origin': _base,
          'Referer': '$_base/v2/matter/start?id=$appId',
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
      // 仅用于统一的会话/非 2xx 判定，原始响应头不再需要；指定 utf-8
      // 以免 http.Response 构造时按 latin1 编码失败。
      final resp = http.Response(
        body,
        streamed.statusCode,
        headers: const {'content-type': 'text/plain; charset=utf-8'},
      );
      _logResponseDiagnostics(resp);
      _session.checkResponse(resp, apiName: 'uploadAttachment');
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
      } catch (e, logStackTrace) {
        AppLog.e(
          _tag,
          'uploadAttachment 失败',
          error: e,
          stackTrace: logStackTrace,
        );
        _log.e(
          _tag,
          'uploadAttachment 响应非 JSON: length=${body.length}',
          category: LogCategory.business,
        );
        throw ServiceException('上传失败');
      }
      final uploadOk =
          json['url'] != null || json['state']?.toString() == 'SUCCESS';
      if (!uploadOk || json['id'] == null) {
        _log.e(
          _tag,
          'uploadAttachment 失败: state=${json['state']}',
          category: LogCategory.business,
        );
        throw ServiceException('上传失败');
      }
      final id = json['id']?.toString() ?? '';
      final original = (json['original'] ?? '').toString();
      final uploadPath = paths['attachUpload'] ?? '/site/attach/auth-upload';
      final downloadPath = uploadPath.replaceAll(
        'auth-upload',
        'auth-download',
      );
      final attachment = ServiceAttachment(
        name: original.isEmpty ? (fileName ?? 'attachment') : original,
        url: '$_base$downloadPath?file_id=$id',
        id: id,
      );
      _log.i(
        _tag,
        'uploadAttachment -> id=$id',
        category: LogCategory.business,
      );
      return attachment;
    });
  }

  /// 提交事项申请（`POST /site/apps/launch`）。
  ///
  /// [appId] 事项 id（350/337/356/357…）。
  /// [formData] 是 `form_data` 的完整字段 Map（key 为表单 id，如 "1419"）。
  /// [starterDepartId] 发起人部门 id（默认 [kDefaultStarterDepartId]）。
  Future<void> submitMatter(
    String appId,
    Map<String, dynamic> formData, {
    String starterDepartId = kDefaultStarterDepartId,
  }) async {
    final data = {
      'app_id': appId,
      'node_id': '',
      'form_data': formData,
      'userview': 1,
    };
    final json = await _postFormJson(paths['launch']!, {
      'data': jsonEncode(data),
      'step': '0',
      'agent_uid': '',
      'starter_depart_id': starterDepartId,
    }, apiName: 'submitMatter');
    if (json['e'] != 0) {
      throw ServiceException(json['m'] ?? '提交失败');
    }
  }

  /// 提交请假申请（[submitMatter] 的 350 委托，保持原行为）。
  Future<void> submitLeave(
    Map<String, dynamic> formData, {
    String starterDepartId = kDefaultStarterDepartId,
  }) => submitMatter(leaveAppId, formData, starterDepartId: starterDepartId);

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
    final json = await _getJson(
      paths['instList']!,
      query: {
        'p': '$page',
        'page_size': '20',
        'status': '$status',
        'keyword': '',
        'time_lower': '',
        'time_upper': '',
        'y': '',
        'task_name': '',
      },
      apiName: 'fetchMyApplications',
    );
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
