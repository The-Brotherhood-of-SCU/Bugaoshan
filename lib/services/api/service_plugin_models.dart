/// 办事大厅动态表单插件模型（汇总出口）。
///
/// 结构来自对真实接口的抓包校准（test/fixtures/service_capture*.json）：
/// - `/site/process/start-info` 的 `d.form[]` 只有 form_id/version/name/version_id，
///   **不含插件定义**；`d.bpmn_id` 在顶层；
/// - 插件定义来自 `/site/form/get-formv?id=<currform>&bpmn_id=<bpmn>`，其 `d` 为
///   `{id, form_version_id, plugins: "<JSON 字符串>", table: "<JSON 字符串>"}`，
///   plugins 解码后为 `{nowNum, plugins: {<key>: <plugin>}, rtplugins}`；
/// - 字段权限（require/writable/readable/front_readonly/hidden/forbidden）与
///   预填值来自 `/site/form/start-data`（见 [ServiceFormDefinition]），两者在此
///   合并为可直接渲染的 [ServiceFormSchema]。
///
/// **所有解析均做多候选容错**：任一环节不符合预期时抛 [FormatException]，
/// 由调用方走 fallback（350 有硬编码元数据兜底；其他事项失败封闭，
/// 绝不渲染猜测的表单）。
///
/// 实现按职责拆分：
/// - `service_field_type.dart` — 字段类型枚举 + 类型推断/解析
/// - `service_showhide_rule.dart` — ShowHide 规则 + 表达式求值
/// - 本文件保留 DataSource / 日期顺序 / 插件 / schema
library;

import 'dart:convert';

import 'package:bugaoshan/services/api/service_field_type.dart';
import 'package:bugaoshan/services/api/service_form_fields.dart'
    show ServiceFieldOption;
import 'package:bugaoshan/services/api/service_form_models.dart';
import 'package:bugaoshan/services/api/service_showhide_rule.dart';

export 'package:bugaoshan/services/api/service_field_type.dart'
    show ServiceFieldType, serviceFieldTypeFromKey, resolveServiceFieldType;
export 'package:bugaoshan/services/api/service_showhide_rule.dart'
    show
        ServiceShowHideCondition,
        ServiceShowHideControl,
        ServiceShowHideRule,
        evalServiceShowHideExpression;

/// DataSource 字段的取数配置（`POST /site/data-source/detail`）。
///
/// 全部来自插件自身配置（`attr.data.sourceid` / `attr.data.resultKey` /
/// `attr.data.mapConfig`），绝不按事项硬编码。
/// 350 的辅导员对应 sourceid=8、form_version_id=2357、resultKey=Input_84。
class ServiceDataSourceRef {
  /// 数据源 id（插件 `attr.data.sourceid`）。
  final String id;

  /// 表单版本 id（form 的 `version_id`，如 2357）。
  final String formVersionId;

  /// 组件 key（插件 key，如 DataSource_85）。
  final String component;

  /// 所属表单 id（如 1419）。
  final String formId;

  /// 结果映射目标（`attr.data.resultKey`）：
  /// - 普通值（如 Input_84）：取数结果同时写入该字段（front_readonly 配对展示）；
  /// - 特殊值 `setplugin`：按 [mapConfig] 把结果对象的列分发到多个字段
  ///   （如 337 的 DataSource_163：grade→User_156、back_date→Input_162）。
  final String resultKey;

  /// setplugin 模式的列映射：目标字段 key → 结果对象列名。
  final Map<String, String> mapConfig;

  /// 附加 configure 参数（插件 `attr.data.sourceConfig`，key → value 字符串）。
  final Map<String, String> configure;

  const ServiceDataSourceRef({
    required this.id,
    required this.formVersionId,
    required this.component,
    required this.formId,
    this.resultKey = '',
    this.mapConfig = const {},
    this.configure = const {},
  });

  /// 是否 setplugin 分发模式。
  bool get isSetPlugin => resultKey == 'setplugin';

  @override
  String toString() =>
      'ServiceDataSourceRef(id=$id, formVersionId=$formVersionId, '
      'component=$component, formId=$formId, resultKey=$resultKey)';
}

