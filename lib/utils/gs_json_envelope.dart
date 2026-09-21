import 'package:bugaoshan/services/auth/scu_exceptions.dart';

/// `code` 字段视为「成功」的取值（实测是字符串 `"0"`，同时兼容数字与大小写变体）。
const Set<String> _kSuccessCodes = {'0', '200', 'success', 'true'};

/// 研教务 / EMAP（金智 WiseDU）统一响应信封解包。
///
/// 实测响应形如：
/// ```json
/// {"code":"0","datas":{"cspzcx":{"totalSize":1045,"pageSize":15,
///   "rows":[{"CSDM":"bbgl_zzfw_appid","CSMC":"自助服务-appId","CSZ":null}],
///   "extParams":{"code":1,"totalPage":0,"logId":"db11466e…"}}}}
/// ```
///
/// 三个必须注意的坑：
/// 1. `code` 是**字符串** `"0"`，不是数字 → 判定成功前先归一化。
/// 2. `datas` 的键名是**查询动作名**（这里是 `cspzcx`），调用方无法预知，
///    所以只能「找出 `datas` 里那个带 `rows` 的 Map」，不能硬编码键名。
///    同一信封里有多个 `rows` 时取第一个。
/// 3. 行内字段是**全大写数据库列名**且大量为 `null`，取值须走
///    `lib/utils/json_utils.dart` 的 `safe*` helper。
///
/// 直接返回数组的非信封接口原样透传；函数幂等（对已解包的结果再调用无副作用）。
/// `code` 非成功值时抛 [ServiceException]（不是 [UnauthenticatedException]：
/// 会话失效时服务端返回的是登录页 HTML，走不到 JSON 解码这一步）。
Object? unwrapGsEnvelope(Object? json) {
  if (json is! Map) return json;

  final code = json['code'];
  if (code != null && !_isSuccessCode(code)) {
    throw ServiceException('研教务返回错误（code=$code）');
  }

  final rows = _findRows(json);
  if (rows != null) return rows;

  final datas = json['datas'];
  if (datas is List) return datas;
  return json;
}

/// 解包并规整为「行列表」，供各 `listFromJson` / 解析器直接消费。
///
/// 非列表负载（含无法识别结构的信封）一律返回空列表，保证脏数据不崩溃。
List<Map<String, dynamic>> gsRows(Object? json) {
  final payload = unwrapGsEnvelope(json);
  if (payload is! List) return const [];
  return payload.whereType<Map<String, dynamic>>().toList();
}

/// EMAP 分页信封的元数据（供调用方决定是否继续翻页）。
///
/// `totalPage` 取自 `extParams`；两者都缺时由 [GsApiService] 用
/// `totalSize` 与实际页行数推算。
class GsPagedEnvelope {
  const GsPagedEnvelope({
    required this.rows,
    this.totalSize,
    this.pageNumber,
    this.pageSize,
    this.totalPage,
  });

  final List<Map<String, dynamic>> rows;
  final int? totalSize;
  final int? pageNumber;
  final int? pageSize;

  /// `extParams.totalPage`（服务端宣称的总页数；实测样本里该值可信）。
  final int? totalPage;
}

/// 定位信封里「带 `rows` 的那个分页 Map」，连同 `totalSize` / `pageNumber` /
/// `pageSize` / `extParams.totalPage` 一起返回；找不到 rows 结构返回 null。
///
/// 与 [gsRows] 的差别：这里**保留分页元数据**——成绩等个人数据接口必须按
/// totalPage/totalSize 循环翻页取全，不能赌一次大 pageSize（服务端 cap 了
/// 也不知道）。搜索规则与 [_findRows] 相同（动作名键不可预知，逐层下探）。
GsPagedEnvelope? gsPagedEnvelope(Object? json) {
  if (json is! Map) return null;
  final owner = _findRowsOwner(json);
  if (owner == null) return null;
  return GsPagedEnvelope(
    rows: (owner['rows'] as List).whereType<Map<String, dynamic>>().toList(),
    totalSize: _asInt(owner['totalSize']),
    pageNumber: _asInt(owner['pageNumber']),
    pageSize: _asInt(owner['pageSize']),
    totalPage: _asInt(
      (owner['extParams'] as Map?)?['totalPage'],
    ),
  );
}

/// 递归找「带 `rows` 的 Map」（rows 的父级分页对象），规则同 [_findRows]。
Map<String, dynamic>? _findRowsOwner(Object? node, [int depth = 0]) {
  if (node is! Map || depth > _maxEnvelopeDepth) return null;
  if (node['rows'] is List) return Map<String, dynamic>.from(node);
  for (final value in node.values) {
    final found = _findRowsOwner(value, depth + 1);
    if (found != null) return found;
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool _isSuccessCode(Object code) =>
    _kSuccessCodes.contains(code.toString().trim().toLowerCase());

/// 递归找 `rows`：信封键名不可预知，而嵌套深度是
/// `根 → datas → <动作名> → rows`，所以只能逐层下探。
///
/// [maxDepth] 防止异常深的结构拖垮解析。
List<Object?>? _findRows(Object? node, [int depth = 0]) {
  if (node is! Map || depth > _maxEnvelopeDepth) return null;
  final direct = node['rows'];
  if (direct is List) return direct;
  for (final value in node.values) {
    final found = _findRows(value, depth + 1);
    if (found != null) return found;
  }
  return null;
}

const int _maxEnvelopeDepth = 4;
