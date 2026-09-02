import 'dart:convert';
import 'dart:io';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/repair.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/zhhq_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/zhhq_crypto.dart';
import 'package:http/http.dart' as http;

/// 智慧后勤（zhhq）在线报修 API Service（第1层）
///
/// service 位于 `zhhq.scu.edu.cn/api`。认证通过 [ZhhqAuth] 的 tokenKey：
/// 每次请求生成全新 `Token`（AES 加密 `{tokenKey, clientId, timestamp, GUID}`）
/// 与 `TokenKey` 请求头；响应体为 AES-CBC 加密，需解密后解析。
///
/// # 真实接口（已通过抓包 + 前端 JS 逆向确认）
///
/// - 常用地址：`POST /repair/oneNetPublish/getCommonAddress`
/// - 区域树：  `POST /repair/publish/getAreaTree`
/// - 维修项目：`POST /repair/publish/getProjectByAreaId`
/// - 预约日期：`POST /repair/publish/getBookDate`
/// - 预约时段：`POST /repair/publish/getBookTime`
/// - 我的报修：`POST /repair/oneNetPublish/myList`
/// - 提交报修：`POST /repair/publish/publish`（JSON）
/// - 图片上传：`POST /api/file/upload`（multipart，响应为明文 JSON）
///
/// # 响应约定
///
/// 成功 `status == "success"`，业务数据在 `data`；错误在 `errorCode`/`message`
/// （4010/4013/4017 为 token 类错误，交给认证层重建会话）。
class ZhhqApiService {
  final ZhhqAuth _auth;
  final AuthLogger _log;
  ZhhqApiService(this._auth) : _log = getIt<AuthLogger>();

  static const String _base = 'https://zhhq.scu.edu.cn/api';

  /// 生成当前请求的 Token（每次全新）。
  String _buildToken(String tokenKey) {
    final payload = {
      'tokenKey': tokenKey,
      'clientId': ZhhqCrypto.clientId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'GUID': _guid(),
    };
    return ZhhqCrypto.encrypt(
      jsonEncode(payload),
      key: ZhhqCrypto.clientSecret,
      iv: ZhhqCrypto.clientId,
    );
  }

  static String _guid() {
    const pattern = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
    final r = StringBuffer();
    for (final c in pattern.split('')) {
      if (c == 'x' || c == 'y') {
        final n =
            (DateTime.now().microsecondsSinceEpoch + _rand()).toUnsigned(32) &
            0xF;
        r.write(c == 'x' ? n.toRadixString(16) : (3 & n | 8).toRadixString(16));
      } else {
        r.write(c);
      }
    }
    return r.toString();
  }

  static int _randSeed = DateTime.now().microsecondsSinceEpoch;
  static int _rand() {
    _randSeed = (_randSeed * 1103515245 + 12345) & 0x7fffffff;
    return _randSeed;
  }

  Future<T> _request<T>(
    Future<T> Function(CookieClient client, String tokenKey) fn,
  ) async {
    // 快速路径：tokenKey 已持久化/缓存时，跳过 SCU 会话（冷启动 SCU 过期
    // 也无需等 5-8s refresh），直接用独立 CookieClient 发请求。
    // 业务请求只依赖 Token/TokenKey 头，不依赖 SCU cookie。
    final fastClient = _auth.getClientFast();
    final fastTokenKey = _auth.tokenKey;
    if (fastClient != null && fastTokenKey != null) {
      try {
        return await fn(fastClient, fastTokenKey);
      } on UnauthenticatedException {
        // tokenKey 失效（4010-4017）：走完整认证重建
        _log.w('ZHhq', 'fast path token invalid, re-authenticating');
      }
    }
    // 完整路径：确保 SCU 会话 + zhhq tokenKey（必要时走 SSO）
    try {
      final client = await _auth.getClient();
      final tokenKey = _auth.tokenKey;
      if (tokenKey == null) throw const UnauthenticatedException();
      return await fn(client, tokenKey);
    } on UnauthenticatedException {
      _auth.invalidate();
      final client = await _auth.getClient();
      final tokenKey = _auth.tokenKey;
      if (tokenKey == null) throw const UnauthenticatedException();
      return await fn(client, tokenKey);
    }
  }

