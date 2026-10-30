import 'dart:convert';

/// 办事大厅动态表单定义（`/site/form/start-data` 响应）
///
/// 服务端动态下发字段 key、权限和已填数据。字段的**中文标签和选项**不在
/// 此接口中，需由 UI 层从表单渲染截图/字段配置接口获取后映射。
///
/// 真实响应样例（app_id=350 离校请假）：
/// ```json
/// {"e":0,"m":"操作成功","d":{
///   "steps":[], "currstep":0, "currform":[1419],
///   "auth":{"1419":{ "User_21":"require", "Calendar_25":"require", ... }},
///   "data":{"1419":{ "User_21":"2025141230072", ... }},
///   "draft":0, "draftAuth":[]
/// }}
/// ```
class ServiceFormDefinition {
  /// 当前生效的表单 id 列表（如 [1419]）。
  final List<dynamic> currform;

  /// 字段 key → 权限。权限值如 `require` / `writable` / `readable` /
  /// `front_readonly`。
  final Map<String, String> auth;

  /// 字段 key → 已填值（如用户自动带出的学号、姓名等）。
  final Map<String, dynamic> data;

  ServiceFormDefinition({
    required this.currform,
    required this.auth,
    required this.data,
  });

  /// 解析 start-data 的 `d` 字段。
  factory ServiceFormDefinition.fromJson(Map<String, dynamic> json) {
    // 取第一个当前表单 id 对应的 auth/data；多表单场景需按 currform 遍历。
    // 注意：currform 里的元素是 int（如 1419），而 auth/data 的 key 是 String "1419"，
    // 必须转成 String 才能查到。
    final rawFormId = (json['currform'] as List?)?.isNotEmpty == true
        ? json['currform'][0]
        : json['currform'];
    final formId = rawFormId?.toString();
    final auth = json['auth'];
    final data = json['data'];

    Map<String, String> authMap = {};
    Map<String, dynamic> dataMap = {};
    if (auth is Map) {
      if (formId != null && auth[formId] is Map) {
        final inner = auth[formId] as Map;
        authMap = inner.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    }
    if (data is Map) {
      if (formId != null && data[formId] is Map) {
        dataMap = (data[formId] as Map).map(
          (k, v) => MapEntry(k.toString(), v),
        );
      }
    }
    return ServiceFormDefinition(
      currform: (json['currform'] as List?) ?? const [],
      auth: authMap,
      data: dataMap,
    );
  }

  /// 字段是否必填。
  bool isRequired(String fieldKey) => auth[fieldKey] == 'require';

  /// 字段是否只读（前端不可改）。
  bool isReadOnly(String fieldKey) {
    final a = auth[fieldKey];
    return a == 'readable' || a == 'front_readonly' || a == 'readonly';
  }

  /// 需要用户填写的字段（非只读）。
  List<String> get editableFields => auth.keys
      .where((k) => !isReadOnly(k) && !(data[k] != null && data[k] != ''))
      .toList();

  /// 已由服务端带出、用户不可改的字段（如学号、姓名）。
  List<String> get prefilledFields => auth.keys
      .where((k) => isReadOnly(k) && data[k] != null && data[k] != '')
      .toList();

  @override
  String toString() =>
      'ServiceFormDefinition(currform=$currform, auth=$auth, data=$data)';
}

/// 便捷：从原始 JSON 字符串解析。
ServiceFormDefinition parseServiceFormDefinition(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  if (json['e'] != 0 || json['d'] == null) {
    throw FormatException('form/start-data 响应异常: ${json['m']}');
  }
  return ServiceFormDefinition.fromJson(json['d'] as Map<String, dynamic>);
}
