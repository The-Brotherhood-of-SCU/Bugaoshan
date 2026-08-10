import 'package:flutter/material.dart';
import 'package:bugaoshan/theme_shape.dart';

/// 地区节点（省/市/区县），对应办事大厅 dRegion 组件的节点结构。
class ServiceRegionNode {
  final String label;
  final String value;
  final List<ServiceRegionNode> children;

  /// 原始 children 是否为 List（而非 dict）。
  ///
  /// 用于可靠区分直辖市和普通省：
  /// - 直辖市（北京/上海/天津/重庆）：省.children 是 **list**（区）
  /// - 在线接口普通省（河北/广东…）：省.children 是 **dict**（市，key 为序号）
  /// - 本地 modood 普通省：省.children 是 **list**（市，市有 children）
  /// - 香港/澳门/台湾：省无 children 或为 dict
  ///
  /// 只靠"children 是否全无下级"无法区分——普通省可能混入直筒子市
  /// （如广东的东莞/中山无区），导致误判为直辖市。
  final bool childrenIsList;

  const ServiceRegionNode({
    required this.label,
    required this.value,
    this.children = const [],
    this.childrenIsList = false,
  });

  bool get hasChildren => children.isNotEmpty;

  /// 是否为直辖市（省的直接 children 是区，无"市"这一级）。
  ///
  /// 判断依据：children 是 list 且所有元素（区）都没有下级。
  /// - 北京（list 区）：true
  /// - 广东（dict 市，即使混入东莞直筒子市）：false
  /// - 本地 modood 省（list 市，市有区）：false
  /// - 香港（无 children）：false
  bool get isMunicipality {
    if (!childrenIsList || children.isEmpty) return false;
    return !children.every((c) => c.hasChildren);
  }