  Map<String, String> _headers(
    CookieClient client,
    String tokenKey, {
    bool json = false,
  }) {
    return {
      'Accept': 'application/json, text/plain, */*',
      'Content-Type': json
          ? 'application/json;charset=utf-8'
          : 'application/x-www-form-urlencoded; charset=UTF-8',
      'Origin': 'https://zhhq.scu.edu.cn',
      'Referer': 'https://zhhq.scu.edu.cn/ihome/newrepair',
      'User-Agent': kDefaultUserAgent,
      'X-Requested-With': 'XMLHttpRequest',
      'Token': _buildToken(tokenKey),
      'TokenKey': tokenKey,
    };
  }

  Map<String, dynamic> _decode(String body, int statusCode) {
    if (statusCode == 302 ||
        statusCode == 401 ||
        statusCode == 403 ||
        body.trim().isEmpty) {
      throw const UnauthenticatedException();
    }
    final json = zhhqDecodeResponse(body);
    if (json == null) {
      // 诊断：解密失败时记录响应片段，便于定位（可能为明文错误页 / 非标准加密）
      _log.w(
        'ZHhq',
        '响应解析失败，status=$statusCode body=${body.length > 100 ? body.substring(0, 100) : body}',
      );
      throw ServiceException('zhhq 响应解析失败');
    }
    final code = json['errorCode']?.toString() ?? '';
    final status = json['status']?.toString() ?? '';
    // 4010-4017 均为 token 类错误（无效/超时/签名错误），触发重新认证
    final codeInt = int.tryParse(code);
    if (codeInt != null && codeInt >= 4010 && codeInt <= 4017) {
      _log.w('ZHhq', 'token 错误 errorCode=$code: ${json['message']}');
      throw const UnauthenticatedException('zhhq 会话已失效');
    }
    if (status != 'success' && json['errorCode'] != null) {
      final message = json['message']?.toString() ?? '操作失败';
      _log.w('ZHhq', '业务错误 errorCode=$code: $message');
      throw ServiceException(message);
    }
    return json;
  }