/// Validate 插件解析出的日期顺序校验（`attr.data.rule`）。
///
/// 已确认的形态：`{f_dateDayMinus}({p_A},{p_B})<0`，`alert` 为提示文案。
/// 前端语义（对照 356/357 实表）：A 早于等于 B 为合法，否则提示 alert。
/// （dateDayMinus(A,B) 实际为 B-A；规则在 A>B 时成立即拦截。）
class ServiceDateOrderRule {
  /// 较早日期字段（如 离校日期 Calendar_34）。
  final String firstKey;

  /// 较晚日期字段（如 预计返校 Calendar_61）。
  final String secondKey;

  /// 服务端给出的提示文案（原样展示，可能措辞不严谨）。
  final String message;

  const ServiceDateOrderRule({
    required this.firstKey,
    required this.secondKey,
    required this.message,
  });

  static final _pattern = RegExp(
    r'^\s*\{f_dateDayMinus\}\(\s*\{p_([A-Za-z0-9_]+)\}\s*,\s*\{p_([A-Za-z0-9_]+)\}\s*\)\s*<\s*0\s*$',
  );

  /// 从 Validate 插件的 rule/alert 解析；不是已确认形态时返回 null。
  static ServiceDateOrderRule? tryParse(dynamic rule, dynamic alert) {
    if (rule is! String || rule.isEmpty) return null;
    final m = _pattern.firstMatch(rule);
    if (m == null) return null;
    return ServiceDateOrderRule(
      firstKey: m.group(1)!,
      secondKey: m.group(2)!,
      message: alert is String ? alert : '',
    );
  }
}

String? _firstString(Map<dynamic, dynamic> map, List<String> keys) {
  for (final k in keys) {
    final v = map[k];
    if (v is String && v.isNotEmpty) return v;
    if (v is num) return v.toString();
  }
  return null;
}

// 拆分前与 service_showhide_rule.dart 共享同一个私有 helper；两边是
// 各自 library 的同名私有副本，修改时务必同步。
int _toInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

/// 单个表单字段（插件）。
class ServiceFormPlugin {
  /// 字段 key（如 Radio_30）。
  final String key;

  /// 字段类型（组件声明或 key 前缀推断）。
  final ServiceFieldType type;

  /// 服务端下发的字段标签（插件顶层 `description`，如 '离开校区'）。
  final String label;

  /// 排序值（同一 form 内大致递增；350 个别字段异常由 per-app fieldOrder 修正）。
  final int sort;

  /// Radio/Select/SelectV2/Checkbox 的选项（`attr.data.options`，
  /// 元素 {value, name, default}）。
  final List<ServiceFieldOption> options;

  /// 占位提示（`attr.data.placeholder`）。
  final String? hint;

  /// 附件数量上限（`attr.data.maxNum`，数字或字符串；0/缺省 → 3）。
  final int maxCount;

  /// DataSource 字段的取数配置（type == dataSource 时非空）。
  final ServiceDataSourceRef? dataSource;

  /// Validate 插件的日期顺序校验（type == validate 且 rule 匹配时非空）。
  final ServiceDateOrderRule? dateOrderRule;

  /// ShowHide 插件的显隐规则（type == showHide 且解析成功时非空）。
  final ServiceShowHideRule? showHideRule;

  /// `attr.data` 原始配置（调试用）。
  final Map<String, dynamic> raw;

  const ServiceFormPlugin({
    required this.key,
    required this.type,
    this.label = '',
    this.sort = 0,
    this.options = const [],
    this.hint,
    this.maxCount = 3,
    this.dataSource,
    this.dateOrderRule,
    this.showHideRule,
    this.raw = const {},
  });

