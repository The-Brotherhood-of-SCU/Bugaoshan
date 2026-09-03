import 'dart:convert';

import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/pages/campus/models/classroom_model.dart';
import 'package:bugaoshan/pages/campus/plan_completion/models/plan_completion.dart';
import 'package:bugaoshan/pages/campus/exam_plan/models/exam_info.dart';
import 'package:bugaoshan/pages/campus/train_program/models/train_program.dart';
import 'package:bugaoshan/pages/campus/train_program/models/train_program_model.dart';
import 'package:bugaoshan/services/api/api_request.dart';
import 'package:bugaoshan/services/auth/zhjw_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart' show kZhjwBase;
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/json_utils.dart';

/// 教务系统 API Service（第1层）
///
/// zhjw.scu.edu.cn 的所有业务 API：课表、成绩、教室、培养方案、计划完成度。
/// 通过 [ZhjwAuth] 获取已认证的 CookieClient，内置自动重试。
class ZhjwApiService {
  final ZhjwAuth _auth;
  ZhjwApiService(this._auth);

  /// 多方案详情页请求之间的间隔，避免一次打开页面连续请求
  /// 多个 getPyfaIndex 详情页被教务系统限流（"请勿频繁刷新"）。
  static Duration planDetailRequestGap = const Duration(milliseconds: 600);

  Future<T> _request<T>(Future<T> Function(CookieClient client) fn) {
    return retryOnUnauthenticated(
      _auth.getClient,
      fn,
      invalidate: _auth.invalidate,
    );
  }

  /// 检查会话是否过期。
  ///
  /// zhjw 在 session 过期时返回 302、空 body 或 HTML 登录页。
  /// 检测到时抛 [UnauthenticatedException]，由 [_request] 捕获重试。
  void _checkSessionExpiry(String body, int statusCode) {
    if (statusCode == 302) {
      throw const UnauthenticatedException();
    }
    if (body.trim().isEmpty) {
      throw const UnauthenticatedException();
    }
    if (body.startsWith('<') && body.contains('login')) {
      throw const UnauthenticatedException();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  课表
  // ═══════════════════════════════════════════════════════════════════

  /// 从教务系统首页获取当前教学周数。
  ///
  /// 假期首页没有“第 N 周”字段，而是显示“当前处于假期时间”，此时返回
  /// `null`，由调用方给出明确的假期提示，而不是把正常假期当成系统异常。
  Future<int?> fetchCurrentWeek() {
    return _request((client) async {
      final resp = await client.get(
        Uri.parse('$kZhjwBase/'),
        headers: {
          'Accept': 'text/html,*/*',
          'Referer': '$kZhjwBase/',
          'User-Agent': kDefaultUserAgent,
        },
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      final match = RegExp(r'第(\d+)周').firstMatch(body);
      if (match != null) return int.parse(match.group(1)!);
      if (body.contains('当前处于假期时间')) return null;
      throw const ServiceException('无法获取当前周数，请检查教务系统状态');
    });
  }

  /// 获取历年学期列表
  Future<List<({String value, String label})>> fetchSemesters() {
    return _request((client) async {
      final resp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/courseSelect'
          '/calendarSemesterCurriculum/index',
        ),
        headers: {
          'Accept': 'text/html,*/*',
          'Referer': '$kZhjwBase/',
          'User-Agent': kDefaultUserAgent,
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
        throw const ServiceException('无法获取学期列表，请检查登录状态');
      }
      return semesters;
    });
  }

  /// 获取指定学期课表 JSON，[planCode] 如 '2025-2026-2-1'
  Future<Map<String, dynamic>> fetchJwxtSchedule({required String planCode}) {
    return _request((client) async {
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
          'User-Agent': kDefaultUserAgent,
          'X-Requested-With': 'XMLHttpRequest',
        },
        body: 'planCode=$planCode',
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      return parseJson(body, 'jwxt/schedule', (msg) => ServiceException(msg));
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  //  成绩
  // ═══════════════════════════════════════════════════════════════════

  /// 获取及格成绩
  Future<Map<String, dynamic>> fetchPassingScores() {
    return _request((client) async {
      final indexResp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/integratedQuery/scoreQuery/allPassingScores/index',
        ),
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '$kZhjwBase/',
          'User-Agent': kDefaultUserAgent,
        },
      );
      final indexBody = indexResp.body;
      _checkSessionExpiry(indexBody, indexResp.statusCode);
      final urlMatch = RegExp(
        r'var\s+url\s*=\s*"(/student/integratedQuery/scoreQuery/[^/]+/allPassingScores/callback)"',
      ).firstMatch(indexBody);
      if (urlMatch == null) {
        if (indexBody.contains('login') || indexBody.contains('Login')) {
          throw const UnauthenticatedException();
        }
        throw const ServiceException('无法从页面提取 allPassingScores callback URL');
      }
      final callbackPath = urlMatch.group(1)!;

      final callbackResp = await client.get(
        Uri.parse('$kZhjwBase$callbackPath'),
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Referer':
              '$kZhjwBase/student/integratedQuery/scoreQuery/allPassingScores/index',
          'User-Agent': kDefaultUserAgent,
        },
      );
      final body = callbackResp.body.trim();
      _checkSessionExpiry(body, callbackResp.statusCode);
      return parseJson(
        body,
        'allPassingScores/callback',
        (msg) => ServiceException(msg),
      );
    });
  }

