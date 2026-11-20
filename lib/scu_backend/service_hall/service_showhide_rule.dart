/// ShowHide 插件规则模型与表达式求值。
///
/// 从 `service_plugin_models.dart` 拆分而来。语义说明（对照 350/337/357
/// 实表校准）：按条件顺序求值，**所有**命中条件的动作按顺序应用（后者覆盖
/// 前者的同字段设置）。"默认 true" 条件通常在最前给出基准状态。
library;

/// ShowHide 插件的一个条件（`attr.data.conditions[i]`）。
class ServiceShowHideCondition {
  final String name;
  final String expression;

  const ServiceShowHideCondition({
    required this.name,
    required this.expression,
  });
}

/// ShowHide 条件命中后的动作（`attr.data.controls[i].setInfo`）。
class ServiceShowHideControl {
  /// 目标字段是否显示（isShow: 1 → 显示，0 → 隐藏；null → 不动）。
  final bool? isShow;

  /// 目标字段是否必填（isRequired: 1 → 必填，0/2 → 非必填；null → 不动）。
  final bool? isRequired;

  /// 隐藏时是否清空值（isEmpty: 1 → 清空）。提交组装对隐藏字段统一给空值，
  /// 效果等价，故仅作记录。
  final bool clearWhenHidden;

  /// 作用目标字段 key 列表。
  final List<String> targets;

  const ServiceShowHideControl({
    this.isShow,
    this.isRequired,
    this.clearWhenHidden = false,
    this.targets = const [],
  });
}

/// ShowHide 插件的完整规则：有序条件 + conkey → 动作。
///
/// 表达式支持形态见 [evalServiceShowHideExpression]。
class ServiceShowHideRule {
  final List<ServiceShowHideCondition> conditions;
  final Map<String, ServiceShowHideControl> controls;

  const ServiceShowHideRule({required this.conditions, required this.controls});

  /// 从 ShowHide 插件的 attr.data 解析；结构不符时返回 null。
  static ServiceShowHideRule? tryParse(Map<String, dynamic> attrData) {
    final rawConds = attrData['conditions'];
    final rawControls = attrData['controls'];
    if (rawConds == null || rawControls == null) return null;

    // conditions 可能是 List 或 Map（{"0": {...}, "1": {...}}）
    final condEntries = <(String, ServiceShowHideCondition)>[];
    void addCond(dynamic key, dynamic v) {
      if (v is! Map) return;
      condEntries.add((
        key.toString(),
        ServiceShowHideCondition(
          name: v['name']?.toString() ?? '',
          expression: v['expression']?.toString() ?? '',
        ),
      ));
    }

    if (rawConds is List) {
      for (var i = 0; i < rawConds.length; i++) {
        addCond(i, rawConds[i]);
      }
    } else if (rawConds is Map) {
      for (final e in rawConds.entries) {
        addCond(e.key, e.value);
      }
    }
    if (condEntries.isEmpty) return null;

    final controls = <String, ServiceShowHideControl>{};
    if (rawControls is List) {
      for (final c in rawControls) {
        if (c is! Map) continue;
        final conkey = c['conkey']?.toString();
        final setInfo = c['setInfo'];
        if (conkey == null || setInfo is! Map) continue;
        controls[conkey] = _parseControl(setInfo);
      }
    }
    return ServiceShowHideRule(
      conditions: [for (final (_, c) in condEntries) c],
      controls: controls,
    );
  }

  static ServiceShowHideControl _parseControl(Map<dynamic, dynamic> setInfo) {
    final isShow = _toInt(setInfo['isShow'], fallback: -1);
    final isRequired = _toInt(setInfo['isRequired'], fallback: -1);
    final isEmpty = _toInt(setInfo['isEmpty'], fallback: 0);
    final rawPlugins = setInfo['plugins'];
    final targets = rawPlugins is List
        ? rawPlugins.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return ServiceShowHideControl(
      isShow: isShow == -1 ? null : isShow == 1,
      isRequired: isRequired == -1 ? null : isRequired == 1,
      clearWhenHidden: isEmpty == 1,
      targets: targets,
    );
  }
}

