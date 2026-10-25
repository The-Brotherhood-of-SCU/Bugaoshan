import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:bugaoshan/models/cloud_print.dart';
import 'package:bugaoshan/services/api/api_request.dart';
import 'package:bugaoshan/services/auth/cloud_print_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/constants.dart';

/// 文件可能已被服务器接收。此异常不能作为认证错误自动重传。
class CloudPrintUploadUncertainException extends ServiceException {
  const CloudPrintUploadUncertainException() : super('上传结果待核对，请先查看打印任务，勿直接重传');
}

class CloudPrintUploadResult {
  const CloudPrintUploadResult({
    this.jobs = const [],
    this.feeRaw,
    this.verified = false,
  });
  final List<CloudPrintJob> jobs;
  final String? feeRaw;
  final bool verified;
}

/// 读取允许恢复认证；文件提交之后不使用认证重试模板。
class CloudPrintApiService {
  CloudPrintApiService(this.auth);
  static const _tag = 'CloudPrintApiService';
  final CloudPrintAuth auth;
  Uri get base => auth.base;

  Future<List<Map<String, dynamic>>> _list(String path) =>
      retryOnUnauthenticated(
        auth.getClient,
        (client) async {
          final body = checkCloudPrintResponse(
            await auth.read(client, 'GET', base.resolve(path)),
          );
          if (!body.containsKey('result')) {
            throw const ServiceException('云打印列表缺少结果');
          }
          try {
            return cloudPrintResultList(body['result']);
          } catch (_) {
            throw const ServiceException('云打印列表格式错误');
          }
        },
        invalidate: auth.invalidate,
        logTag: _tag,
      );

  Future<List<CloudPrintJob>> fetchJobs() async => (await _list(
    '/api/client/PrintJob/Get',
  )).map(CloudPrintJob.fromJson).where((job) => job.id > 0).toList();

  Future<List<CloudScanJob>> fetchScans() async =>
      (await _list(
          '/api/client/Scan/Get',
        )).map(CloudScanJob.fromJson).where((job) => job.id > 0).toList()
        ..sort((a, b) {
          final date = b.date.compareTo(a.date);
          return date != 0 ? date : b.time.compareTo(a.time);
        });

  Future<CloudPrintUploadResult> upload(
    CloudPrintFile file,
    CloudPrintOptions options, {
    void Function(double progress)? onProgress,
  }) async {
    final fields = options.toFields();
    // 在发送前发现文件失效可安全报错；文件字节从 openRead 流式读取。
    final source = File(file.path);
    if (!await source.exists() || await source.length() != file.size) {
      throw const ServiceException('待上传文件已变化，请重新选择');
    }
    final before = await fetchJobs();
    final client = await auth.getClient();
    await auth.check(client);
    if (!auth.isCurrent(client)) throw const UnauthenticatedException();
    final back = base
        .resolve(cloudPrintJobsPath)
        .replace(
          queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'},
        );
    final request =
        http.MultipartRequest(
            'POST',
            base.resolve('/api/client/CloudPrint/Upload'),
          )
          ..followRedirects = false
          ..fields.addAll({...fields, 'BackURL': back.toString()})
          ..headers.addAll({
            'Origin': base.origin,
            'Referer': base.resolve(cloudPrintPagePath).toString(),
            'User-Agent': kDefaultUserAgent,
          });
    var sent = 0;
    final stream = source.openRead().map((bytes) {
      sent += bytes.length;
      onProgress?.call((sent / file.size).clamp(0.0, 1.0).toDouble());
      return bytes;
    });
    request.files.add(
      http.MultipartFile('szPath', stream, file.size, filename: file.name),
    );
    String? fee;
    var accepted = false;
    // 从此处开始，只要没有明确拒绝，就按「可能已接收」处理。
    try {
      var current = request.url;
      var response = await http.Response.fromStream(
        await client.sendOnce(request, timeout: const Duration(minutes: 2)),
      ).timeout(const Duration(minutes: 2));
      for (var hop = 0; hop < 10; hop++) {
        if ([301, 302, 303].contains(response.statusCode)) {
          final location = response.headers['location'];
          if (location == null) {
            throw const CloudPrintUploadUncertainException();
          }
          final next = current.resolve(location);
          if (next.userInfo.isNotEmpty ||
              next.origin != base.origin ||
              next.path != cloudPrintJobsPath) {
            throw const CloudPrintUploadUncertainException();
          }
          current = next;
          response = await http.Response.fromStream(
            await client.sendOnce(http.Request('GET', current)),
          ).timeout(kHttpTimeout);
          continue;
        }
        if (response.statusCode == 413 && current.path == request.url.path) {
          throw const ServiceException('文件超出打印服务器大小限制', statusCode: 413);
        }
        if (response.statusCode != 200) {
          throw const CloudPrintUploadUncertainException();
        }
        final codes = current.queryParametersAll['code'];
        if (codes == null || codes.length != 1) {
          throw const CloudPrintUploadUncertainException();
        }
        final code = int.tryParse(codes.single);
        if (code == null || code == 4) {
          throw const CloudPrintUploadUncertainException();
        }
        if (code != 0) throw ServiceException('打印服务器拒绝此文档（code=$code）');
        fee = current.queryParameters['fee'];
        accepted = true;
        break;
      }
      if (!accepted) throw const CloudPrintUploadUncertainException();
    } on ServiceException catch (error, stack) {
      AppLog.e(_tag, '云打印文件提交失败', error: error, stackTrace: stack);
      rethrow;
    } catch (_, stack) {
      AppLog.e(
        _tag,
        '云打印提交结果不确定',
        error: const CloudPrintUploadUncertainException(),
        stackTrace: stack,
      );
      throw const CloudPrintUploadUncertainException();
    }
    // code=0 已确认接收；列表暂不可读不能把已成功上传误标成可重试的失败。
    final known = before.map((job) => job.id).toSet();
    try {
      final added = (await fetchJobs())
          .where((job) => !known.contains(job.id) && job.name == file.name)
          .toList();
      return CloudPrintUploadResult(
        jobs: added,
        feeRaw: fee,
        verified: added.length == 1,
      );
    } catch (_, stack) {
      AppLog.w(
        _tag,
        '上传已接受，任务列表尚未核对',
        error: const ServiceException('待查询任务列表'),
        stackTrace: stack,
      );
      return CloudPrintUploadResult(feeRaw: fee);
    }
  }

