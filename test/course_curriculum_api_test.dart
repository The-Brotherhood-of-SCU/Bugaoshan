import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/zhjw_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';

void main() {
  late SharedPreferences prefs;
  late AuthLogger logger;

  setUp(() async {
    await getIt.reset();
    logger = AuthLogger();
    getIt.registerSingleton<AuthLogger>(logger);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('fetchCourseCurriculumIndex parses semester/department/category '
      'selects', () async {
    final helper = _buildRoutingApi(
      {
        '/student/teachingResources/courseCurriculum/index': '''
<html><body>
<select name="zxjxjhh" class="select">
  <option value="">全部</option>
  <option value="2026-2027-1-1" selected>2026-2027学年秋</option>
  <option value="2025-2026-2-1">2025-2026学年春</option>
</select>
<select name="kkxsh" class="select">
  <option value="">全部</option>
  <option value="101">艺术学院</option>
  <option value="102">经济学院</option>
</select>
<select name="kclb" class="select">
  <option value="">全部</option>
  <option value="5">国际周课程</option>
  <option value="16">文化素质公选课</option>
</select>
</body></html>
''',
      },
      prefs,
      logger,
    );
    addTearDown(helper.auth.dispose);

    final result = await helper.api.fetchCourseCurriculumIndex();
    expect(result.semesters, hasLength(2));
    expect(result.semesters.first.value, '2026-2027-1-1');
    expect(result.semesters.first.label, '2026-2027学年秋');
    expect(result.departments, hasLength(2));
    expect(result.departments.first.value, '101');
    expect(result.departments.first.name, '艺术学院');
    expect(result.categories, hasLength(2));
    expect(result.categories.first.code, '5');
    expect(result.categories.first.name, '国际周课程');
  });

  test('fetchCourseList parses top-level records and totalCount', () async {
    final helper = _buildRoutingApi(
      {
        '/student/teachingResources/courseCurriculum/search': jsonEncode({
          'pageSize': 30,
          'pageNum': 1,
          'pageContext': {'totalCount': 4},
          'records': [
            {
              'JSH': '20214007',
              'JSM': '王鲲鹏*',
              'KCH': '316001040',
              'KCLBDM': '',
              'KCLBMC': '',
              'KCM': '高等数学1（全英文）',
              'KKXSH': '316',
              'KKXSM': '奥克兰学院',
              'KSLXDM': '01',
              'KSLXMC': '考试',
              'KXH': '01',
              'RN': '1',
              'XF': '4',
              'ZXJXJHH': '2026-2027-1-1',
              'ZXJXJHM': '2026-2027学年秋',
            },
          ],
        }),
      },
      prefs,
      logger,
    );
    addTearDown(helper.auth.dispose);

    final result = await helper.api.fetchCourseList(
      semester: '2026-2027-1-1',
      courseName: '高等数学',
    );
    expect(result.totalCount, 4);
    expect(result.courses, hasLength(1));
    final course = result.courses.single;
    expect(course.planCode, '2026-2027-1-1');
    expect(course.planName, '2026-2027学年秋');
    expect(course.courseCode, '316001040');
    expect(course.courseName, '高等数学1（全英文）');
    expect(course.courseSeq, '01');
    expect(course.credits, '4');
    expect(course.examType, '考试');
    expect(course.department, '奥克兰学院');
    expect(course.teachers, '王鲲鹏*');
  });

  test('fetchCourseList returns empty when records is null', () async {
    final helper = _buildRoutingApi(
      {
        '/student/teachingResources/courseCurriculum/search': jsonEncode({
          'pageSize': 30,
          'pageNum': 1,
          'pageContext': {'totalCount': 0},
          'records': null,
        }),
      },
      prefs,
      logger,
    );
    addTearDown(helper.auth.dispose);

    final result = await helper.api.fetchCourseList();
    expect(result.totalCount, 0);
    expect(result.courses, isEmpty);
  });

  test(
    'fetchCourseSchedule parses callback payload (real response shape)',
    () async {
      // 响应样例来自 2026-09 真实抓包：外层数组包一层的结构与班级课表一致。
      final helper = _buildRoutingApi(
        {
          '/student/teachingResources/courseCurriculum/searchCurriculum/callback':
              jsonEncode([
                [
                  {
                    'id': {
                      'zxjxjhh': '2026-2027-1-1',
                      'jsh': '20092132',
                      'kxh': '01',
                      'kch': '101022020',
                      'skzc': '011111111111000000000000',
                      'skxq': 4,
                      'skjc': 5,
                    },
                    'kcm': '中外经典舞蹈佳作赏析',
                    'jclxdm': '01',
                    'zxjxjhm': '2026-2027学年秋',
                    'zcsm': '2-12周',
                    'cxjc': 3,
                    'xqh': '03',
                    'xqm': '江安',
                    'jxlh': '304',
                    'jxlm': '一教D座',
                    'jash': 'D405',
                    'jasm': 'D405',
                    'kkxsh': '101',
                    'xsh': '101',
                    'jsm': '海维清',
                    'xf': '2',
                    'kkxsm': '艺术学院',
                    'skxq': '4',
                  },
                ],
              ]),
        },
        prefs,
        logger,
      );
      addTearDown(helper.auth.dispose);

      final courses = await helper.api.fetchCourseSchedule(
        planCode: '2026-2027-1-1',
        courseCode: '101022020',
        courseSequenceCode: '01',
      );
      expect(courses, hasLength(1));
      final item = courses.single;
      expect(item.dayOfWeek, 4);
      expect(item.startPeriod, 5);
      expect(item.duration, 3);
      expect(item.courseCode, '101022020');
      expect(item.courseSeq, '01');
      expect(item.courseName, '中外经典舞蹈佳作赏析');
      expect(item.teacherName, '海维清');
      expect(item.weeksDescription, '2-12周');
      expect(item.campus, '江安');
      expect(item.building, '一教D座');
      expect(item.classroom, 'D405');
    },
  );
}

/// 构建按 URL 路径路由响应的 MockClient。
({ZhjwApiService api, ZhjwAuth auth}) _buildRoutingApi(
  Map<String, String> routes,
  SharedPreferences prefs,
  AuthLogger logger,
) {
  var requests = 0;
  final client = CookieClient(
    inner: MockClient((request) async {
      requests++;
      // 第一个请求是 CookieClient 的域隔离探测请求（不在路由内）
      if (requests == 1) return http.Response('ok', 200, request: request);
      final path = request.url.path;
      final body = routes[path];
      if (body == null) {
        return http.Response('route not found: $path', 404, request: request);
      }
      return http.Response.bytes(
        utf8.encode(body),
        200,
        headers: const {'content-type': 'text/html; charset=utf-8'},
        request: request,
      );
    }),
  );
  final scuAuth = _TestScuAuth(prefs, logger: logger, client: client);
  final auth = ZhjwAuth(scuAuth, logger: logger);
  return (api: ZhjwApiService(auth), auth: auth);
}

class _TestScuAuth extends ScuAuth {
  final CookieClient client;

  _TestScuAuth(super.prefs, {required super.logger, required this.client});

  @override
  Future<CookieClient> getClient() async => client;

  @override
  String? get accessToken => 'test-token';
}