/// 求值 ShowHide 条件表达式。返回 null 表示形态未支持（按不命中处理，
/// "默认 true" 基准条件总是可求值，因此字段不会卡在未知状态）。
///
/// 已支持形态（全部来自 4 个实表的 conditions）：
/// - `true` / `false`
/// - `{p_K}==v` / `{p_K}!=v`（v 为数字或 '字符串'，宽松比较）
/// - `{p_K}.indexOf(v)!==-1` / `==-1`（包含 / 不包含）
/// - `{p_K}[0].value==v` / `{p_K}[0]==v`（SelectV2 数组取值，!=同理）
/// - `new Date({p_K}) <= new Date('yyyy-MM-dd')`（及 <, >, >=）
/// - `{p_K}.includes('s')`、`{p_K}==''` / `!=''`
/// - `A||B` 复合（356 的审批意见判断用到）
bool? evalServiceShowHideExpression(
  String expression,
  Object? Function(String key) valueOf,
) {
  final expr = expression.trim();
  if (expr.isEmpty) return null;
  if (expr == 'true') return true;
  if (expr == 'false') return false;
  // || 复合（JS 中 && 优先级更高，但实表只出现 ||，逐段求值即可）
  if (expr.contains('||')) {
    var any = false;
    for (final part in expr.split('||')) {
      final r = evalServiceShowHideExpression(part, valueOf);
      if (r == true) return true;
      if (r == null) return null; // 有未知段则不妄断
    }
    return any;
  }

  String norm(Object? v) {
    if (v == null) return '';
    if (v is DateTime) return v.toIso8601String();
    return v.toString().trim();
  }

  String unquote(String s) {
    final t = s.trim();
    if (t.length >= 2 &&
        ((t.startsWith("'") && t.endsWith("'")) ||
            (t.startsWith('"') && t.endsWith('"')))) {
      return t.substring(1, t.length - 1);
    }
    return t;
  }

  // {p_K}=='' / {p_K}!=''
  var m = RegExp(r"^\{p_([A-Za-z0-9_]+)\}\s*(==|!=)\s*''$").firstMatch(expr);
  if (m != null) {
    final empty = norm(valueOf(m.group(1)!)).isEmpty;
    return m.group(2) == '==' ? empty : !empty;
  }

  // {p_K}.indexOf(v)!==-1 / ==-1
  m = RegExp(
    r'^\{p_([A-Za-z0-9_]+)\}\.indexOf\(([^)]+)\)\s*(!==-1|==-1)$',
  ).firstMatch(expr);
  if (m != null) {
    final v = norm(valueOf(m.group(1)!));
    final needle = unquote(m.group(2)!);
    final hit = needle.isNotEmpty && v.contains(needle);
    return m.group(3) == '!==-1' ? hit : !hit;
  }

  // {p_K}.includes('s')
  m = RegExp(
    r'''^\{p_([A-Za-z0-9_]+)\}\.includes\(([^)]+)\)$''',
  ).firstMatch(expr);
  if (m != null) {
    final v = norm(valueOf(m.group(1)!));
    return v.contains(unquote(m.group(2)!));
  }

  // {p_K}[0].value==v / {p_K}[0]==v（!=同理）
  m = RegExp(
    r'^\{p_([A-Za-z0-9_]+)\}\[0\](?:\.value)?\s*(==|!=)\s*(\S+)$',
  ).firstMatch(expr);
  if (m != null) {
    final v = norm(valueOf(m.group(1)!));
    final target = unquote(m.group(3)!);
    // SelectV2 值在本应用中存为单个 value 字符串；[0] 语义即"所选值"
    final hit = v == target;
    return m.group(2) == '==' ? hit : !hit;
  }

  // new Date({p_K}) <= new Date('yyyy-MM-dd')
  m = RegExp(
    r"^new Date\(\{p_([A-Za-z0-9_]+)\}\)\s*(<=|>=|<|>)\s*new Date\('([^']+)'\)$",
  ).firstMatch(expr);
  if (m != null) {
    final a = _parseServiceDate(valueOf(m.group(1)!));
    final b = _parseServiceDate(m.group(3));
    if (a == null || b == null) return null;
    final cmp = a.compareTo(b);
    return switch (m.group(2)) {
      '<=' => cmp <= 0,
      '>=' => cmp >= 0,
      '<' => cmp < 0,
      '>' => cmp > 0,
      _ => null,
    };
  }

  // {p_K}==v / {p_K}!=v（放最后，避免吞掉上面的形态）
  m = RegExp(r'^\{p_([A-Za-z0-9_]+)\}\s*(==|!=)\s*(\S+)$').firstMatch(expr);
  if (m != null) {
    final v = norm(valueOf(m.group(1)!));
    final target = unquote(m.group(3)!);
    final hit = v == target;
    return m.group(2) == '==' ? hit : !hit;
  }

  return null;
}

// 拆分前与 service_plugin_models.dart 共享同一个私有 helper；两边是
// 各自 library 的同名私有副本，修改时务必同步。
int _toInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

/// 宽松解析服务端日期（'2026-08-10'、'2026-08-10T17:10:21+' 等）。
DateTime? _parseServiceDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  var s = raw.toString().trim();
  if (s.isEmpty) return null;
  // 截断的时区标记（'2026-08-10T17:10:21+'）→ 去掉尾部非日期内容
  final m = RegExp(
    r'^(\d{4}-\d{2}-\d{2})(?:[T ](\d{2}:\d{2}(?::\d{2})?))?',
  ).firstMatch(s);
  if (m == null) return null;
  s = m.group(2) != null ? '${m.group(1)}T${m.group(2)}' : m.group(1)!;
  return DateTime.tryParse(s);
}