  /// 仅下载设备已产生的扫描文件；路径由调用方生成，不信任服务端文件名。
  Future<void> downloadScan(
    CloudScanJob scan,
    String destination, {
    void Function(double progress)? onProgress,
  }) async {
    if (scan.expired) throw const ServiceException('扫描文件已过期');
    // 独立临时目录避免登出/重新登录后的下载共用同一个 .part。
    final parent = File(destination).parent;
    await parent.create(recursive: true);
    final scratch = await parent.createTemp('.scan-');
    final partial = File(
      '${scratch.path}${Platform.pathSeparator}document.part',
    );
    try {
      await retryOnUnauthenticated(
        auth.getClient,
        (client) async {
          final uri = base
              .resolve('/api/client/Scan/Download')
              .replace(queryParameters: {'dwJobId': '${scan.id}'});
          final response = await client.sendOnce(
            http.Request('GET', uri),
            timeout: const Duration(minutes: 2),
          );
          if ([301, 302, 303, 401, 403].contains(response.statusCode)) {
            await response.stream.drain<void>();
            throw const UnauthenticatedException();
          }
          final contentType = (response.headers['content-type'] ?? '')
              .toLowerCase();
          if (response.statusCode != 200 || contentType.contains('text/html')) {
            await response.stream.drain<void>();
            throw const ServiceException('扫描文件下载失败');
          }
          // 有些服务会用 200 JSON 表示认证失败，不能将 JSON 保存成 PDF。
          if (contentType.contains('application/json')) {
            checkCloudPrintResponse(
              await http.Response.fromStream(response).timeout(kHttpTimeout),
            );
            throw const ServiceException('扫描文件未返回文件内容');
          }
          var received = 0;
          await response.stream
              .timeout(const Duration(minutes: 2))
              .map((bytes) {
                received += bytes.length;
                final total = response.contentLength ?? scan.size;
                if (total > 0) {
                  onProgress?.call(
                    (received / total).clamp(0.0, 1.0).toDouble(),
                  );
                }
                return bytes;
              })
              .pipe(partial.openWrite());
          if (received == 0 ||
              (response.contentLength != null &&
                  received != response.contentLength) ||
              (scan.size > 0 && received != scan.size)) {
            throw const ServiceException('扫描文件下载不完整');
          }
        },
        invalidate: auth.invalidate,
        logTag: _tag,
      );
      await partial.rename(destination);
    } catch (_, stack) {
      AppLog.e(
        _tag,
        '扫描文件下载失败',
        error: const ServiceException('文件下载失败'),
        stackTrace: stack,
      );
      rethrow;
    } finally {
      await scratch.delete(recursive: true);
    }
  }
}