  /// 获取方案成绩
  Future<Map<String, dynamic>> fetchSchemeScores() {
    return _request((client) async {
      final indexResp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/integratedQuery/scoreQuery/schemeScores/index',
        ),
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '$kZhjwBase/',
          'User-Agent': kDefaultUserAgent,
        },
      );
      final indexBody = indexResp.body;
      _checkSessionExpiry(indexBody, indexResp.statusCode);
      final urlMatch = RegExp(
        r'var\s+url\s*=\s*"(/student/integratedQuery/scoreQuery/[^/]+/schemeScores/callback)"',
      ).firstMatch(indexBody);
      if (urlMatch == null) {
        if (indexBody.contains('login') || indexBody.contains('Login')) {
          throw const UnauthenticatedException();
        }
        throw const ServiceException('无法从页面提取 schemeScores callback URL');
      }
      final callbackPath = urlMatch.group(1)!;
      final callbackResp = await client.get(
        Uri.parse('$kZhjwBase$callbackPath'),
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Referer':
              '$kZhjwBase/student/integratedQuery/scoreQuery/schemeScores/index',
          'User-Agent': kDefaultUserAgent,
        },
      );
      final body = callbackResp.body.trim();
      _checkSessionExpiry(body, callbackResp.statusCode);
      return parseJson(
        body,
        'schemeScores/callback',
        (msg) => ServiceException(msg),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  //  教室
  // ═══════════════════════════════════════════════════════════════════

  /// 获取教室查询页面的校区和教学楼列表
  Future<({List<ClassroomCampus> campuses, List<ClassroomBuilding> buildings})>
  fetchClassroomIndex() {
    return _request((client) async {
      final resp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/teachingResources/classroomUseStatus/index',
        ),
        headers: {
          'Accept': 'text/html,*/*',
          'Referer': '$kZhjwBase/',
          'User-Agent': kDefaultUserAgent,
        },
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      final xqMatch = RegExp(
        r"""<input[^>]+id="xqList"[^>]+value='([^']+)'""",
      ).firstMatch(body);
      if (xqMatch == null) {
        throw const ServiceException('无法解析校区列表');
      }
      final xqList = (jsonDecode(xqMatch.group(1)!) as List)
          .map((e) => ClassroomCampus.fromJson(e as Map<String, dynamic>))
          .toList();

      final jxlMatch = RegExp(
        r"""<input[^>]+id="jxlList"[^>]+value='([^']+)'""",
      ).firstMatch(body);
      if (jxlMatch == null) {
        throw const ServiceException('无法解析教学楼列表');
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
  }) {
    return _request((client) async {
      final resp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/teachingResources/classroomUseStatus'
          '/$campusNumber/$buildingNumber'
          '/${Uri.encodeComponent(campusName)}/${Uri.encodeComponent(buildingName)}',
        ),
        headers: {
          'Accept': 'text/html,*/*',
          'Referer': '$kZhjwBase/',
          'User-Agent': kDefaultUserAgent,
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
  }) {
    return _request((client) async {
      final resp = await client.post(
        Uri.parse(
          '$kZhjwBase/student/teachingResources/classroomUseStatus/jasInfo',
        ),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Referer':
              '$kZhjwBase/student/teachingResources/classroomUseStatus/index',
          'User-Agent': kDefaultUserAgent,
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
          (msg) => ServiceException(msg),
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  //  培养方案（从 TrainProgramProvider 迁移 HTTP + 解析逻辑）
  // ═══════════════════════════════════════════════════════════════════

  /// 获取学院列表
  Future<List<College>> fetchColleges() async {
    final body = await _request((client) async {
      final resp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/comprehensiveQuery/search/trainProgram/index',
        ),
        headers: {
          'Accept': 'text/html,*/*',
          'Referer': '$kZhjwBase/',
          'User-Agent': kDefaultUserAgent,
        },
      );
      _checkSessionExpiry(resp.body, resp.statusCode);
      return resp.body;
    });
    return _parseOptions(body, 'xsh');
  }

  /// 获取年级列表
  Future<List<Grade>> fetchGrades() async {
    final body = await _request((client) async {
      final resp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/comprehensiveQuery/search/trainProgram/index',
        ),
        headers: {
          'Accept': 'text/html,*/*',
          'Referer': '$kZhjwBase/',
          'User-Agent': kDefaultUserAgent,
        },
      );
      _checkSessionExpiry(resp.body, resp.statusCode);
      return resp.body;
    });
    return _parseGradeOptions(body, 'nj');
  }

  /// 搜索培养方案
  Future<List<TrainProgram>> searchPrograms({
    required String? college,
    required String? grade,
  }) async {
    return _request((client) async {
      final resp = await client.post(
        Uri.parse(
          '$kZhjwBase/student/comprehensiveQuery/search/trainProgram/load',
        ),
        headers: {
          'Accept': 'application/json, */*',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Referer':
              '$kZhjwBase/student/comprehensiveQuery/search/trainProgram/index',
          'User-Agent': kDefaultUserAgent,
        },
        body:
            'famc=&jhmc=&nj=${grade ?? ''}&xw=&xzlx=&xdlx=00001&xsh=${college ?? ''}&pageNum=1&pageSize=100',
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      final json = jsonDecode(body) as Map<String, dynamic>;
      final records = json['data']['records'] as List<dynamic>? ?? [];
      return records
          .map((e) => TrainProgram.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// 获取培养方案详情
  Future<TrainProgramDetail> fetchProgramDetail(String fajhh) async {
    return _request((client) async {
      final resp = await client.post(
        Uri.parse(
          '$kZhjwBase/student/comprehensiveQuery/search/trainProgram/detail',
        ),
        headers: {
          'Accept': 'application/json, */*',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Referer':
              '$kZhjwBase/student/comprehensiveQuery/search/trainProgram/index',
          'User-Agent': kDefaultUserAgent,
        },
        body: 'fajhh=$fajhh&lx=1',
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      return TrainProgramDetail.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    });
  }

  /// 获取课程详情
  Future<CourseDetail> fetchCourseDetail(String urlPath) async {
    return _request((client) async {
      final resp = await client.get(
        Uri.parse('$kZhjwBase$urlPath'),
        headers: {
          'Accept': 'application/json, */*',
          'Referer':
              '$kZhjwBase/student/comprehensiveQuery/search/trainProgram/index',
          'User-Agent': kDefaultUserAgent,
        },
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      return CourseDetail.fromJson(jsonDecode(body) as Map<String, dynamic>);
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  //  计划完成度（从 PlanCompletionProvider 迁移 HTTP + 解析逻辑）
  // ═══════════════════════════════════════════════════════════════════

  /// 获取计划完成度数据，返回多份培养方案（每份含树节点列表）。
  ///
  /// 教务系统行为：
  /// - 单方案用户：`/planCompletion/index` 直接返回含 zNodes 的数据页；
  /// - 多方案用户（主修+辅修等）：`/index` 是方案选择页，不含数据，
  ///   真正的树数据在 `/getPyfaIndex/<方案ID>` 详情页。
  ///
  /// 解析策略：
  /// 1. 请求 `/index`；若页面含非空 zNodes（有根节点）→ 单方案，直接解析；
  /// 2. 否则从页面提取 `getPyfaIndex/<ID>` 链接逐个请求详情页；
  /// 3. 两者皆无且 zNodes 明确为空数组 → 代表"账号无方案"，返回空列表；
  /// 4. 页面结构异常（无法匹配 zNodes 也无链接）→ 按会话过期处理，
  ///    解析失败（正则不匹配/JSON 损坏）→ 抛 [ServiceException] 可诊断，
  ///    不再静默返回空数组。
  ///
  /// 如果遇到频率限制，抛出 [RateLimitedException]。
  Future<List<PlanCompletionPlan>> fetchPlanCompletion() async {
    return _request((client) async {
      final resp = await client.get(
        Uri.parse('$kZhjwBase/student/integratedQuery/planCompletion/index'),
        headers: {
          'Accept': 'text/html,*/*',
          'Referer': '$kZhjwBase/',
          'User-Agent': kDefaultUserAgent,
        },
      );
      final body = resp.body;

      // 频率限制检测
      if (body.contains('请勿频繁刷新')) {
        throw const RateLimitedException();
      }

      // 1) 尝试直接解析 zNodes（单方案场景）。
      //    仅当正则匹配到 zNodes 时才解析；匹配不上返回 null，不抛错，
      //    以便继续走链接提取分支（多方案选择页可能不含 zNodes）。
      final directNodes = _tryParseZNodes(body);
      if (directNodes != null && directNodes.isNotEmpty) {
        return [
          PlanCompletionPlan(
            id: '',
            name: _extractPlanName(body),
            nodes: directNodes,
          ),
        ];
      }

      // 2) 多方案场景：从入口页提取 getPyfaIndex 链接，逐个请求详情页。
      final planLinks = _extractPlanLinks(body);
      if (planLinks.isNotEmpty) {
        final plans = <PlanCompletionPlan>[];
        for (final link in planLinks) {
          // 教务系统对连续请求有限流（"请勿频繁刷新"），详情页之间
          // 加短暂间隔，避免打开页面时一次触发 N+1 个请求被限流。
          if (plans.isNotEmpty) {
            await Future<void>.delayed(planDetailRequestGap);
          }
          final detailResp = await client.get(
            Uri.parse('$kZhjwBase${link.path}'),
            headers: {
              'Accept': 'text/html,*/*',
              'Referer':
                  '$kZhjwBase/student/integratedQuery/planCompletion/index',
              'User-Agent': kDefaultUserAgent,
            },
          );
          final detailBody = detailResp.body;
          // 详情页可能返回登录页（会话过期）或限流提示
          _checkSessionExpiry(detailBody, detailResp.statusCode);
          if (detailBody.contains('请勿频繁刷新')) {
            throw const RateLimitedException();
          }
          // 详情页必须包含数据；解析失败/结构异常在此抛错，不再静默返回空。
          final nodes = _parseZNodes(detailBody);
          plans.add(
            PlanCompletionPlan(id: link.id, name: link.name, nodes: nodes),
          );
        }
        return plans;
      }

      // 3) 无数据也无链接：zNodes 明确存在但为空数组 → 账号无方案。
      if (directNodes != null) {
        return const [];
      }

      // 4) 页面结构异常（既无 zNodes 也无 getPyfaIndex 链接）：
      //    - 页面是登录页/会话过期页 → 抛 UnauthenticatedException 走重认证；
      //    - 其它无法识别的 HTML（如错误页）→ 抛 ServiceException，
      //      避免触发重认证风暴（每次都会重新 SSO，进一步触发限流）。
      if (body.toLowerCase().contains('login')) {
        throw const UnauthenticatedException();
      }
      throw const ServiceException('方案修读数据格式异常：页面无法解析');
    });
  }

  /// 尝试从 HTML 提取 zNodes 数组。
  ///
  /// 正则未匹配时返回 null（不代表"无方案"，可能是选择页），
  /// 匹配成功但 JSON/字段解析失败时抛 [ServiceException]（可诊断错误）。
  List<PlanCompletionNode>? _tryParseZNodes(String html) {
    final match = RegExp(
      r'var\s+zNodes\s*=\s*(\[.*?\]);',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return null;
    return _decodeZNodes(match.group(1)!);
  }

  /// 解析 zNodes 数组；正则未匹配或解析失败均抛 [ServiceException]。
  List<PlanCompletionNode> _parseZNodes(String html) {
    final match = RegExp(
      r'var\s+zNodes\s*=\s*(\[.*?\]);',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) {
      throw const ServiceException('方案修读数据格式异常：未找到 zNodes 数据');
    }
    return _decodeZNodes(match.group(1)!);
  }

  List<PlanCompletionNode> _decodeZNodes(String jsonStr) {
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((e) => PlanCompletionNode.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServiceException('方案修读数据解析失败：$e');
    }
  }

  /// 提取方案名（单方案场景，来自 index 页 echarts 雷达图 legend）。
  ///
  /// 页面 JS 形如 `legend: { data: ['某某培养方案'], ... }`。
  /// 提取不到时返回空串，由 UI 兜底显示通用名称。
  String _extractPlanName(String html) {
    final match = RegExp(
      r"""data:\s*\[\s*'([^']+)'\s*\]""",
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return '';
    final name = match.group(1)!.trim();
    return name.length > 60 ? name.substring(0, 60) : name;
  }

  /// 从方案选择页提取 `getPyfaIndex/<方案ID>` 入口。
  ///
  /// 教务系统多方案选择页的入口形态（真机抓包确认）：
  /// - 按钮：`<button ... title="方案名(方案ID)" onclick="getPyfaIndex('ID');...">`，
  ///   onclick 中方案 ID 可能带 `&#39;` HTML 实体；
  /// - 链接：`<a href="...getPyfaIndex/123...">方案名</a>`（兜底兼容）。
  ///
  /// 返回去重后的入口列表；方案名取自 title 属性或链接文本，无名称时
  /// 用 `方案<ID>` 兜底，保证多方案用户至少能看到可区分的名称。
  List<_PlanLink> _extractPlanLinks(String html) {
    final links = <_PlanLink>[];
    final seen = <String>{};

    void addPlan(String id, String name) {
      if (!seen.add(id)) return;
      final trimmed = name.trim();
      links.add(
        _PlanLink(
          id: id,
          name: trimmed.isNotEmpty ? trimmed : '方案$id',
          path: '/student/integratedQuery/planCompletion/getPyfaIndex/$id',
        ),
      );
    }

    // 1) 按钮形态：onclick="getPyfaIndex('ID');" + title="方案名(ID)"
    //    真机抓包确认 onclick 里的引号是 &#39; HTML 实体,需显式处理。
    final buttonRe = RegExp(
      r'''onclick=["'][^"']*getPyfaIndex\(\s*(?:&#39;|&quot;|['"])?(\d+)(?:&#39;|&quot;|['"])?\s*\)''',
      dotAll: true,
    );
    for (final m in buttonRe.allMatches(html)) {
      final id = m.group(1)!;
      // 按钮的 title 属性含方案名（如 广播电视编导培养方案(10692)）
      final tagStart = html.lastIndexOf('<button', m.start);
      final tagEnd = html.indexOf('>', m.start);
      if (tagStart >= 0 && tagEnd > tagStart) {
        final tag = html.substring(tagStart, tagEnd);
        final titleMatch = RegExp(
          r'''title=["']([^"']*)["']''',
        ).firstMatch(tag);
        if (titleMatch != null) {
          // title 形如 方案名(10692)，去掉尾部 (ID)
          var name = titleMatch.group(1)!.trim();
          name = name.replaceFirst(RegExp(r'\(\d+\)\s*$'), '').trim();
          addPlan(id, name);
          continue;
        }
      }
      addPlan(id, '方案$id');
    }

    // 2) 链接形态：<a href="...getPyfaIndex/123...">名称</a>
    if (links.isEmpty) {
      final anchorRe = RegExp(
        r"""<a[^>]*href=["'][^"']*getPyfaIndex/(\d+)[^"']*["'][^>]*>(.*?)</a>""",
        dotAll: true,
      );
      for (final m in anchorRe.allMatches(html)) {
        final id = m.group(1)!;
        final rawName = m
            .group(2)!
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll('&nbsp;', ' ')
            .trim();
        addPlan(id, rawName);
      }
    }

    // 3) 兜底：非按钮/链接形态（如 JS 字符串）也提取 ID
    if (links.isEmpty) {
      final bareRe = RegExp(r'getPyfaIndex/(\d+)');
      for (final m in bareRe.allMatches(html)) {
        addPlan(m.group(1)!, '方案${m.group(1)}');
      }
    }
    return links;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  考表
  // ═══════════════════════════════════════════════════════════════════

  /// 获取考试安排列表，通过正则从 HTML 页面解析考试卡片。
  Future<List<ExamInfo>> fetchExamPlan() {
    return _request((client) async {
      final resp = await client.get(
        Uri.parse('$kZhjwBase/student/examinationManagement/examPlan/index'),
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '$kZhjwBase/',
          'User-Agent': kDefaultUserAgent,
        },
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      return _parseExamCards(body);
    });
  }

  /// 用正则从考表 HTML 中提取考试卡片信息。
  List<ExamInfo> _parseExamCards(String html) {
    final cards = <ExamInfo>[];
    final blocks = RegExp(
      r'<div class="widget-box widget-color-\w+(?: collapsed)?">(.*?)'
      r'</div>\s*</div>\s*</div>\s*</div>',
      dotAll: true,
    ).allMatches(html);

    for (final block in blocks) {
      final blockText = block.group(1)!;

      String? firstMatch(RegExp re) {
        final m = re.firstMatch(blockText);
        return m?.group(1)?.trim();
      }

      final courseName =
          (firstMatch(
            RegExp(
              r'<h5 class="widget-title smaller">\s*(.*?)\s*</h5>',
              dotAll: true,
            ),
          )?.replaceAll(RegExp(r'\s*（已结束）'), '').trim()) ??
          '未知';
      final weekNum = firstMatch(RegExp(r'(\d+)周')) ?? '';
      final date = firstMatch(RegExp(r'(\d{4}-\d{2}-\d{2})\s*&nbsp;')) ?? '未知';
      final weekday = firstMatch(RegExp(r'(星期[一二三四五六日])')) ?? '未知';
      final timeRange =
          firstMatch(RegExp(r'&nbsp;(\d{2}:\d{2}-\d{2}:\d{2})')) ?? '未知';
      final locationRaw = firstMatch(RegExp(r'地点:&nbsp;(.+?)</br>')) ?? '未知';
      final location = locationRaw.replaceAll('&nbsp;', ' ');
      final seatNumber = firstMatch(RegExp(r'座位号:&nbsp;(\d+)')) ?? '未知';
      final ticketNumber = firstMatch(RegExp(r'准考证号:&nbsp;(.*?)</br>')) ?? '';
      final tip = firstMatch(RegExp(r'考试提示信息：&nbsp;(.*?)</span>')) ?? '无';

      cards.add(
        ExamInfo(
          courseName: courseName,
          week: weekNum.isNotEmpty ? '第 $weekNum 周' : '未知',
          date: date,
          weekday: weekday,
          timeRange: timeRange,
          location: location,
          seatNumber: seatNumber,
          ticketNumber: ticketNumber,
          tip: tip,
        ),
      );
    }

    return cards;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  班级课表
  // ═══════════════════════════════════════════════════════════════════

  /// 获取班级课表首页的筛选选项
  Future<
    ({
      List<SemesterOption> semesters,
      List<String> grades,
      List<DepartmentOption> departments,
    })
  >
  fetchClassScheduleInquiryIndex() {
    return _request((client) async {
      final resp = await client.get(
        Uri.parse('$kZhjwBase/student/teachingResources/classCurriculum/index'),
        headers: {
          'Accept': 'text/html,*/*',
          'Referer': '$kZhjwBase/',
          'User-Agent': kDefaultUserAgent,
        },
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);

      // 解析学年学期
      final semesterOptions = _parseSelectOptions(
        body,
        'executiveEducationPlanNum',
      );
      final semesters = semesterOptions
          .where((o) => o.value.isNotEmpty)
          .map((o) => SemesterOption(value: o.value, label: o.label))
          .toList();

      // 解析年级
      final gradeOptions = _parseSelectOptions(body, 'yearNum');
      final grades = gradeOptions
          .where((o) => o.value.isNotEmpty)
          .map((o) => o.value)
          .toList();

      // 解析院系
      final deptOptions = _parseSelectOptions(body, 'departmentNum');
      final departments = deptOptions
          .where((o) => o.value.isNotEmpty)
          .map((o) => DepartmentOption(value: o.value, name: o.label))
          .toList();

      return (semesters: semesters, grades: grades, departments: departments);
    });
  }

  /// 根据院系获取专业列表
  Future<List<SubjectOption>> fetchSubjectsByDepartment(String departmentNum) {
    return _request((client) async {
      final resp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/teachingResources/gradeAndClassCurriculum/subjectJson'
          '?departmentNum=${Uri.encodeComponent(departmentNum)}',
        ),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Referer':
              '$kZhjwBase/student/teachingResources/classCurriculum/index',
          'User-Agent': kDefaultUserAgent,
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      final list = jsonDecode(body) as List<dynamic>;
      return list
          .map((e) => SubjectOption.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// 根据年级、院系、专业获取班级列表
  Future<List<ClassOption>> fetchClassOptions({
    required String yearNum,
    required String departmentNum,
    String subjectNum = '',
  }) {
    return _request((client) async {
      final resp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/teachingResources/gradeAndClassCurriculum/classJson'
          '?departmentNum=${Uri.encodeComponent(departmentNum)}'
          '&subjectNum=${Uri.encodeComponent(subjectNum)}'
          '&yearNum=${Uri.encodeComponent(yearNum)}',
        ),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Referer':
              '$kZhjwBase/student/teachingResources/classCurriculum/index',
          'User-Agent': kDefaultUserAgent,
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      final list = jsonDecode(body) as List<dynamic>;
      return list
          .map((e) => ClassOption.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// 搜索班级列表（支持筛选）
  Future<({List<ClassInfo> classes, int totalCount})> fetchClassList({
    int pageNum = 1,
    int pageSize = 30,
    String executiveEducationPlanNum = '',
    String yearNum = '',
    String departmentNum = '',
    String subjectNum = '',
    String classNum = '',
  }) {
    return _request((client) async {
      final resp = await client.post(
        Uri.parse(
          '$kZhjwBase/student/teachingResources/classCurriculum/search',
        ),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Referer':
              '$kZhjwBase/student/teachingResources/classCurriculum/index',
          'User-Agent': kDefaultUserAgent,
          'X-Requested-With': 'XMLHttpRequest',
        },
        body:
            'executiveEducationPlanNum=${Uri.encodeComponent(executiveEducationPlanNum)}'
            '&yearNum=${Uri.encodeComponent(yearNum)}'
            '&departmentNum=${Uri.encodeComponent(departmentNum)}'
            '&subjectNum=${Uri.encodeComponent(subjectNum)}'
            '&classNum=${Uri.encodeComponent(classNum)}'
            '&pageNum=$pageNum&pageSize=$pageSize',
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      final json = jsonDecode(body) as List<dynamic>;
      final first = json.isNotEmpty
          ? json[0] as Map<String, dynamic>
          : <String, dynamic>{};
      final records = (first['records'] as List<dynamic>?) ?? [];
      final totalCount =
          (first['pageContext']?['totalCount'] as num?)?.toInt() ?? 0;
      final classes = records
          .map((e) => ClassInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      return (classes: classes, totalCount: totalCount);
    });
  }

  /// 获取指定班级的课表
  Future<List<ClassScheduleInquiryItem>> fetchClassSchedule({
    required String planCode,
    required String classCode,
  }) {
    return _request((client) async {
      final resp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/teachingResources/classCurriculum/searchCurriculumInfo/callback'
          '?planCode=${Uri.encodeComponent(planCode)}'
          '&classCode=${Uri.encodeComponent(classCode)}',
        ),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Referer':
              '$kZhjwBase/student/teachingResources/classCurriculum/index',
          'User-Agent': kDefaultUserAgent,
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      final json = jsonDecode(body) as List<dynamic>;
      final list = (json.isNotEmpty ? json[0] : []) as List<dynamic>;
      return list
          .map(
            (e) => ClassScheduleInquiryItem.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  //  HTML 解析工具
  // ═══════════════════════════════════════════════════════════════════

  /// 从 HTML 中解析 select 元素的选项列表
  List<({String value, String label})> _parseSelectOptions(
    String html,
    String selectId,
  ) {
    final selectRegex = RegExp(
      '''<select[^>]*name="$selectId"[^>]*>([\\s\\S]*?)</select>''',
    );
    final match = selectRegex.firstMatch(html);
    if (match == null) return [];

    final optionsRegex = RegExp(
      '''<option[^>]*value="([^"]*)"[^>]*>([\\s\\S]*?)</option>''',
    );
    final options = optionsRegex.allMatches(match.group(1)!);
    return options
        .where((m) => m.group(1)!.isNotEmpty)
        .map(
          (m) => (
            value: m.group(1)!,
            label: m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim(),
          ),
        )
        .toList();
  }

  List<College> _parseOptions(String html, String selectId) {
    final selectRegex = RegExp(
      '''<select[^>]*name="$selectId"[^>]*>([\\s\\S]*?)</select>''',
    );
    final match = selectRegex.firstMatch(html);
    if (match == null) return [];

    final optionsRegex = RegExp(
      '''<option[^>]*value="([^"]*)"[^>]*>([\\s\\S]*?)</option>''',
    );
    final options = optionsRegex.allMatches(match.group(1)!);
    return options
        .where((m) => m.group(1)!.isNotEmpty)
        .map(
          (m) => College(
            value: m.group(1)!,
            name: m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim(),
          ),
        )
        .toList();
  }

  List<Grade> _parseGradeOptions(String html, String selectId) {
    final selectRegex = RegExp(
      '''<select[^>]*name="$selectId"[^>]*>([\\s\\S]*?)</select>''',
    );
    final match = selectRegex.firstMatch(html);
    if (match == null) return [];

    final optionsRegex = RegExp(
      '''<option[^>]*value="([^"]*)"[^>]*>([\\s\\S]*?)</option>''',
    );
    final options = optionsRegex.allMatches(match.group(1)!);
    return options
        .where((m) => m.group(1)!.isNotEmpty)
        .map(
          (m) => Grade(
            value: m.group(1)!,
            label: m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim(),
          ),
        )
        .toList();
  }
}

/// 方案选择页中解析出的培养方案入口链接。
class _PlanLink {
  final String id;
  final String name;
  final String path;

  const _PlanLink({required this.id, required this.name, required this.path});
}
