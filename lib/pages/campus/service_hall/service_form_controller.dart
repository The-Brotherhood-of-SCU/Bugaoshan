/// 办事大厅通用表单控制器（纯逻辑，不依赖 Flutter UI）
///
/// 负责四件事：
/// 1. 条件显示与动态必填——**服务端 ShowHide 插件驱动**（conditions/controls
///    表达式求值，见 [evalServiceShowHideExpression]），每事项
///    [ServiceAppOverrides.visibility] 仅作兜底；
/// 2. 提交前校验（动态必填的可见可编辑字段 + schema 的 Validate 日期顺序
///    规则 + 每事项 [ServiceAppOverrides.extraValidators]）；
/// 3. 组装 `form_data`（[buildFormData]）——类型感知序列化，复现
///    350 已抓包验证的提交结构；
/// 4. DataSource 取数结果分发（resultKey 配对 / setplugin mapConfig 多列）。
library;

import 'package:bugaoshan/services/api/service_api_service.dart'
    show ServiceAttachment;
import 'package:bugaoshan/services/api/service_plugin_models.dart';
import 'package:bugaoshan/widgets/common/service_region_picker.dart';

/// 校验问题类型。
enum ServiceValidationKind { required, custom }

/// 一次校验发现的问题。
class ServiceValidationIssue {
  /// 相关字段 key（自定义校验可为空）。
  final String fieldKey;

  final ServiceValidationKind kind;

  /// 说明文案（Validate 插件的服务端 alert 原样带出；为空时 UI 用 l10n）。
  final String? message;

  const ServiceValidationIssue(this.fieldKey, this.kind, {this.message});

  @override
  String toString() => 'ServiceValidationIssue($fieldKey, $kind, $message)';
}

/// 条件显示规则（**兜底**：仅当服务端 ShowHide 配置未覆盖该字段时使用）。
/// 当 [dependsOnKey] 字段的当前值（radio/select 的 value 字符串）在
/// [visibleWhenValues] 中时字段才显示。
class FieldVisibilityRule {
  final String dependsOnKey;
  final Set<String> visibleWhenValues;

  const FieldVisibilityRule(this.dependsOnKey, this.visibleWhenValues);

  bool isVisible(Object? currentValue) {
    if (currentValue == null) return false;
    return visibleWhenValues.contains(currentValue.toString());
  }
}

/// 每事项的服务端表达不了的覆盖配置。
class ServiceAppOverrides {
  /// 条件显示兜底（key 为被控制字段）。服务端 ShowHide 引擎优先。
  final Map<String, FieldVisibilityRule> visibility;

  /// DataSource → 配对 Input 兜底（正常由插件 attr.data.resultKey 提供）。
  final Map<String, String> dataSourceTargets;

  /// 字段标签兜底（key → 中文标签；服务端插件 description 缺失时使用）。
  final Map<String, String> fieldLabels;

  /// 字段展示顺序（key 列表；未列出的字段按 sort 排在后面）。
  /// 350 的 sort 值异常（Calendar_25=2/Calendar_26=3），用此修正。
  final List<String> fieldOrder;

  /// 附加校验（如 350 的返校时间必须晚于离校时间——服务端没有对应
  /// Validate 规则，保留硬编码）。
  final List<ServiceValidationIssue? Function(ServiceFormController)>
  extraValidators;

  const ServiceAppOverrides({
    this.visibility = const {},
    this.dataSourceTargets = const {},
    this.fieldLabels = const {},
    this.fieldOrder = const [],
    this.extraValidators = const [],
  });
}

/// 表单值（[ServiceFormController.values]）的类型约定：
/// - input / multiInput / dataSource → String
/// - radio / select / selectV2 → String（选项 `value`；selectV2 单选也是单值，
///   提交时包装为 [{value, name}] 数组）
/// - checkbox → `Set<String>`（选项 value 集合）
/// - calendar → DateTime
/// - region → ServiceRegionSelection
/// - file → `List<ServiceAttachment>`（提交前由页面把本地 File 上传后替换）
class ServiceFormController {
  final ServiceFormSchema schema;
  final ServiceAppOverrides overrides;

  /// 字段 key → 当前值（类型见上）。构造时从 schema.data 播种预填。
  final Map<String, Object?> values = {};