  /// 从单个插件 JSON 解析（get-formv 的 plugins map entry）。
  ///
  /// [fallbackKey] 为 Map 外层 key（真实数据中插件自身也带 key，外层 key 兜底）。
  /// 解析不出 key 时抛 [FormatException]。
  factory ServiceFormPlugin.fromJson(
    Map<String, dynamic> json, {
    required String formId,
    String formVersionId = '',
    String? fallbackKey,
  }) {
    final key =
        _firstString(json, const ['key', 'dataid', 'id']) ?? fallbackKey;
    if (key == null || key.isEmpty) {
      throw FormatException('插件缺少 key: $json');
    }

    // attr 可能是字符串（二次编码）或对象
    var attr = json['attr'];
    if (attr is String) {
      try {
        attr = jsonDecode(attr);
      } catch (_) {
        attr = null;
      }
    }
    final attrMap = attr is Map ? attr : const {};
    var attrData = attrMap['data'];
    if (attrData is String) {
      try {
        attrData = jsonDecode(attrData);
      } catch (_) {
        attrData = null;
      }
    }
    final data = attrData is Map
        ? Map<String, dynamic>.from(attrData)
        : <String, dynamic>{};

    final declaredType = _firstString(json, const ['type', 'component']);
    final type = resolveServiceFieldType(declaredType, key);

    // 标签：真实数据在顶层 description（如 '离开校区' / '学号'）；
    // attr.data.name 是绑定表达式名（如 '发起者.学工号'），仅作兜底
    final label =
        _firstString(json, const ['description', 'label', 'title']) ??
        _firstString(data, const ['label', 'title', 'name']) ??
        '';

    final sort = _toInt(json['sort'] ?? data['sort']);

    final options = _parseOptions(data);

    final hint = _firstString(data, const ['placeholder', 'hint', 'tip']);

    // maxNum 可能是数字（350 File_71: 0）或字符串（357 Ximage_64: "100"）；
    // 0/非法 → 默认 3。注意不要用 limitval（那是 Region 的层级深度）。
    final maxCount = _toInt(data['maxNum'] ?? data['maxCount'], fallback: 0);

    ServiceDataSourceRef? dsRef;
    if (type == ServiceFieldType.dataSource) {
      final sourceId =
          _firstString(data, const [
            'sourceid',
            'source_id',
            'data_source_id',
            'dataSourceId',
          ]) ??
          '';
      if (sourceId.isNotEmpty) {
        dsRef = ServiceDataSourceRef(
          id: sourceId,
          formVersionId: formVersionId,
          component: key,
          formId: formId,
          resultKey: _firstString(data, const ['resultKey']) ?? '',
          mapConfig: _parseMapConfig(data['mapConfig']),
          configure: _parseSourceConfig(data['sourceConfig']),
        );
      }
    }

    ServiceDateOrderRule? dateOrderRule;
    if (type == ServiceFieldType.validate) {
      dateOrderRule = ServiceDateOrderRule.tryParse(
        data['rule'],
        data['alert'],
      );
    }

    ServiceShowHideRule? showHideRule;
    if (type == ServiceFieldType.showHide) {
      showHideRule = ServiceShowHideRule.tryParse(data);
    }

    return ServiceFormPlugin(
      key: key,
      type: type,
      label: label,
      sort: sort,
      options: options,
      hint: hint,
      maxCount: maxCount > 0 ? maxCount : 3,
      dataSource: dsRef,
      dateOrderRule: dateOrderRule,
      showHideRule: showHideRule,
      raw: data,
    );
  }

  static List<ServiceFieldOption> _parseOptions(Map<String, dynamic> data) {
    for (final k in const ['options', 'items', 'list', 'option']) {
      final raw = data[k];
      if (raw is! List) continue;
      final result = <ServiceFieldOption>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final label = _firstString(item, const ['name', 'label', 'title']);
        final value = _firstString(item, const ['value', 'id']);
        if (label != null && value != null) {
          result.add(ServiceFieldOption(value, label));
        }
      }
      if (result.isNotEmpty) return result;
    }
    return const [];
  }

  /// mapConfig 真实形态为 Map（{User_156: {key: "grade"}}），
  /// 也可能是空 List（[]）——按空处理。
  static Map<String, String> _parseMapConfig(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final v = entry.value;
      if (v is Map && v['key'] != null) {
        result[entry.key.toString()] = v['key'].toString();
      }
    }
    return result;
  }

  static Map<String, String> _parseSourceConfig(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final v = entry.value;
      // sourceConfig 结构为 {key: {value: ...}}
      if (v is Map && v['value'] != null) {
        result[entry.key.toString()] = v['value'].toString();
      } else if (v != null) {
        result[entry.key.toString()] = v.toString();
      }
    }
    return result;
  }

  @override
  String toString() =>
      'ServiceFormPlugin(key=$key, type=$type, label=$label, sort=$sort)';
}

