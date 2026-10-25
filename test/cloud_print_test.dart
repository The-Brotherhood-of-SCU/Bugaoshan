import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/cloud_print.dart';
import 'package:bugaoshan/providers/cloud_print_provider.dart';
import 'package:bugaoshan/services/api/cloud_print_api_service.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/cloud_print_auth.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:bugaoshan/utils/constants.dart';

class _Root extends ChangeNotifier implements ScuAuth {
  _Root(this.client);
  CookieClient client;
  String? identity = 'account-a';
  bool ready = true;
  @override
  bool get isReady => ready;
  @override
  AuthState get state => ready ? AuthState.ready : AuthState.unknown;
  @override
  String? get principal => identity;
  @override
  Future<CookieClient> getClient() async => client;
  void switchAccount(CookieClient next) {
    client = next;
    identity = 'account-b';
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements CloudPrintAuth {
  _Auth(this.client);
  final CookieClient client;
  int invalidations = 0;
  bool current = true;
  @override
  final Uri base = Uri.parse(cloudPrintBaseUrl);
  @override
  Future<CookieClient> getClient() async => client;
  @override
  Future<void> check(CookieClient client) async {}
  @override
  bool isCurrent(CookieClient client) => current;
  @override
  void invalidate() {
    invalidations++;
  }

  @override
  Future<http.Response> read(
    CookieClient client,
    String method,
    Uri uri,
  ) async => http.Response.fromStream(
    await client.sendOnce(http.Request(method, uri)),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QueueApi implements CloudPrintApiService {
  final List<String> uploads = [];
  final Map<String, Exception> failOnce = {};
  final Set<int> failDownloadOnce = {};
  Completer<void>? hold;
  int inFlight = 0, maxInFlight = 0, jobCalls = 0;
  List<CloudPrintJob> jobs = [];
  List<CloudScanJob> scans = [];
  final Set<int> failDeleteOnce = {};
  @override
  Future<List<CloudPrintJob>> fetchJobs() async {
    jobCalls++;
    return jobs;
  }

  @override
  Future<List<CloudScanJob>> fetchScans() async => scans;
  @override
  Future<CloudPrintUploadResult> upload(
    CloudPrintFile file,
    CloudPrintOptions options, {
    void Function(double)? onProgress,
    Set<int>? knownJobIds,
  }) async {
    uploads.add(file.name);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    onProgress?.call(0.5);
    try {
      if (hold case final block?) await block.future;
      final error = failOnce.remove(file.name);
      if (error != null) throw error;
      return const CloudPrintUploadResult(verified: true);
    } finally {
      inFlight--;
    }
  }

  final List<int> deletedJobs = [];
  final List<int> deletedScans = [];
  @override
  Future<void> deleteJob(CloudPrintJob job) async {
    if (failDeleteOnce.remove(job.id)) {
      throw const ServiceException('delete failed');
    }
    deletedJobs.add(job.id);
    jobs = jobs.where((item) => item.id != job.id).toList();
  }

  @override
  Future<void> deleteScan(CloudScanJob scan) async {
    if (failDeleteOnce.remove(scan.id)) {
      throw const ServiceException('delete failed');
    }
    deletedScans.add(scan.id);
    scans = scans.where((item) => item.id != scan.id).toList();
  }

  @override
  Future<void> downloadScan(
    CloudScanJob scan,
    String destination, {
    void Function(double)? onProgress,
  }) async {
    if (failDownloadOnce.remove(scan.id)) {
      throw const ServiceException('test download failure');
    }
    await File(destination).parent.create(recursive: true);
    await File(destination).writeAsString('scan-${scan.id}');
    onProgress?.call(1);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    getIt.registerSingleton<AppLogger>(AppLogger());
    temp = await Directory.systemTemp.createTemp('bugaoshan-cloudprint-test-');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
    await getIt.reset();
  });
  Future<String> fixture(String name) async {
    final f = File('${temp.path}/$name');
    await f.parent.create(recursive: true);
    await f.writeAsString('%PDF-1.4\ntest fixture\n');
    return f.path;
  }

  test('默认 A4 黑白长边，范围/份数不会互相覆盖，异常范围不接受', () {
    expect(const CloudPrintOptions().toFields(), {
      'dwColor': '1',
      'dwPaperId': '9',
      'dwDuplex': '2',
      'dwCopies': '1',
      'dwFrom': '0',
      'dwTo': '0',
    });
    expect(
      const CloudPrintOptions(
        copies: 2,
        pages: '2-3',
        paper: CloudPrintPaper.a3,
        color: CloudPrintColor.color,
        duplex: CloudPrintDuplex.shortEdge,
      ).toFields(),
      {
        'dwColor': '2',
        'dwPaperId': '8',
        'dwDuplex': '3',
        'dwCopies': '2',
        'dwFrom': '2',
        'dwTo': '3',
      },
    );
    for (final range in ['0', '3-2', '1,3', '-1', '1-', '4294967296']) {
      expect(
        () => CloudPrintOptions(pages: range).toFields(),
        throwsFormatException,
      );
    }
    expect(
      () => const CloudPrintOptions(copies: 0).toFields(),
      throwsFormatException,
    );
  });

  test('没有后缀或空文件属于格式错误，扫描过期标志按 256 位判断', () async {
    await expectLater(
      CloudPrintFile.fromPath(await fixture('no-extension')),
      throwsFormatException,
    );
    final empty = File('${temp.path}/empty.pdf');
    await empty.writeAsBytes([]);
    await expectLater(
      CloudPrintFile.fromPath(empty.path),
      throwsFormatException,
    );
    expect(CloudScanJob.fromJson({'dwStatus': 257}).expired, isTrue);
    expect(CloudScanJob.fromJson({'dwStatus': 1}).expired, isFalse);
  });

  test('单次传输发生 ClientException 不重放或替换 client', () async {
    var requests = 0, replacements = 0;
    final client = CookieClient(
      inner: MockClient((request) async {
        requests++;
        throw http.ClientException('lost');
      }),
      innerFactory: () {
        replacements++;
        return MockClient((request) async => http.Response('', 200));
      },
    );
    await expectLater(
      client.sendOnce(
        http.Request('POST', Uri.parse('$cloudPrintBaseUrl/upload')),
      ),
      throwsA(isA<http.ClientException>()),
    );
    expect(requests, 1);
    expect(replacements, 0);
    client.close();
  });

  test('JSON SSoPage + cookie 链建立会话，根身份变化使认证缓存失效', () async {
    var loggedIn = false, links = 0;
    final client = CookieClient(
      inner: MockClient((request) async {
        expect(request.headers['authorization'], isNull);
        expect(request.headers['user-agent'], kDefaultUserAgent);
        expect(
          request.headers['accept'],
          request.url.path.startsWith('/api/')
              ? 'application/json'
              : 'text/html,application/xhtml+xml,*/*',
        );
        switch (request.url.path) {
          case '/api/client/Auth/Check':
            return http.Response(
              loggedIn ? '{"code":0,"SessionId":"test-session"}' : '{"code":4}',
              200,
              headers: {'set-cookie': 'anonymous=same-jar; Path=/'},
            );
          case '/api/client/Auth/SSoPage':
            links++;
            expect(request.headers['cookie'], contains('anonymous=same-jar'));
            return http.Response(
              '{"code":0,"result":"https://libic.scu.edu.cn/library"}',
              200,
            );
          case '/library':
            return http.Response(
              '',
              302,
              headers: {'location': 'https://id.scu.edu.cn/cas'},
            );
          case '/cas':
            return http.Response(
              '',
              302,
              headers: {'location': '$cloudPrintBaseUrl/callback'},
            );
          case '/callback':
            loggedIn = true;
            return http.Response('ready', 200);
          default:
            throw StateError('unexpected path');
        }
      }),
    );
    final root = _Root(client);
    final actual = CloudPrintAuth(root);
    expect(await actual.getClient(), same(client));
    expect(await actual.getClient(), same(client));
    expect(links, 1);
    final next = CookieClient(
      inner: MockClient(
        (request) async => http.Response('{"code":0,"SessionId":"next"}', 200),
      ),
    );
    root.switchAccount(next);
    expect(actual.isCurrent(client), isFalse);
    expect(await actual.getClient(), same(next));
    actual.dispose();
    root.dispose();
    client.close();
    next.close();
  });

  test('SSO 不跟随未允许的站点，也不将带票据的 URL 写入错误', () async {
    var external = false;
    final client = CookieClient(
      inner: MockClient((request) async {
        if (request.url.path.endsWith('/Check')) {
          return http.Response('{"code":4}', 200);
        }
        if (request.url.path.endsWith('/SSoPage')) {
          return http.Response(
            '{"code":0,"result":"https://evil.example/?ticket=SECRET"}',
            200,
          );
        }
        external = true;
        return http.Response('', 200);
      }),
    );
    final root = _Root(client);
    final auth = CloudPrintAuth(root);
    await expectLater(
      auth.getClient(),
      throwsA(
        isA<ServiceException>().having(
          (e) => e.message,
          'message',
          isNot(contains('SECRET')),
        ),
      ),
    );
    expect(external, isFalse);
    auth.dispose();
    root.dispose();
    client.close();
  });

  for (final mode in [
    'ok',
    '401',
    '403',
    'code4',
    '307',
    'missing',
    'callback401',
    '413',
    'lost',
  ]) {
    test('实际 multipart 响应 $mode：仅提交一次，认证失效按不确定结果处理', () async {
      final file = await CloudPrintFile.fromPath(await fixture('中文文件.pdf'));
      var posts = 0;
      final client = CookieClient(
        inner: MockClient((request) async {
          if (request.url.path.endsWith('/Get')) {
            return http.Response(
              jsonEncode({
                'code': 0,
                'result': posts == 0
                    ? []
                    : [
                        {'dwJobId': 99, 'szJobName': file.name},
                      ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.url.path.endsWith('/Upload')) {
            posts++;
            final raw = utf8.decode(request.bodyBytes);
            expect(raw, contains('filename="中文文件.pdf"'));
            expect(raw, contains('%PDF-1.4'));
            expect(raw, contains('name="dwDuplex"\r\n\r\n2\r\n'));
            expect(request.contentLength, greaterThan(file.size));
            return switch (mode) {
              '401' => http.Response('', 401),
              '403' => http.Response('', 403),
              '413' => http.Response('', 413),
              '307' => http.Response(
                '',
                307,
                headers: {'location': '/api/client/CloudPrint/Upload'},
              ),
              'missing' => http.Response('ok', 200),
              'lost' => throw http.ClientException('lost after body'),
              _ => http.Response(
                '',
                302,
                headers: {
                  'location':
                      '$cloudPrintJobsPath?code=${mode == 'code4' ? 4 : 0}&fee=40',
                },
              ),
            };
          }
          if (request.url.path == cloudPrintJobsPath) {
            return http.Response('page', mode == 'callback401' ? 401 : 200);
          }
          throw StateError('unexpected path');
        }),
      );
      final auth = _Auth(client);
      final api = CloudPrintApiService(auth);
      if (mode == 'ok') {
        final result = await api.upload(file, const CloudPrintOptions());
        expect(result.verified, isTrue);
        expect(result.jobs.single.id, 99);
      } else if (mode == '413') {
        await expectLater(
          api.upload(file, const CloudPrintOptions()),
          throwsA(
            isA<ServiceException>().having((e) => e.statusCode, 'status', 413),
          ),
        );
      } else {
        await expectLater(
          api.upload(file, const CloudPrintOptions()),
          throwsA(isA<CloudPrintUploadUncertainException>()),
        );
      }
      expect(posts, 1);
      expect(auth.invalidations, 0);
      auth.dispose();
      client.close();
    });
  }

  test('批量逐文件隔离失败，重试不重复提交成功项', () async {
    final api = _QueueApi()
      ..failOnce['b.pdf'] = const ServiceException('rejected');
    final provider = CloudPrintProvider(api, uploadConcurrency: 1);
    addTearDown(provider.dispose);
    final paths = [
      await fixture('a.pdf'),
      await fixture('b.pdf'),
      await fixture('c.pdf'),
    ];
    final added = await provider.addPaths([...paths, paths.first]);
    expect(added.added, 3);
    expect(added.duplicates, 1);
    await provider.uploadPending();
    expect(api.maxInFlight, 1);
    expect(provider.failedCount, 1);
    provider.retryFailed();
    await provider.uploadPending();
    expect(api.uploads, ['a.pdf', 'b.pdf', 'c.pdf', 'b.pdf']);
    expect(
      provider.queue.every(
        (item) => item.status == CloudPrintQueueStatus.uploaded,
      ),
      isTrue,
    );
  });

  test('待核对项阻止队列继续，不进入失败重试；只有显式核对后可排队', () async {
    final api = _QueueApi()
      ..failOnce['a.pdf'] = const CloudPrintUploadUncertainException();
    final provider = CloudPrintProvider(api, uploadConcurrency: 1);
    addTearDown(provider.dispose);
    await provider.addPaths([await fixture('a.pdf'), await fixture('b.pdf')]);
    await provider.uploadPending();
    final uncertain = provider.queue.first;
    expect(uncertain.status, CloudPrintQueueStatus.uncertain);
    expect(api.uploads, ['a.pdf']);
    provider.retryFailed();
    provider.requeue(uncertain);
    expect(uncertain.status, CloudPrintQueueStatus.uncertain);
    provider.requeue(uncertain, confirmedMissing: true);
    await provider.uploadPending();
    expect(api.uploads, ['a.pdf', 'a.pdf', 'b.pdf']);
  });

  test('重复启动不并发，停止保留后续文件，登出后旧回调不能污染队列', () async {
    final api = _QueueApi()..hold = Completer<void>();
    final provider = CloudPrintProvider(api, uploadConcurrency: 1);
    addTearDown(provider.dispose);
    await provider.addPaths([await fixture('a.pdf'), await fixture('b.pdf')]);
    final run = provider.uploadPending();
    await Future<void>.delayed(Duration.zero);
    await provider.uploadPending();
    provider.stopAfterCurrent();
    api.hold!.complete();
    await run;
    expect(api.uploads, ['a.pdf']);
    expect(provider.pendingCount, 1);
    api.hold = Completer<void>();
    final old = provider.uploadPending();
    await Future<void>.delayed(Duration.zero);
    provider.clear();
    api.hold!.complete();
    await old;
    expect(provider.queue, isEmpty);
    expect(provider.jobs, isEmpty);
    expect(provider.uploading, isFalse);
  });

  test('扫描下载失败隔离、过期项跳过，文件名不允许路径穿越', () async {
    final api = _QueueApi()..failDownloadOnce.add(1);
    final provider = CloudPrintProvider(api, uploadConcurrency: 1);
    addTearDown(provider.dispose);
    final scans = [
      CloudScanJob.fromJson({'dwJobId': 1, 'szDisplayName': 'a.pdf'}),
      CloudScanJob.fromJson({'dwJobId': 2, 'szDisplayName': '../../evil.pdf'}),
      CloudScanJob.fromJson({
        'dwJobId': 3,
        'szDisplayName': 'expired.pdf',
        'dwStatus': 256,
      }),
    ];
    await provider.downloadScans(scans, Directory('${temp.path}/downloads'));
    expect(provider.scanFailures, {1});
    expect(provider.scanFiles.keys, [2]);
    expect(
      provider.scanFiles[2],
      predicate<String>(
        (path) => p.isWithin(p.join(temp.path, 'downloads'), path),
      ),
    );
    await provider.downloadScans(scans, Directory('${temp.path}/downloads'));
    expect(provider.scanFiles.keys.toSet(), {1, 2});
    expect(provider.scanFailures, isEmpty);
  });

  for (final mode in ['ok', 'auth', 'html', 'truncated', 'lost']) {
    test('扫描文件流 $mode：认证只重试读取，失败不留下不完整文件', () async {
      final bytes = utf8.encode('%PDF-1.4\nscan fixture\n');
      var requests = 0;
      final client = CookieClient(
        inner: MockClient.streaming((request, body) async {
          await body.drain<void>();
          expect(request.method, 'GET');
          expect(request.url.path, '/api/client/Scan/Download');
          expect(request.url.queryParameters['dwJobId'], '7');
          requests++;
          if (mode == 'auth' && requests == 1) {
            return http.StreamedResponse(
              Stream.value(utf8.encode('{"code":4}')),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (mode == 'html') {
            return http.StreamedResponse(
              Stream.value(utf8.encode('<html>login</html>')),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }
          return http.StreamedResponse(
            mode == 'lost'
                ? Stream<List<int>>.fromIterable([
                    bytes.take(5).toList(),
                  ]).asyncMap((chunk) => throw const HttpException('lost'))
                : Stream.fromIterable([
                    bytes.take(5).toList(),
                    bytes.skip(5).toList(),
                  ]),
            200,
            contentLength: bytes.length + (mode == 'truncated' ? 5 : 0),
            headers: {'content-type': 'application/pdf'},
          );
        }),
      );
      final auth = _Auth(client);
      final api = CloudPrintApiService(auth);
      addTearDown(client.close);
      addTearDown(auth.dispose);
      final scan = CloudScanJob.fromJson({
        'dwJobId': 7,
        'dwFileSize': bytes.length,
      });
      final target = File(p.join(temp.path, 'scan.pdf'));
      // 已存在的完整下载只有在新下载完整时才会替换。
      await target.writeAsString('previous complete file');
      if (mode == 'ok' || mode == 'auth') {
        final progress = <double>[];
        await api.downloadScan(scan, target.path, onProgress: progress.add);
        expect(await target.readAsBytes(), bytes);
        expect(progress.last, 1);
        expect(auth.invalidations, mode == 'auth' ? 1 : 0);
      } else {
        await expectLater(
          api.downloadScan(scan, target.path),
          throwsA(isA<Exception>()),
        );
        expect(await target.readAsString(), 'previous complete file');
      }
      expect(await File('${target.path}.part').exists(), isFalse);
      expect(requests, mode == 'auth' ? 2 : 1);
    });
  }

  test('认证进行中切换账号不接受旧认证结果', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final oldClient = CookieClient(
      inner: MockClient((request) {
        started.complete();
        return response.future;
      }),
    );
    final newClient = CookieClient(
      inner: MockClient(
        (request) async => http.Response('{"code":0,"SessionId":"next"}', 200),
      ),
    );
    final root = _Root(oldClient);
    final auth = CloudPrintAuth(root);
    addTearDown(auth.dispose);
    addTearDown(root.dispose);
    addTearDown(oldClient.close);
    addTearDown(newClient.close);
    final old = auth.getClient();
    final rejected = expectLater(old, throwsA(isA<UnauthenticatedException>()));
    await started.future;
    root.switchAccount(newClient);
    expect(await auth.getClient(), same(newClient));
    response.complete(http.Response('{"code":0,"SessionId":"old"}', 200));
    await rejected;
    expect(auth.isCurrent(oldClient), isFalse);
    expect(auth.isCurrent(newClient), isTrue);
  });

  test('打印任务用纸型、颜色、单双面和创建时间描述，界面不读状态码', () {
    final job = CloudPrintJob.fromJson({
      'dwJobId': 142116,
      'szJobName': 'a.pdf',
      'dwPages': 4,
      'dwCopies': 1,
      'dwStatus': 1,
      'szAttribe': 'single,',
      'dwCreateDate': 20261025,
      'dwCreateTime': 173804,
      'szPaperDetail':
          '[{"dwPaperID":9,"dwBWPages":4,"dwColorPages":0,"dwPaperNum":4}]',
    });
    expect(job.colored, isFalse);
    expect(job.duplex, CloudPrintDuplex.simplex);
    expect(job.paperIds, {9});
    expect(job.createdDateLabel, '2026-10-25');
    expect(job.createdTimeLabel, '17:38');
    expect(
      CloudPrintJob.fromJson({'szAttribe': 'vdup,color,'}).duplex,
      CloudPrintDuplex.longEdge,
    );
    expect(CloudPrintJob.fromJson({'szAttribe': 'vdup,color,'}).colored, isTrue);
    // 属性缺失时按列表模板的兜底分支判为短边双面，纸型解析失败不抛异常。
    expect(
      CloudPrintJob.fromJson({'szPaperDetail': 'not-json'}).paperIds,
      isEmpty,
    );
  });

  test('删除任务只发一次 POST Del，新旧任务 ID 相同', () async {
    late http.Request captured;
    final client = CookieClient(
      inner: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"code":0,"message":"ok"}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final auth = _Auth(client);
    final api = CloudPrintApiService(auth);
    await api.deleteJob(
      CloudPrintJob.fromJson({'dwJobId': 139077, 'szJobName': 'a.pdf'}),
    );
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/client/PrintJob/Del');
    expect(captured.headers['content-type'], contains('application/json'));
    expect(jsonDecode(captured.body), {
      'dwJobId': 139077,
      'dwOldJobId': 139077,
    });
    expect(auth.invalidations, 0);
    auth.dispose();
    client.close();
  });

  test('预览按任务与创建时间取单页，base64 PNG 解码后返回原始字节', () async {
    final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
    late Uri requested;
    final client = CookieClient(
      inner: MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode({'code': 0, 'result': base64Encode(png)}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final auth = _Auth(client);
    final api = CloudPrintApiService(auth);
    final job = CloudPrintJob.fromJson({
      'dwJobId': 139077,
      'dwCreateTime': 173804,
    });
    expect(await api.previewPage(job, 2), png);
    expect(requested.path, '/api/client/PrintJob/PreviewPage');
    expect(requested.queryParameters['dwJobId'], '139077');
    expect(requested.queryParameters['dwCreateTime'], '173804');
    expect(requested.queryParameters['pageNo'], '2');
    auth.dispose();
    client.close();
  });

  test('默认 5 路并发上传，停止只影响尚未派发的文件', () async {
    final api = _QueueApi()..hold = Completer<void>();
    final provider = CloudPrintProvider(api);
    addTearDown(provider.dispose);
    await provider.addPaths([
      for (final name in ['a.pdf', 'b.pdf', 'c.pdf', 'd.pdf', 'e.pdf', 'f.pdf'])
        await fixture(name),
    ]);
    final run = provider.uploadPending();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // 批次基线只查一次，前 5 个文件同时在传。
    expect(api.jobCalls, 1);
    expect(api.maxInFlight, 5);
    provider.stopAfterCurrent();
    api.hold!.complete();
    await run;
    expect(api.uploads, hasLength(5));
    expect(
      provider.queue.where(
        (item) => item.status == CloudPrintQueueStatus.pending,
      ),
      hasLength(1),
    );
    expect(provider.uploading, isFalse);
  });

  test('批量删除打印任务与扫描记录逐项隔离失败', () async {
    final api = _QueueApi();
    final provider = CloudPrintProvider(api, uploadConcurrency: 1);
    addTearDown(provider.dispose);
    api.jobs = [
      CloudPrintJob.fromJson({'dwJobId': 1, 'szJobName': 'a.pdf'}),
      CloudPrintJob.fromJson({'dwJobId': 2, 'szJobName': 'b.pdf'}),
      CloudPrintJob.fromJson({'dwJobId': 3, 'szJobName': 'c.pdf'}),
    ];
    await provider.refreshJobs();
    final jobsResult = await provider.deleteJobs(provider.jobs.take(2));
    expect(jobsResult.deleted, 2);
    expect(jobsResult.failed, 0);
    expect(api.deletedJobs, [1, 2]);
    expect(provider.jobs.map((job) => job.id), [3]);

    api.scans = [
      CloudScanJob.fromJson({'dwJobId': 11, 'szDisplayName': 's1.pdf'}),
      CloudScanJob.fromJson({
        'dwJobId': 12,
        'szDisplayName': 's2.pdf',
        'dwStatus': 256,
      }),
    ];
    await provider.refreshScans();
    final scansResult = await provider.deleteScans(provider.scans);
    expect(scansResult.deleted, 2);
    expect(api.deletedScans, [11, 12]);
    expect(provider.scans, isEmpty);
  });

  test('删除失败时保留列表项并返回失败数', () async {
    final api = _QueueApi()..failDeleteOnce.add(1);
    final provider = CloudPrintProvider(api, uploadConcurrency: 1);
    addTearDown(provider.dispose);
    api.jobs = [
      CloudPrintJob.fromJson({'dwJobId': 1, 'szJobName': 'a.pdf'}),
      CloudPrintJob.fromJson({'dwJobId': 2, 'szJobName': 'b.pdf'}),
    ];
    await provider.refreshJobs();
    final result = await provider.deleteJobs(provider.jobs);
    expect(result.deleted, 1);
    expect(result.failed, 1);
    expect(provider.jobs.map((job) => job.id), [1]);
  });
}