  ServiceFormController(
    this.schema, {
    this.overrides = const ServiceAppOverrides(),
  }) {
    _seedFromPrefill();
  }

  /// 从服务端预填播种（calendar 字段的字符串宽容解析为 DateTime）。
  void _seedFromPrefill() {
    for (final e in schema.data.entries) {
      final p = schema.pluginByKey(e.key);
      final v = e.value;
      if (v == null) continue;
      if (p?.type == ServiceFieldType.calendar) {
        final parsed = parseServiceDateTime(v);
        if (parsed != null) values[e.key] = parsed;
      } else if (v is String && v.isEmpty) {
        continue; // 空串预填不播种（如 Calendar_25: ''）
      } else {
        values[e.key] = v;
      }
    }
  }

  /// 提交成功后重置：清空用户输入，重新播种预填。
  void resetToPrefill() {
    values.clear();
    _seedFromPrefill();
  }

  /// 字段标签：优先服务端插件 label，缺失时用 override 兜底，最后回退 key。
  String labelOf(ServiceFormPlugin p) {
    if (p.label.isNotEmpty) return p.label;
    return overrides.fieldLabels[p.key] ?? p.key;
  }

  /// 展示顺序：override 的 fieldOrder 优先，其余按 sort。
  List<ServiceFormPlugin> get displayPlugins {
    final order = overrides.fieldOrder;
    final list = schema.editablePlugins;
    if (order.isEmpty) return list;
    final idx = <String, int>{};
    for (var i = 0; i < order.length; i++) {
      idx[order[i]] = i;
    }
    final sorted = [...list];
    sorted.sort((a, b) {
      final ai = idx[a.key] ?? 0x3fffffff;
      final bi = idx[b.key] ?? 0x3fffffff;
      if (ai != bi) return ai.compareTo(bi);
      return a.sort.compareTo(b.sort);
    });
    return sorted;
  }

  /// 跑一遍 ShowHide 引擎：按条件顺序求值，命中条件的动作按序应用
  /// （后者覆盖前者的同字段设置）。返回 (visibility, required) 两张表。
  (Map<String, bool>, Map<String, bool>) _evalShowHide() {
    final vis = <String, bool>{};
    final req = <String, bool>{};
    for (final p in schema.activeShowHidePlugins) {
      final rule = p.showHideRule!;
      for (var i = 0; i < rule.conditions.length; i++) {
        final hit = evalServiceShowHideExpression(
          rule.conditions[i].expression,
          (k) => values[k],
        );
        if (hit != true) continue;
        final control = rule.controls[i.toString()];
        if (control == null) continue;
        for (final t in control.targets) {
          if (control.isShow != null) vis[t] = control.isShow!;
          if (control.isRequired != null) req[t] = control.isRequired!;
        }
      }
    }
    return (vis, req);
  }

  /// 字段当前是否显示（ShowHide 引擎 → override 兜底 → 恒显示）。
  bool isFieldVisible(ServiceFormPlugin p) {
    final (vis, _) = _evalShowHide();
    final dyn = vis[p.key];
    if (dyn != null) return dyn;
    final rule = overrides.visibility[p.key];
    if (rule == null) return true;
    return rule.isVisible(values[rule.dependsOnKey]);
  }

  /// 字段当前是否必填（ShowHide 引擎 → auth require）。
  bool isFieldRequired(String fieldKey) {
    final (_, req) = _evalShowHide();
    final dyn = req[fieldKey];
    if (dyn != null) return dyn;
    return schema.isRequired(fieldKey);
  }

  /// 提交前校验。返回 null 表示通过。
  ///
  /// 规则：每个**可见**的可编辑字段若当前必填则按类型判空；
  /// 之后跑 schema 的日期顺序规则（Validate 插件解析）与
  /// [ServiceAppOverrides.extraValidators]。
  ServiceValidationIssue? validate() {
    for (final p in schema.editablePlugins) {
      if (!isFieldRequired(p.key)) continue;
      if (!isFieldVisible(p)) continue;
      if (_isEmptyValue(p, values[p.key])) {
        return ServiceValidationIssue(p.key, ServiceValidationKind.required);
      }
    }
    for (final rule in schema.dateOrderRules) {
      final a = values[rule.firstKey];
      final b = values[rule.secondKey];
      if (a is DateTime && b is DateTime && a.isAfter(b)) {
        return ServiceValidationIssue(
          rule.secondKey,
          ServiceValidationKind.custom,
          message: rule.message,
        );
      }
    }
    for (final v in overrides.extraValidators) {
      final issue = v(this);
      if (issue != null) return issue;
    }
    return null;
  }