/// 完整可渲染 schema = get-formv 插件定义 + start-data 权限/预填。
class ServiceFormSchema {
  /// 事项 id（如 '350'）。
  final String appId;

  /// 当前生效的表单 id（get-formv 的 `d.id`，如 '1419'）。
  final String formId;

  /// 表单版本 id（get-formv 的 `d.form_version_id`，如 '2357'）。
  final String formVersionId;

  /// 全部插件（sort 升序）。
  final List<ServiceFormPlugin> plugins;

  /// 字段 key → 权限（require/writable/readable/front_readonly/hidden/forbidden）。
  final Map<String, String> auth;

  /// 字段 key → 服务端预填值（学号/姓名等）。
  final Map<String, dynamic> data;

  const ServiceFormSchema({
    required this.appId,
    required this.formId,
    this.formVersionId = '',
    required this.plugins,
    required this.auth,
    required this.data,
  });

  /// 占位类型：不渲染、提交时按规则给 `''` 或 `[]`（复现已验证的 350 行为：
  /// Variate_75/ShowHide_44/ShowHide_83/Validate_86 提交 `''`，
  /// Conversion_74/RepeatTable_76 提交 `[]`）。
  static const Set<ServiceFieldType> placeholderTypes = {
    ServiceFieldType.showHide,
    ServiceFieldType.variate,
    ServiceFieldType.validate,
    ServiceFieldType.conversion,
    ServiceFieldType.repeatTable,
    ServiceFieldType.text,
    ServiceFieldType.image,
    ServiceFieldType.table,
    ServiceFieldType.unknown,
  };

  /// 占位字段提交空值（标量 `''`、数组型 `[]`；`''`/`[]` 选择复现 350 已验证
  /// 规则，数组型集合与前端 setComPluginData 的类型约定一致）。
  static dynamic placeholderValueFor(ServiceFieldType type) {
    return switch (type) {
      ServiceFieldType.conversion ||
      ServiceFieldType.repeatTable ||
      ServiceFieldType.selectV2 ||
      ServiceFieldType.checkbox ||
      ServiceFieldType.file => const <dynamic>[],
      _ => '',
    };
  }

  /// 字段是否必填（auth 为 require；ShowHide 动态必填见 controller）。
  bool isRequired(String fieldKey) => auth[fieldKey] == 'require';

  /// 字段是否只读（readable/front_readonly/readonly）。
  bool isReadOnly(String fieldKey) {
    final a = auth[fieldKey];
    return a == 'readable' || a == 'front_readonly' || a == 'readonly';
  }

  /// 字段是否被隐藏/禁用（auth 为 hidden/forbidden）：不渲染，
  /// 提交时按占位规则给空值（DataSource 写入的值除外）。
  bool isSuppressed(String fieldKey) {
    final a = auth[fieldKey];
    return a == 'hidden' || a == 'forbidden';
  }

  /// 需要用户填写的字段（非占位、非只读、非隐藏、非自动取数类）。
  List<ServiceFormPlugin> get editablePlugins => plugins
      .where(
        (p) =>
            !placeholderTypes.contains(p.type) &&
            p.type != ServiceFieldType.user &&
            p.type != ServiceFieldType.dataSource &&
            !isReadOnly(p.key) &&
            !isSuppressed(p.key),
      )
      .toList(growable: false);

  /// 只读展示字段：User 类（身份预填）或只读且有预填值的字段。
  List<ServiceFormPlugin> get readonlyInfoPlugins => plugins
      .where(
        (p) =>
            (p.type == ServiceFieldType.user || isReadOnly(p.key)) &&
            !isSuppressed(p.key) &&
            data[p.key] != null &&
            data[p.key].toString().isNotEmpty,
      )
      .toList(growable: false);

  /// DataSource 字段（需取数，如辅导员）。
  List<ServiceFormPlugin> get dataSourcePlugins => plugins
      .where(
        (p) => p.type == ServiceFieldType.dataSource && p.dataSource != null,
      )
      .toList(growable: false);