  /// 完整保留树结构（不按 depth 截断）。
  ///
  /// 数据结构可能为：
  /// - 在线接口普通省：省 → children(dict 市) → children(list 区)（三级）
  /// - 在线接口直辖市：省 → children(list 区)（两级，无市）
  /// - 本地 modood（已剥离街道级）：省 → 市 → 区（三级，街道由用户手填详细地址）
  /// - 香港/澳门：省无 children（Region_80 选到省即可）
  /// - 直筒子市（东莞/中山/济源）：市无 children
  ///
  /// children 兼容 list 和 dict 两种形式。完整解析，由 picker 根据
  /// `childrenIsList` 与 children 内容自适应，避免 depth 截断破坏判断。
  factory ServiceRegionNode.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    return ServiceRegionNode(
      // region_data.json（modood pcas-code）字段名为 code/name；
      // 在线接口 /api/dictionary/province 字段名为 value/label。
      label: (json['name'] ?? json['label'] ?? '').toString(),
      value: normalizeRegionCode(
        (json['code'] ?? json['value'] ?? '').toString(),
      ),
      children: _parseChildren(rawChildren),
      childrenIsList: rawChildren is List,
    );
  }

  /// 解析 children：支持 list（`[{...}]`）和 dict（`{"1": {...}, "2": {...}}`）。
  ///
  /// 注意：不要用 `whereType<Map<String, dynamic>>()`——dart:convert 解码出的
  /// `_Map` 是 `Map<String, dynamic>` 的实现，但 `whereType` 的泛型运行时检查
  /// 在某些 Dart 版本/平台下不可靠，可能导致 children 被静默丢弃，进而让
  /// `isMunicipality` 误判。这里改用显式的 `is Map` + `cast`。
  static List<ServiceRegionNode> _parseChildren(dynamic raw) {
    if (raw is List) {
      return raw
          // ignore: prefer_iterable_wheretype
          .where((e) => e is Map)
          .map((e) => ServiceRegionNode.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }
    if (raw is Map) {
      return raw.values
          // ignore: prefer_iterable_wheretype
          .where((e) => e is Map)
          .map((e) => ServiceRegionNode.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }
    return const [];
  }
}

/// 将行政区划代码补全为 6 位（办事大厅 Region_80 的 value 格式）。
///
/// 本地数据库（modood 行政区划库）使用 2/4/6 位变长码：
/// - 省级 `11` → `110000`
/// - 市级 `1101` → `110100`
/// - 区级 `110101` 保持
/// 办事大厅抓包中 value 为 6 位完整区划代码（如 `440111`）。
String normalizeRegionCode(String code) {
  final trimmed = code.trim();
  if (trimmed.length >= 6) return trimmed;
  return trimmed.padRight(6, '0');
}

/// 已选地区。
class ServiceRegionSelection {
  final ServiceRegionNode? province;
  final ServiceRegionNode? city;
  final ServiceRegionNode? area;
  final String details;

  const ServiceRegionSelection({
    this.province,
    this.city,
    this.area,
    this.details = '',
  });

  bool get isEmpty =>
      province == null && city == null && area == null && details.isEmpty;

  /// 组装成办事大厅 Region_80 的提交结构。
  Map<String, dynamic> toRegionData() {
    final p = province?.label ?? '';
    final c = city?.label ?? '';
    final a = area?.label ?? '';
    final d = details.trim();
    return {
      'province': {'label': p, 'value': province?.value ?? ''},
      'city': {'label': c, 'value': city?.value ?? ''},
      'area': {'label': a, 'value': area?.value ?? ''},
      'details': d,
      'address': [
        if (p.isNotEmpty) p,
        if (c.isNotEmpty) c,
        if (a.isNotEmpty) a,
        if (d.isNotEmpty) d,
      ].join('/'),
    };
  }

  String get displayText {
    final parts = <String>[
      if (province != null) province!.label,
      if (city != null) city!.label,
      if (area != null) area!.label,
      if (details.isNotEmpty) details,
    ];
    return parts.join('/');
  }
}

/// 省市区三级级联选择器文案（可本地化）。
class ServiceRegionLabels {
  final String province;
  final String city;
  final String area;
  final String selectHint;
  final String detailHint;
  final String pickProvince;
  final String pickCity;
  final String pickArea;

  const ServiceRegionLabels({
    this.province = '省',
    this.city = '市',
    this.area = '区县',
    this.selectHint = '请选择',
    this.detailHint = '详细地址（街道、门牌号等）',
    this.pickProvince = '选择省份',
    this.pickCity = '选择城市',
    this.pickArea = '选择区县',
  });
}

/// 省市区三级级联选择器。
///
/// 数据由外部传入（[provinces]，本地内置行政区划数据库）。
/// 用户逐级选择省 → 市 → 区县，并填写详细地址。
/// 文案可用 [labels] 本地化，默认中文。
class ServiceRegionPicker extends StatefulWidget {
  const ServiceRegionPicker({
    super.key,
    required this.provinces,
    this.initial,
    this.onChanged,
    this.labels = const ServiceRegionLabels(),
  });

  final List<ServiceRegionNode> provinces;
  final ServiceRegionSelection? initial;
  final ValueChanged<ServiceRegionSelection>? onChanged;
  final ServiceRegionLabels labels;

  @override
  State<ServiceRegionPicker> createState() => _ServiceRegionPickerState();
}

class _ServiceRegionPickerState extends State<ServiceRegionPicker> {
  late final TextEditingController _detailsController;
  ServiceRegionNode? _province;
  ServiceRegionNode? _city;
  ServiceRegionNode? _area;

  @override
  void initState() {
    super.initState();
    _province = widget.initial?.province;
    _city = widget.initial?.city;
    _area = widget.initial?.area;
    _detailsController = TextEditingController(
      text: widget.initial?.details ?? '',
    )..addListener(_emit);
  }

  @override
  void dispose() {
    _detailsController.removeListener(_emit);
    _detailsController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged?.call(
      ServiceRegionSelection(
        province: _province,
        city: _city,
        area: _area,
        details: _detailsController.text,
      ),
    );
  }

  Future<void> _pickProvince() async {
    final sel = await showModalBottomSheet<ServiceRegionNode>(
      context: context,
      builder: (ctx) => _RegionListSheet(
        title: widget.labels.pickProvince,
        nodes: widget.provinces,
        selectedValue: _province?.value,
      ),
    );
    if (sel == null || !mounted) return;
    setState(() {
      _province = sel;
      _city = null;
      _area = null;
    });
    _emit();
  }

  /// 直辖市：省的 children 直接是区（如北京/上海），无"市"这一级。
  bool get _isMunicipality =>
      (_province?.isMunicipality ?? false) && (_province?.hasChildren ?? false);

  /// 是否需要显示"市"列：普通省（省有 children 且非直辖市）。
  bool get _needsCity {
    final p = _province;
    return p != null && p.hasChildren && !_isMunicipality;
  }

  /// 是否需要显示"区"列：
  /// - 直辖市：需要（省.children 就是区）
  /// - 普通省：已选市且市有 children（排除直筒子市，如东莞/中山/济源）
  bool get _needsArea => _isMunicipality || (_city?.hasChildren ?? false);

  Future<void> _pickCity() async {
    final p = _province;
    if (p == null || p.children.isEmpty || p.isMunicipality) return;
    final sel = await showModalBottomSheet<ServiceRegionNode>(
      context: context,
      builder: (ctx) => _RegionListSheet(
        title: widget.labels.pickCity,
        nodes: p.children,
        selectedValue: _city?.value,
      ),
    );
    if (sel == null || !mounted) return;
    setState(() {
      _city = sel;
      _area = null;
    });
    _emit();
  }

  Future<void> _pickArea() async {
    // 直辖市：从省.children 选区（省.children 就是区列表）。
    if (_isMunicipality) {
      final p = _province!;
      if (!p.hasChildren) return;
      final sel = await showModalBottomSheet<ServiceRegionNode>(
        context: context,
        builder: (ctx) => _RegionListSheet(
          title: widget.labels.pickArea,
          nodes: p.children,
          selectedValue: _area?.value,
        ),
      );
      if (sel == null || !mounted) return;
      setState(() => _area = sel);
      _emit();
      return;
    }
    // 普通省：从市.children 选区。
    final c = _city;
    if (c == null || c.children.isEmpty) return;
    final sel = await showModalBottomSheet<ServiceRegionNode>(
      context: context,
      builder: (ctx) => _RegionListSheet(
        title: widget.labels.pickArea,
        nodes: c.children,
        selectedValue: _area?.value,
      ),
    );
    if (sel == null || !mounted) return;
    setState(() => _area = sel);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 省/市/区按需竖排，保证窄屏下选中值完整显示。
        // 省列总是显示；市/区列根据结构自适应：
        // - 普通省：省→市→区
        // - 直辖市：省→区（隐藏市列）
        // - 香港/澳门（省无 children）：只选省
        // - 直筒子市（市无 children）：省→市（隐藏区列）
        _SelectorTile(
          label: widget.labels.province,
          value: _province?.label,
          selectHint: widget.labels.selectHint,
          onTap: _pickProvince,
        ),
        if (_needsCity) ...[
          const SizedBox(height: 8),
          _SelectorTile(
            label: widget.labels.city,
            value: _city?.label,
            selectHint: widget.labels.selectHint,
            onTap: _pickCity,
          ),
        ],
        if (_needsArea) ...[
          const SizedBox(height: 8),
          _SelectorTile(
            label: widget.labels.area,
            value: _area?.label,
            selectHint: widget.labels.selectHint,
            onTap: _pickArea,
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _detailsController,
          decoration: InputDecoration(
            hintText: widget.labels.detailHint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _SelectorTile extends StatelessWidget {
  final String label;
  final String? value;
  final String selectHint;
  final VoidCallback onTap;

  const _SelectorTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.selectHint = '请选择',
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppShapes.small),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value ?? selectHint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: value == null
                ? Theme.of(context).hintColor
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}

class _RegionListSheet extends StatelessWidget {
  final String title;
  final List<ServiceRegionNode> nodes;
  final String? selectedValue;

  const _RegionListSheet({
    required this.title,
    required this.nodes,
    this.selectedValue,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 400,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: nodes.length,
                itemBuilder: (context, i) {
                  final node = nodes[i];
                  final selected = node.value == selectedValue;
                  return ListTile(
                    title: Text(node.label),
                    trailing: selected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    selected: selected,
                    onTap: () => Navigator.pop(context, node),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