  bool _isEmptyValue(ServiceFormPlugin p, Object? v) {
    return switch (p.type) {
      ServiceFieldType.radio ||
      ServiceFieldType.select ||
      ServiceFieldType.selectV2 => v == null || v.toString().isEmpty,
      ServiceFieldType.checkbox => v == null || (v as Set).isEmpty,
      ServiceFieldType.input ||
      ServiceFieldType.multiInput ||
      ServiceFieldType.dataSource => v == null || v.toString().trim().isEmpty,
      ServiceFieldType.region =>
        v == null || (v as ServiceRegionSelection).isEmpty,
      ServiceFieldType.file => v == null || (v as List).isEmpty,
      ServiceFieldType.calendar => v == null,
      _ => v == null,
    };
  }

  bool _hasValue(ServiceFormPlugin p, Object? v) => !_isEmptyValue(p, v);

  /// DataSource 取数结果分发（页面在取数成功后调用）：
  /// - resultKey 为 `setplugin`：按 mapConfig 把 list 对象的列分发到目标字段
  ///   （calendar 目标宽容解析日期）；
  /// - 否则：name 写入本字段与 resultKey 配对字段（front_readonly 展示用）。
  void applyDataSourceValue(ServiceFormPlugin p, Object? listValue) {
    final ref = p.dataSource;
    if (ref == null) return;
    if (ref.isSetPlugin) {
      if (listValue is Map) {
        for (final e in ref.mapConfig.entries) {
          final raw = listValue[e.value];
          if (raw == null || raw.toString().isEmpty) continue;
          final target = schema.pluginByKey(e.key);
          if (target?.type == ServiceFieldType.calendar) {
            final parsed = parseServiceDateTime(raw);
            if (parsed != null) values[e.key] = parsed;
          } else {
            values[e.key] = raw.toString();
          }
        }
      }
      return;
    }
    final name = listValue?.toString() ?? '';
    if (name.isEmpty) return;
    values[p.key] = name;
    final target = ref.resultKey.isNotEmpty
        ? ref.resultKey
        : overrides.dataSourceTargets[p.key];
    if (target != null && target.isNotEmpty) {
      values[target] = name;
    }
  }

  /// 组装单个表单的字段 Map（不含外层 formId 包装）。
  ///
  /// 规则（复现 350 已验证 payload + 337/356/357 真实 auth 校准）：
  /// 1. 占位类型（ShowHide/Variate/Validate/Text/Image/Table）→ `''`/`[]`；
  /// 2. DataSource：有值 → `{list: name}` + resultKey 配对 Input；空 → 整对省略
  ///    （350 已验证行为）；
  /// 3. 只读/隐藏/User：有值 → 类型感知序列化（预填/取数结果透传），
  ///    空 → `''`（孤儿 auth key 无插件，直接占位兜底）；
  /// 4. 可编辑：可见 → 类型感知序列化；被条件隐藏 → 空值（350 已验证：
  ///    未选"其它"时 MultiInput_40 为 `''`）；数组型（selectV2/checkbox/file）
  ///    隐藏/占位给 `[]`。
  Map<String, dynamic> buildFormFields() {
    final result = <String, dynamic>{};
    final omitted = <String>{};

    for (final key in schema.auth.keys) {
      final p = schema.pluginByKey(key);
      final type = p?.type ?? serviceFieldTypeFromKey(key);
      final v = values[key];

      if (ServiceFormSchema.placeholderTypes.contains(type)) {
        result[key] = ServiceFormSchema.placeholderValueFor(type);
        continue;
      }

      if (type == ServiceFieldType.dataSource) {
        final name = v?.toString() ?? '';
        if (name.isNotEmpty) {
          result[key] = {'list': name};
          final ref = p?.dataSource;
          final target = ref != null && ref.resultKey.isNotEmpty
              ? ref.resultKey
              : overrides.dataSourceTargets[key];
          if (target != null && target.isNotEmpty && !ref!.isSetPlugin) {
            result[target] = name;
          }
        } else {
          // 取数为空：整对省略（350 已验证）
          omitted.add(key);
          final ref = p?.dataSource;
          final target = ref != null && ref.resultKey.isNotEmpty
              ? ref.resultKey
              : overrides.dataSourceTargets[key];
          if (target != null && target.isNotEmpty) omitted.add(target);
        }
        continue;
      }

      if (p == null) {
        // 孤儿 auth key（插件已删/未下发）按前缀规则占位兜底
        result[key] = ServiceFormSchema.placeholderValueFor(type);
        continue;
      }

      if (schema.isReadOnly(key) ||
          schema.isSuppressed(key) ||
          type == ServiceFieldType.user) {
        result[key] = _hasValue(p, v)
            ? serializeServiceFieldValue(p, v)
            : ServiceFormSchema.placeholderValueFor(type);
        continue;
      }

      if (!isFieldVisible(p)) {
        result[key] = ServiceFormSchema.placeholderValueFor(type);
        continue;
      }
      result[key] = serializeServiceFieldValue(p, v);
    }

    result.removeWhere((k, _) => omitted.contains(k));
    return result;
  }

