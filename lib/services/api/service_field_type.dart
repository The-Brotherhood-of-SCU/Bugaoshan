/// 办事大厅动态表单字段类型与解析。
///
/// 从 `service_plugin_models.dart` 拆分而来。类型判定规则：
/// - 优先插件声明的组件类型（`type` 字段，如 `dRadio`，大小写不敏感）；
/// - 缺失/不认识时按 key 前缀推断（`Radio_30` → radio）。
library;

/// 字段类型。优先取插件声明的组件类型（`type` 字段，如 dRadio），
/// 缺失时按 key 前缀推断（Radio_30 → radio）。
enum ServiceFieldType {
  input,
  multiInput,
  radio,
  select,

  /// 新下拉组件（dSelectV2）：提交为 [{value, name}] 数组（单选也是数组）。
  selectV2,
  checkbox,
  calendar,
  region,

  /// 附件/图片上传（dFile / dXImage）：提交 [{name, url, id}]。
  file,
  dataSource,
  user,
  showHide,
  variate,
  validate,
  conversion,
  repeatTable,

  /// 静态说明文字（dOneInput，Text_*）。只读展示，不参与填写。
  text,

  /// 静态图片（dImage）。占位不渲染。
  image,

  /// 布局容器（dTable）。占位不渲染。
  table,
  unknown,
}

/// key 前缀 → 类型（key 形如 `Radio_30`，前缀与组件名一一对应）。
const Map<String, ServiceFieldType> _kPrefixTypes = {
  'Input_': ServiceFieldType.input,
  'MultiInput_': ServiceFieldType.multiInput,
  'MultiText_': ServiceFieldType.multiInput,
  'Radio_': ServiceFieldType.radio,
  'Select_': ServiceFieldType.select,
  'SelectV2_': ServiceFieldType.selectV2,
  'Checkbox_': ServiceFieldType.checkbox,
  'Calendar_': ServiceFieldType.calendar,
  'Region_': ServiceFieldType.region,
  'File_': ServiceFieldType.file,
  'Ximage_': ServiceFieldType.file,
  'DataSource_': ServiceFieldType.dataSource,
  'User_': ServiceFieldType.user,
  'ShowHide_': ServiceFieldType.showHide,
  'Variate_': ServiceFieldType.variate,
  'Validate_': ServiceFieldType.validate,
  'Conversion_': ServiceFieldType.conversion,
  'RepeatTable_': ServiceFieldType.repeatTable,
  'Text_': ServiceFieldType.text,
  'Image_': ServiceFieldType.image,
  'Table_': ServiceFieldType.table,
};

/// 组件名（去 `d` 前缀、小写）→ 类型。来自真实抓包的组件清单：
/// dInput/dmultiText/dmultiInputs/dRadio/dSelect/dSelectV2/dCheckbox/
/// dCalendar/dRegion/dFile/dXImage/dDataSource/dUser/dShowHide/dVariate/
/// dValidate/dConversion/dRepeatTable/dOneInput（静态文字）/dImage/dTable。
const Map<String, ServiceFieldType> _kComponentTypes = {
  'input': ServiceFieldType.input,
  'integerinput': ServiceFieldType.input,
  'numericinput': ServiceFieldType.input,
  'phonenumber': ServiceFieldType.input,
  'multitext': ServiceFieldType.multiInput,
  'multiinputs': ServiceFieldType.multiInput,
  'radio': ServiceFieldType.radio,
  'select': ServiceFieldType.select,
  'selectv2': ServiceFieldType.selectV2,
  'checkbox': ServiceFieldType.checkbox,
  'calendar': ServiceFieldType.calendar,
  'region': ServiceFieldType.region,
  'file': ServiceFieldType.file,
  'ximage': ServiceFieldType.file,
  'datasource': ServiceFieldType.dataSource,
  'user': ServiceFieldType.user,
  'showhide': ServiceFieldType.showHide,
  'variate': ServiceFieldType.variate,
  'validate': ServiceFieldType.validate,
  'conversion': ServiceFieldType.conversion,
  'repeattable': ServiceFieldType.repeatTable,
  'oneinput': ServiceFieldType.text,
  'text': ServiceFieldType.text,
  'show': ServiceFieldType.text,
  'image': ServiceFieldType.image,
  'table': ServiceFieldType.table,
};

/// 按 key 前缀推断字段类型（无法推断返回 [ServiceFieldType.unknown]）。
ServiceFieldType serviceFieldTypeFromKey(String key) {
  for (final entry in _kPrefixTypes.entries) {
    if (key.startsWith(entry.key)) return entry.value;
  }
  return ServiceFieldType.unknown;
}

/// 解析字段类型：优先组件声明（如 `dRadio`，大小写不敏感），
/// 缺失/不认识时按 key 前缀推断。
ServiceFieldType resolveServiceFieldType(String? declaredType, String key) {
  if (declaredType != null && declaredType.isNotEmpty) {
    var name = declaredType.trim().toLowerCase();
    // 组件名以 d 开头（dRadio/dmultiText…），去掉后查表
    if (name.startsWith('d') && name.length > 1) {
      name = name.substring(1);
    }
    final t = _kComponentTypes[name];
    if (t != null) return t;
  }
  return serviceFieldTypeFromKey(key);
}
