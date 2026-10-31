import 'package:bugaoshan/pages/campus/fitness_test/models/fitness_models.dart';
import 'package:bugaoshan/scu_backend/core/api_session.dart';
import 'package:bugaoshan/scu_backend/fitness/fitness_auth.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';

/// 体测系统业务 API 的最小契约，供 [FitnessTestProvider] 注入和测试替身使用。
abstract interface class FitnessTestApi {
  Future<List<FitnessNotice>> fetchNotices();

  Future<FitnessScore?> fetchScore(int year);
}

/// 体测系统 API Service（第 1 层）。
///
/// 请求认证、体测子系统 session 失效识别和单次重试均由 [ApiSession] 完成。
class FitnessApiService implements FitnessTestApi {
  static const _tag = 'FitnessApiService';
  static final _baseUrl = Uri.parse(
    'https://pead.scu.edu.cn/bdlp_h5_fitness_test/public/index.php',
  );

  // ignore: unused_field
  final FitnessAuth _auth;
  final ApiSession _session;

  FitnessApiService(this._auth, {ApiSession? session})
    : _session =
          session ??
          ApiSession(
            getClient: _auth.getClient,
            invalidate: _auth.invalidate,
            baseUrl: _baseUrl,
            logTag: _tag,
            jsonValidator: (json) {
              final message = json['info']?.toString() ?? '';
              if (message.contains('登录信息失效') || message.contains('请重新登录')) {
                throw UnauthenticatedException(message);
              }
            },
            defaultHeaders: const {
              'Origin': 'https://pead.scu.edu.cn',
              'Referer':
                  'https://pead.scu.edu.cn/bdlp_h5_fitness_test/public/index.php/index/index',
            },
          );

  @override
  Future<List<FitnessNotice>> fetchNotices() async {
    final json = await _session.postFormForJsonMap(
      '/index/News/getSchoolNoticeList',
      {},
      apiName: 'getSchoolNoticeList',
    );
    _checkStatus(json, 'getSchoolNoticeList');
    final data = json['data'];
    if (data is! List) {
      throw const ServiceException('体测通知响应格式错误');
    }
    return data
        .map(
          (item) => FitnessNotice.fromJson(
            Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          ),
        )
        .toList();
  }

  @override
  Future<FitnessScore?> fetchScore(int year) async {
    final json = await _session.postFormForJsonMap(
      '/index/Report/getStudentScore',
      {'year_num': year.toString()},
      apiName: 'getStudentScore',
    );
    _checkStatus(json, 'getStudentScore');
    final data = json['data'];
    if (data is! Map) return null;
    return FitnessScore.fromJson(Map<String, dynamic>.from(data));
  }

  void _checkStatus(Map<String, dynamic> json, String api) {
    if (json['status']?.toString() != '1') {
      final message = json['info']?.toString() ?? '体测服务请求失败';
      throw ServiceException(message);
    }
  }
}