  /// 可应用的 ShowHide 规则（writable 的才作用于发起节点；
  /// readable 的是审批侧规则，如 350 的 ShowHide_68 / 357 的 ShowHide_46）。
  List<ServiceFormPlugin> get activeShowHidePlugins => plugins
      .where(
        (p) =>
            p.type == ServiceFieldType.showHide &&
            p.showHideRule != null &&
            !isReadOnly(p.key) &&
            !isSuppressed(p.key),
      )
      .toList(growable: false);

  /// Validate 插件解析出的日期顺序校验列表。
  List<ServiceDateOrderRule> get dateOrderRules => [
    for (final p in plugins)
      if (p.dateOrderRule != null) p.dateOrderRule!,
  ];

  /// schema 是否可渲染（至少一个可编辑字段）。否则调用方应走 fallback。
  bool get isRenderable => editablePlugins.isNotEmpty;

  /// 按 key 查插件。
  ServiceFormPlugin? pluginByKey(String key) {
    for (final p in plugins) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// 从 get-formv 的 `d` 字段与 start-data 的 [ServiceFormDefinition] 合并
  /// 构建 schema。
  ///
  /// - `d.plugins` 为 JSON 字符串（二次编码），解码后为
  ///   `{nowNum, plugins: {<key>: <plugin>}, rtplugins}`；
  /// - `d.id` / `d.form_version_id` 给出表单与版本；
  /// - 解析失败、无插件时抛 [FormatException]，由调用方走 fallback。
  factory ServiceFormSchema.build({
    required String appId,
    required Map<String, dynamic> formvD,
    required ServiceFormDefinition startData,
  }) {
    final formId =
        _firstString(formvD, const ['id', 'form_id', 'formId']) ??
        (startData.currform.isNotEmpty
            ? startData.currform.first.toString()
            : '');
    final formVersionId =
        _firstString(formvD, const [
          'form_version_id',
          'version_id',
          'formVersionId',
        ]) ??
        '';

    final allPlugins = _parseFormPlugins(
      formvD,
      formId: formId,
      formVersionId: formVersionId,
    );
    if (allPlugins.isEmpty) {
      throw const FormatException('get-formv 无可解析插件');
    }
    allPlugins.sort((a, b) => a.sort.compareTo(b.sort));

    return ServiceFormSchema(
      appId: appId,
      formId: formId,
      formVersionId: formVersionId,
      plugins: allPlugins,
      auth: startData.auth,
      data: startData.data,
    );
  }

  static List<ServiceFormPlugin> _parseFormPlugins(
    Map<String, dynamic> formvD, {
    required String formId,
    required String formVersionId,
  }) {
    var pluginsRaw = formvD['plugins'];
    if (pluginsRaw is String) {
      pluginsRaw = jsonDecode(pluginsRaw);
    }
    // 结构：{nowNum, plugins: {K: P}}（真实）；容错 {plugins: [...]} / 直接 List/Map
    if (pluginsRaw is Map && pluginsRaw['plugins'] != null) {
      pluginsRaw = pluginsRaw['plugins'];
    }
    final entries = <(String?, Map<String, dynamic>)>[];
    if (pluginsRaw is List) {
      for (final item in pluginsRaw) {
        if (item is Map) {
          entries.add((null, Map<String, dynamic>.from(item)));
        }
      }
    } else if (pluginsRaw is Map) {
      for (final entry in pluginsRaw.entries) {
        if (entry.value is Map) {
          entries.add((
            entry.key.toString(),
            Map<String, dynamic>.from(entry.value as Map),
          ));
        }
      }
    }
    final result = <ServiceFormPlugin>[];
    for (final (fallbackKey, json) in entries) {
      result.add(
        ServiceFormPlugin.fromJson(
          json,
          formId: formId,
          formVersionId: formVersionId,
          fallbackKey: fallbackKey,
        ),
      );
    }
    return result;
  }

  @override
  String toString() =>
      'ServiceFormSchema(appId=$appId, formId=$formId, '
      'formVersionId=$formVersionId, plugins=${plugins.length})';
}