  /// 获取常用地址列表。
  Future<List<RepairAddress>> fetchAddresses() async {
    final json = await _request((client, tokenKey) async {
      final resp = await client.post(
        Uri.parse('$_base/repair/oneNetPublish/getCommonAddress'),
        headers: _headers(client, tokenKey),
      );
      return _decode(resp.body, resp.statusCode);
    });
    final data = json['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => RepairAddress.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// 获取区域树（用于地址选择）。
  Future<List<RepairAreaNode>> fetchAreaTreeNodes() async {
    final json = await _request((client, tokenKey) async {
      final resp = await client.post(
        Uri.parse('$_base/repair/publish/getAreaTree'),
        headers: _headers(client, tokenKey),
      );
      return _decode(resp.body, resp.statusCode);
    });
    final data = json['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => RepairAreaNode.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// 按区域获取维修项目。
  Future<List<RepairProject>> fetchProjects(String areaId) async {
    final json = await _request((client, tokenKey) async {
      final resp = await client.post(
        Uri.parse('$_base/repair/publish/getProjectByAreaId'),
        headers: _headers(client, tokenKey),
        body: {'areaId': areaId},
      );
      return _decode(resp.body, resp.statusCode);
    });
    final data = json['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => RepairProject.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// 获取可预约日期（未来数天）。
  Future<List<String>> fetchBookDates() async {
    final json = await _request((client, tokenKey) async {
      final resp = await client.post(
        Uri.parse('$_base/repair/publish/getBookDate'),
        headers: _headers(client, tokenKey),
      );
      return _decode(resp.body, resp.statusCode);
    });
    final data = json['data'];
    if (data is! List) return const [];
    return data.map((e) => e.toString()).toList(growable: false);
  }

  /// 获取某日期的可预约时段。
  Future<List<String>> fetchBookTimes(String bookDate) async {
    final json = await _request((client, tokenKey) async {
      final resp = await client.post(
        Uri.parse('$_base/repair/publish/getBookTime'),
        headers: _headers(client, tokenKey),
        body: {'bookDate': bookDate},
      );
      return _decode(resp.body, resp.statusCode);
    });
    final data = json['data'];
    if (data is! List) return const [];
    return data.map((e) => e.toString()).toList(growable: false);
  }

  /// 获取「我的动态」报修工单列表（推荐）。
  ///
  /// 使用 `manager/activeTemplateData/list`（首页「我的动态」同源接口）：
  /// - **快**：~600ms（`oneNetPublish/myList` 需 20s+）
  /// - 返回的 `status` 直接是中文文案（已关闭/待完工/待评价/已撤回）
  /// - `content` 为 JSON 字符串（维修项目/故障地点/故障描述）
  ///
  /// [userId] 为当前用户的 `createUser`（用于筛选本人工单），
  /// 可从常用地址（[RepairAddress.userId]）获取。
  Future<List<RepairTicket>> fetchDynamicTickets({
    required String userId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final json = await _request((client, tokenKey) async {
      final search = jsonEncode([
        {
          'andOr': 'and',
          'searchField': 'createUser',
          'operator': '=',
          'value': userId,
        },
      ]);
      final resp = await client.post(
        Uri.parse('$_base/manager/activeTemplateData/list'),
        headers: _headers(client, tokenKey),
        body: {
          'pageIndex': '$page',
          'pageSize': '$pageSize',
          'systemCode': 'newRepair',
          'search': search,
        },
      );
      return _decode(resp.body, resp.statusCode);
    });
    final data = json['data'];
    if (data is! List) return const [];
    final tickets = data
        .whereType<Map>()
        .map((e) => RepairTicket.fromDynamicJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    // 接口返回顺序无序（非时间序），按 activeTime 倒序（最新在前），
    // 与页面「我的动态」展示一致。activeTime 为 `YYYY-MM-DD HH:mm:ss` 字符串，
    // 字典序即时间序；缺失时回退 createTime 时间戳。
    tickets.sort((a, b) {
      final ta = a.activeTime;
      final tb = b.activeTime;
      if (ta.isNotEmpty && tb.isNotEmpty && ta != tb) {
        return tb.compareTo(ta);
      }
      return b.createTime.compareTo(a.createTime);
    });
    return tickets;
  }

  /// 保存（新增）常用报修地址。
  ///
  /// 对应前端 `userCommonAddress/save`（JSON body）。
  /// [areaName] 为级联选择得出的区域名称（如 `望江学生区/东苑五栋`）。
  Future<void> saveAddress({
    required String areaId,
    required String areaName,
    required String addressDetail,
    required String phone,
    String userName = '',
    bool isCommon = false,
  }) async {
    final json = await _request((client, tokenKey) async {
      final resp = await client.post(
        Uri.parse('$_base/repair/userCommonAddress/save'),
        headers: _headers(client, tokenKey, json: true),
        body: jsonEncode({
          'areaId': areaId,
          'areaName': areaName,
          'addressDetail': addressDetail,
          'phone': phone,
          'userName': userName,
          'ifCommon': isCommon ? '1' : '0',
          'id': '',
        }),
      );
      return _decode(resp.body, resp.statusCode);
    });
    final code = json['errorCode']?.toString();
    if (code != null && code != '0') {
      throw ServiceException(json['message']?.toString() ?? '保存地址失败');
    }
  }

  /// 提交报修工单。
  Future<void> submitTicket(Map<String, dynamic> payload) async {
    final json = await _request((client, tokenKey) async {
      final resp = await client.post(
        Uri.parse('$_base/repair/publish/publish'),
        headers: _headers(client, tokenKey, json: true),
        body: jsonEncode(payload),
      );
      return _decode(resp.body, resp.statusCode);
    });
    final code = json['errorCode']?.toString();
    if (code != null && code != '0') {
      throw ServiceException(json['message']?.toString() ?? '提交报修失败');
    }
  }

  /// 提交前预取：按区域+维修项目获取负责部门与收费信息。
  ///
  /// 对应前端提交链的第一步 `getAcceptUserByAreaIdAndProjectId`。返回的
  /// `dept`（或第一个 `user`）含 `deptId`/`deptName`/`payName`，是
  /// `publish` 请求体里 `acceptDeptId`/`acceptDeptName`/`payName` 的来源；
  /// 失败时返回 null（提交链的 `checkIfHadProjectIdByAreaId` 为可选校验，
  /// 服务端以 `publish` 缺参为由拒单时再暴露给用户）。
  Future<RepairAcceptDept?> fetchAcceptDept({
    required String areaId,
    required String projectId,
  }) async {
    final json = await _request((client, tokenKey) async {
      final resp = await client.post(
        Uri.parse('$_base/repair/publish/getAcceptUserByAreaIdAndProjectId'),
        headers: _headers(client, tokenKey),
        body: {'areaId': areaId, 'projectId': projectId},
      );
      return _decode(resp.body, resp.statusCode);
    });
    final data = json['data'];
    if (data is! Map) return null;
    final dept = data['dept'];
    if (dept is Map) {
      return RepairAcceptDept.fromJson(Map<String, dynamic>.from(dept));
    }
    final users = data['users'];
    if (users is List && users.isNotEmpty && users.first is Map) {
      return RepairAcceptDept.fromJson(
        Map<String, dynamic>.from(users.first as Map),
      );
    }
    return null;
  }

  /// 上传报修图片，返回服务端 `path`（用于提交工单的 `resourcesVOS.fileUrl`）。
  ///
  /// 对应前端 `POST /api/file/upload`（multipart：`file` + `system=manager`）。
  /// 注意：本接口响应是**明文 JSON**（拦截器对 `/api/file/upload` 跳过 AES 解密），
  /// 不走 `_request`/`_decode`，直接解析。
  Future<String> uploadImage({required File file}) async {
    // 快速路径优先：tokenKey 有效时无需等待 SCU 会话（与 _request 模板一致）。
    // 失效时 invalidate + 完整认证后重试一次（multipart 上传幂等，可安全重放）。
    var client = _auth.getClientFast();
    var tokenKey = _auth.tokenKey;
    if (client == null || tokenKey == null) {
      client = await _auth.getClient();
      tokenKey = _auth.tokenKey;
    }
    try {
      if (tokenKey == null) throw const UnauthenticatedException();
      return await _uploadImageWith(client, tokenKey, file);
    } on UnauthenticatedException {
      _auth.invalidate();
      client = await _auth.getClient();
      tokenKey = _auth.tokenKey;
      if (tokenKey == null) throw const UnauthenticatedException();
      return await _uploadImageWith(client, tokenKey, file);
    }
  }

  Future<String> _uploadImageWith(
    CookieClient client,
    String tokenKey,
    File file,
  ) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_base/file/upload'))
          ..headers.addAll(_headers(client, tokenKey))
          ..fields['system'] = 'manager'
          ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await client.send(request);
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 302 ||
        resp.statusCode == 401 ||
        resp.statusCode == 403) {
      throw const UnauthenticatedException();
    }
    // 明文 JSON（非 AES 加密）
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw ServiceException('图片上传失败：响应解析异常');
    }
    if (json['errorCode']?.toString() != '0' &&
        json['status']?.toString() != 'success') {
      throw ServiceException(json['message']?.toString() ?? '图片上传失败');
    }
    final data = json['data'];
    if (data is! Map) throw const ServiceException('图片上传失败：响应异常');
    final path = data['path']?.toString() ?? '';
    if (path.isEmpty) throw const ServiceException('图片上传失败：未返回路径');
    return path;
  }
}
