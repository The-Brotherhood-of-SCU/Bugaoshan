import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/api/service_api_service.dart';
import 'package:bugaoshan/services/api/service_plugin_models.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/service_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';

/// 可切换 CookieClient 的假 ScuAuth（与 wfw_auth_test 同模式）。
class _FakeScuAuth extends ScuAuth {
  _FakeScuAuth(super.prefs, {required super.logger});

  @override
  Future<CookieClient> getClient() async => CookieClient();
}

/// 假 ServiceAuth：getClient 依次返回预置的 CookieClient，
/// invalidate 计数（验证 retryOnUnauthenticated 只重试一次）。
class _FakeServiceAuth extends ServiceAuth {
  _FakeServiceAuth(ScuAuth scuAuth, this._clients) : super(scuAuth);

  final List<CookieClient> _clients;
  int getClientCalls = 0;
  int invalidations = 0;

  @override
  Future<CookieClient> getClient() async {
    final i = getClientCalls < _clients.length
        ? getClientCalls
        : _clients.length - 1;
    getClientCalls++;
    return _clients[i];
  }

  @override
  void invalidate() {
    invalidations++;
  }
}

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

  (_FakeServiceAuth, ServiceApiService) makeService(
    List<CookieClient> clients,
  ) {
    final scuAuth = _FakeScuAuth(prefs, logger: logger);
    final auth = _FakeServiceAuth(scuAuth, clients);
    return (auth, ServiceApiService(auth));
  }

  http.Response jsonResponse(Map<String, dynamic> body, http.Request req) {
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: req,
    );
  }

  group('fetchFormSchema', () {
    test('appId 参数化：请求带对应 app_id 并解析 auth/data', () async {
      final requests = <http.Request>[];
      final client = CookieClient(
        inner: MockClient((request) async {
          requests.add(request);
          return jsonResponse({
            'e': 0,
            'm': '操作成功',
            'd': {
              'currform': [1500],
              'auth': {
                '1500': {'Radio_1': 'require'},
              },
              'data': {
                '1500': {'User_1': '张三'},
              },
            },
          }, request);
        }),
      );
      final (_, service) = makeService([client]);
      final def = await service.fetchFormSchema('337');

      expect(requests.single.url.queryParameters['app_id'], '337');
      expect(def.currform, [1500]);
      expect(def.auth, {'Radio_1': 'require'});
      expect(def.data, {'User_1': '张三'});
    });

    test('e:10042 视为未登录，invalidate 后重试一次', () async {
      final expired = CookieClient(
        inner: MockClient(
          (request) async => jsonResponse({'e': 10042, 'm': '未登录'}, request),
        ),
      );
      final ok = CookieClient(
        inner: MockClient(
          (request) async => jsonResponse({
            'e': 0,
            'd': {
              'currform': [1419],
              'auth': {'1419': <String, String>{}},
              'data': {'1419': <String, String>{}},
            },
          }, request),
        ),
      );
      final (auth, service) = makeService([expired, ok]);

      final def = await service.fetchFormSchema('350');
      expect(def.currform, [1419]);
      expect(auth.getClientCalls, 2);
      expect(auth.invalidations, 1);
    });

    test('e!=0 业务错误抛 ServiceException', () async {
      final client = CookieClient(
        inner: MockClient(
          (request) async => jsonResponse({'e': 1, 'm': '事项已下架'}, request),
        ),
      );
      final (_, service) = makeService([client]);
      await expectLater(
        service.fetchFormSchema('350'),
        throwsA(isA<ServiceException>()),
      );
    });
  });

  group('fetchStartInfo / fetchFormPlugins', () {
    test('fetchStartInfo 返回原始 d 字段', () async {
      final requests = <http.Request>[];
      final client = CookieClient(
        inner: MockClient((request) async {
          requests.add(request);
          return jsonResponse({
            'e': 0,
            'd': {
              'bpmn_id': '123',
              'form': [
                {'form_id': 1419, 'version_id': 2357, 'plugins': '{}'},
              ],
            },
          }, request);
        }),
      );
      final (_, service) = makeService([client]);
      final d = await service.fetchStartInfo('356');
      expect(requests.single.url.queryParameters['app_id'], '356');
      expect(d['bpmn_id'], '123');
      expect((d['form'] as List).single['form_id'], 1419);
    });

    test('fetchFormPlugins 带 bpmn_id 与 form id（参数与前端一致）', () async {
      final requests = <http.Request>[];
      final client = CookieClient(
        inner: MockClient((request) async {
          requests.add(request);
          return jsonResponse({
            'e': 0,
            'd': {'plugins': '{"plugins":[]}'},
          }, request);
        }),
      );
      final (_, service) = makeService([client]);
      final d = await service.fetchFormPlugins(
        bpmnId: '3577',
        formId: '1419',
        starterDepartId: '395876',
      );
      final qp = requests.single.url.queryParameters;
      // 被动抓包确认的前端参数形态：
      // get-formv?id=1419&bpmn_id=3577&sess_id=0&report_id=0&agent_uid=&starter_depart_id=395876
      expect(qp['id'], '1419');
      expect(qp['bpmn_id'], '3577');
      expect(qp['sess_id'], '0');
      expect(qp['report_id'], '0');
      expect(qp['agent_uid'], '');
      expect(qp['starter_depart_id'], '395876');
      expect(d['plugins'], '{"plugins":[]}');
    });
  });

  group('fetchDataSourceValue', () {
    test('按插件配置组装请求体并返回原始 d（含多列 list 对象）', () async {
      String? body;
      final client = CookieClient(
        inner: MockClient((request) async {
          body = request.body;
          return jsonResponse({
            'e': 0,
            'm': '操作成功',
            'd': {'list': '张美成'},
          }, request);
        }),
      );
      final (_, service) = makeService([client]);
      final d = await service.fetchDataSourceValue(
        appId: '350',
        ref: const ServiceDataSourceRef(
          id: '8',
          formVersionId: '2357',
          component: 'DataSource_85',
          formId: '1419',
          configure: {'college': 'auto'},
        ),
      );
      // 单值数据源：d.list 为字符串（真实响应形态）
      expect(d, {'list': '张美成'});
      final params = Uri.splitQueryString(body!);
      expect(params['id'], '8');
      expect(params['app_id'], '350');
      expect(params['form_version_id'], '2357');
      expect(params['component'], 'DataSource_85');
      expect(params['params[formId]'], '1419');
      expect(params['params[pluginKey]'], 'DataSource_85');
      expect(params['configure[college]'], 'auto');
    });

    test('多列数据源的 list 对象原样带出（337 年级和返校日期）', () async {
      final client = CookieClient(
        inner: MockClient((request) async {
          return jsonResponse({
            'e': 0,
            'm': '操作成功',
            'd': {
              'list': {'grade': '2023', 'back_date': ''},
            },
          }, request);
        }),
      );
      final (_, service) = makeService([client]);
      final d = await service.fetchDataSourceValue(
        appId: '337',
        ref: const ServiceDataSourceRef(
          id: '11',
          formVersionId: '2282',
          component: 'DataSource_163',
          formId: '1396',
          resultKey: 'setplugin',
          mapConfig: {'User_156': 'grade', 'Input_162': 'back_date'},
        ),
      );
      expect(d?['list'], {'grade': '2023', 'back_date': ''});
    });

    test('fetchTutor 委托保持 350 抓包参数', () async {
      String? body;
      final client = CookieClient(
        inner: MockClient((request) async {
          body = request.body;
          return jsonResponse({
            'e': 0,
            'd': {'list': '张美成'},
          }, request);
        }),
      );
      final (_, service) = makeService([client]);
      final name = await service.fetchTutor();
      expect(name, '张美成');
      final params = Uri.splitQueryString(body!);
      expect(params['id'], '8');
      expect(params['app_id'], '350');
      expect(params['form_version_id'], '2357');
      expect(params['component'], 'DataSource_85');
      expect(params['params[formId]'], '1419');
      // 无 configure 参数（与原实现逐字节一致）
      expect(params.keys.where((k) => k.startsWith('configure[')), isEmpty);
    });

    test('业务失败返回 null 而不抛异常', () async {
      final client = CookieClient(
        inner: MockClient(
          (request) async => jsonResponse({'e': 1, 'm': '无数据源'}, request),
        ),
      );
      final (_, service) = makeService([client]);
      expect(await service.fetchTutor(), isNull);
    });
  });

  group('submitMatter', () {
    test('data JSON 含参数化的 app_id 与 form_data', () async {
      String? body;
      final client = CookieClient(
        inner: MockClient((request) async {
          body = request.body;
          return jsonResponse({'e': 0, 'm': '操作成功', 'd': {}}, request);
        }),
      );
      final (_, service) = makeService([client]);
      await service.submitMatter('357', {
        '1500': {
          'Radio_1': {'value': '1', 'name': '选项'},
        },
      });
      final params = Uri.splitQueryString(body!);
      expect(params['step'], '0');
      expect(params['starter_depart_id'], '395876');
      final data = jsonDecode(params['data']!) as Map<String, dynamic>;
      expect(data['app_id'], '357');
      expect(data['node_id'], '');
      expect(data['userview'], 1);
      expect(data['form_data'], {
        '1500': {
          'Radio_1': {'value': '1', 'name': '选项'},
        },
      });
    });

    test('submitLeave 委托 app_id=350', () async {
      String? body;
      final client = CookieClient(
        inner: MockClient((request) async {
          body = request.body;
          return jsonResponse({'e': 0, 'd': {}}, request);
        }),
      );
      final (_, service) = makeService([client]);
      await service.submitLeave({'1419': {}});
      final data = jsonDecode(Uri.splitQueryString(body!)['data']!) as Map;
      expect(data['app_id'], '350');
    });

    test('e!=0 抛 ServiceException 且不重试', () async {
      final client = CookieClient(
        inner: MockClient(
          (request) async => jsonResponse({'e': 10043, 'm': '校验失败'}, request),
        ),
      );
      final (auth, service) = makeService([client]);
      await expectLater(
        service.submitMatter('350', {'1419': {}}),
        throwsA(isA<ServiceException>()),
      );
      expect(auth.getClientCalls, 1);
      expect(auth.invalidations, 0);
    });
  });

  group('uploadAttachment', () {
    test('解析双 JSON 包裹响应并组装下载链接', () async {
      http.MultipartRequest? captured;
      final client = CookieClient(
        inner: MockClient.streaming((request, body) async {
          if (request is http.MultipartRequest) captured = request;
          final resp = http.StreamedResponse(
            Stream.value(
              utf8.encode(
                // 真实接口可能返回 "JSON 字符串包裹的 JSON"
                jsonEncode(
                  jsonEncode({
                    'url': '/upload/1.png',
                    'original': '图片1.png',
                    'state': 'SUCCESS',
                    'id': 1774464,
                  }),
                ),
              ),
            ),
            200,
          );
          return resp;
        }),
      );
      final (_, service) = makeService([client]);
      // 写一个临时图片文件
      final tmp = File(
        '${Directory.systemTemp.path}/service_api_test_upload.png',
      );
      await tmp.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete();
      });

      final attachment = await service.uploadAttachment(tmp, appId: '337');
      expect(attachment.id, '1774464');
      expect(attachment.name, '图片1.png');
      expect(
        attachment.url,
        'https://service.scu.edu.cn/site/attach/auth-download?file_id=1774464',
      );
      expect(captured, isNotNull);
      // Referer 带参数化 appId
      expect(captured!.headers['Referer'], contains('id=337'));
    });
  });

  group('fetchStarterDepartId', () {
    test('真实响应形态：depart 列表中 select==1 项的 college', () async {
      // 对照 test/fixtures/service_capture.json 的 select-department app=350
      final client = CookieClient(
        inner: MockClient(
          (request) async => jsonResponse({
            'e': 0,
            'm': '操作成功',
            'd': {
              'depart': [
                {
                  'id': 174694623,
                  'uid': 432883,
                  'number': '2023141460081',
                  'college': 395876,
                  'identity': 'student',
                  'select': 1,
                  'college_name': '计算机学院（软件学院）',
                },
              ],
              'tip': 0,
            },
          }, request),
        ),
      );
      final (_, service) = makeService([client]);
      // 前端实际使用 college（395876），而非关系 id（174694623）
      expect(await service.fetchStarterDepartId('350'), '395876');
    });

    test('从多种响应结构提取部门 id', () async {
      final client = CookieClient(
        inner: MockClient(
          (request) async => jsonResponse({
            'e': 0,
            'd': {
              'list': [
                {'id': '395876', 'name': '计算机学院'},
              ],
            },
          }, request),
        ),
      );
      final (_, service) = makeService([client]);
      expect(await service.fetchStarterDepartId('350'), '395876');
    });

    test('解析不出时返回 null（调用方回退默认值）', () async {
      final client = CookieClient(
        inner: MockClient(
          (request) async => jsonResponse({'e': 0, 'd': {}}, request),
        ),
      );
      final (_, service) = makeService([client]);
      expect(await service.fetchStarterDepartId('350'), isNull);
    });
  });
}