  /// 完整 `form_data`（外层以 formId 包装）。
  Map<String, dynamic> buildFormData() => {schema.formId: buildFormFields()};
}

/// 宽容解析服务端日期（公开供 controller/页面使用）：
/// '2026-08-10'、'2026-08-10T17:10:21+'（截断时区）等。
DateTime? parseServiceDateTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  var s = raw.toString().trim();
  if (s.isEmpty) return null;
  final m = RegExp(
    r'^(\d{4}-\d{2}-\d{2})(?:[T ](\d{2}:\d{2}(?::\d{2})?))?',
  ).firstMatch(s);
  if (m == null) return null;
  s = m.group(2) != null ? '${m.group(1)}T${m.group(2)}' : m.group(1)!;
  return DateTime.tryParse(s);
}

/// 类型感知序列化（公开纯函数便于单测）。
///
/// - radio/select → `{"value": v, "name": <选项 label>}`（350 抓包确认）
/// - selectV2/checkbox → `[{"value","name"}, ...]`（前端 setComPluginData 确认：
///   dSelectV2/dCheckbox 一律数组，单选也是单元素数组）
/// - calendar → UTC ISO 8601
/// - region → [ServiceRegionSelection.toRegionData]
/// - file（含 dXImage）→ `[{name,url,id}]`（空值给 `[]`）
/// - dataSource → `{"list": name}`（空值给 `''`）
/// - input/multiInput/user → 字符串
/// - 空值统一给 `''`（数组型给 `[]`）
Object? serializeServiceFieldValue(ServiceFormPlugin p, Object? value) {
  String optionName(String v) {
    for (final o in p.options) {
      if (o.value == v) return o.label;
    }
    return '';
  }

  switch (p.type) {
    case ServiceFieldType.radio:
    case ServiceFieldType.select:
      final v = value?.toString() ?? '';
      if (v.isEmpty) return '';
      return {'value': v, 'name': optionName(v)};
    case ServiceFieldType.selectV2:
      final v = value?.toString() ?? '';
      if (v.isEmpty) return const <dynamic>[];
      return [
        {'value': v, 'name': optionName(v)},
      ];
    case ServiceFieldType.checkbox:
      final selected = value is Set ? value : const <dynamic>{};
      return [
        for (final v in selected) {'value': '$v', 'name': optionName('$v')},
      ];
    case ServiceFieldType.calendar:
      if (value is! DateTime) return '';
      return value.toUtc().toIso8601String();
    case ServiceFieldType.region:
      if (value is! ServiceRegionSelection || value.isEmpty) return '';
      return value.toRegionData();
    case ServiceFieldType.file:
      if (value is! List) return const <dynamic>[];
      return [
        for (final a in value)
          if (a is ServiceAttachment) a.toFormData(),
      ];
    case ServiceFieldType.dataSource:
      final name = value?.toString() ?? '';
      return name.isEmpty ? '' : {'list': name};
    case ServiceFieldType.input:
    case ServiceFieldType.multiInput:
    case ServiceFieldType.user:
      return value?.toString() ?? '';
    default:
      return value?.toString() ?? '';
  }
}
