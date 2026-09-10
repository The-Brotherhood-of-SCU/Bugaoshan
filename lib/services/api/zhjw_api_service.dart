import 'dart:convert';

import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/pages/campus/models/classroom_model.dart';
import 'package:bugaoshan/pages/campus/models/course_curriculum_model.dart';
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

part 'zhjw_html_parsers.dart';

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
  /// 登录页用 [looksLikeLoginPage] 的强特征组合判断，不做裸 login 子串
  /// 匹配——正常业务页（如选课页含 loginStatus/clientLogin）不能误伤
  /// （issue #282）。
  void _checkSessionExpiry(String body, int statusCode) {
    if (statusCode == 302) {
      throw const UnauthenticatedException();
    }
    if (body.trim().isEmpty) {
      throw const UnauthenticatedException();
    }
    if (looksLikeLoginPage(body)) {
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
        if (looksLikeLoginPage(indexBody)) {
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
        if (looksLikeLoginPage(indexBody)) {
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

      // 会话过期检测（302 / 空 body / HTML 登录页），与详情页一致：
      // 过期时抛 UnauthenticatedException 交给 retryOnUnauthenticated 重认证，
      // 而不是落入下方分支 4 抛 ServiceException（用户会看到"格式异常"
      // 而非触发重新登录）。
      _checkSessionExpiry(body, resp.statusCode);

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
      if (looksLikeLoginPage(body)) {
        throw const UnauthenticatedException();
      }
      throw const ServiceException('方案修读数据格式异常：页面无法解析');
    });
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
  //  课程课表
  // ═══════════════════════════════════════════════════════════════════

  /// 获取课程课表首页的筛选选项（学年学期 / 开课院系 / 课程类别）
  Future<
    ({
      List<SemesterOption> semesters,
      List<DepartmentOption> departments,
      List<CourseCategoryOption> categories,
    })
  >
  fetchCourseCurriculumIndex() {
    return _request((client) async {
      final resp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/teachingResources/courseCurriculum/index',
        ),
        headers: {
          'Accept': 'text/html,*/*',
          'Referer': '$kZhjwBase/',
          'User-Agent': kDefaultUserAgent,
        },
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);

      final semesterOptions = _parseSelectOptions(body, 'zxjxjhh');
      final semesters = semesterOptions
          .where((o) => o.value.isNotEmpty)
          .map((o) => SemesterOption(value: o.value, label: o.label))
          .toList();

      final deptOptions = _parseSelectOptions(body, 'kkxsh');
      final departments = deptOptions
          .where((o) => o.value.isNotEmpty)
          .map((o) => DepartmentOption(value: o.value, name: o.label))
          .toList();

      final categoryOptions = _parseSelectOptions(body, 'kclb');
      final categories = categoryOptions
          .where((o) => o.value.isNotEmpty)
          .map((o) => CourseCategoryOption(code: o.value, name: o.label))
          .toList();

      return (
        semesters: semesters,
        departments: departments,
        categories: categories,
      );
    });
  }

  /// 搜索课程列表（支持学期 / 院系 / 课程名 / 课程号 / 课序号 / 课程类别筛选）
  Future<({List<CourseSectionInfo> courses, int totalCount})> fetchCourseList({
    int pageNum = 1,
    int pageSize = 30,
    String semester = '',
    String department = '',
    String courseName = '',
    String courseCode = '',
    String courseSeq = '',
    String category = '',
  }) {
    return _request((client) async {
      final resp = await client.post(
        Uri.parse(
          '$kZhjwBase/student/teachingResources/courseCurriculum/search',
        ),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Referer':
              '$kZhjwBase/student/teachingResources/courseCurriculum/index',
          'User-Agent': kDefaultUserAgent,
          'X-Requested-With': 'XMLHttpRequest',
        },
        body:
            'zxjxjhh=${Uri.encodeComponent(semester)}'
            '&kkxsh=${Uri.encodeComponent(department)}'
            '&kcm=${Uri.encodeComponent(courseName)}'
            '&kch=${Uri.encodeComponent(courseCode)}'
            '&kxh=${Uri.encodeComponent(courseSeq)}'
            '&kclb=${Uri.encodeComponent(category)}'
            '&pageNum=$pageNum&pageSize=$pageSize',
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      // 网关异常时可能返回非 JSON 文本（如 502 页面），解析失败抛
      // ServiceException 而不是让 FormatException 裸奔。
      final json = parseJson(
        body,
        'jwxt/courseCurriculum/search',
        (msg) => ServiceException('课程列表数据格式异常：$msg'),
      );
      final records = (json['records'] as List<dynamic>?) ?? [];
      final totalCount =
          (json['pageContext']?['totalCount'] as num?)?.toInt() ?? 0;
      final courses = records
          .map((e) => CourseSectionInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      return (courses: courses, totalCount: totalCount);
    });
  }

  /// 获取指定课程（教学班）的课表，返回结构与班级课表一致
  Future<List<ClassScheduleInquiryItem>> fetchCourseSchedule({
    required String planCode,
    required String courseCode,
    required String courseSequenceCode,
  }) {
    return _request((client) async {
      final resp = await client.get(
        Uri.parse(
          '$kZhjwBase/student/teachingResources/courseCurriculum'
          '/searchCurriculum/callback'
          '?planCode=${Uri.encodeComponent(planCode)}'
          '&courseCode=${Uri.encodeComponent(courseCode)}'
          '&courseSequenceCode=${Uri.encodeComponent(courseSequenceCode)}',
        ),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Referer':
              '$kZhjwBase/student/teachingResources/courseCurriculum/index',
          'User-Agent': kDefaultUserAgent,
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
      final body = resp.body.trim();
      _checkSessionExpiry(body, resp.statusCode);
      // 响应结构为 [[item, item, ...]]：外层数组只有一个元素，内层才是课表项。
      // 解析失败或外层元素不是数组都按格式异常处理，不再裸强转。
      final json = parseJsonList(
        body,
        'jwxt/courseCurriculum/searchCurriculum',
        (msg) => ServiceException('课程课表数据格式异常：$msg'),
      );
      if (json.isEmpty) return const <ClassScheduleInquiryItem>[];
      final list = json.first;
      if (list is! List<dynamic>) {
        throw const ServiceException('课程课表数据格式异常：外层元素不是数组');
      }
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
