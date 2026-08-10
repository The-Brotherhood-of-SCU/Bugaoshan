/// 办事大厅通用表单的字段组件。
///
/// 每个组件对应一种 [ServiceFieldType]，统一用 [CardWithTitle] 卡片外观
/// （与办事大厅各页面一致），通过回调向页面汇报值变化。
/// 必填字段标题带红色 `*`（由 `isRequired` 参数驱动，来自服务端 auth）。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:bugaoshan/services/api/service_plugin_models.dart';
import 'package:bugaoshan/widgets/common/service_region_picker.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';

/// 字段类型的默认图标（服务端不下发图标，按类型给 Material 默认）。
IconData iconForServiceFieldType(ServiceFieldType type) {
  return switch (type) {
    ServiceFieldType.input => Icons.edit_outlined,
    ServiceFieldType.multiInput => Icons.edit_note_outlined,
    ServiceFieldType.radio => Icons.radio_button_checked_outlined,
    ServiceFieldType.select => Icons.arrow_drop_down_circle_outlined,
    ServiceFieldType.selectV2 => Icons.arrow_drop_down_circle_outlined,
    ServiceFieldType.checkbox => Icons.check_box_outlined,
    ServiceFieldType.calendar => Icons.schedule_outlined,
    ServiceFieldType.region => Icons.place_outlined,
    ServiceFieldType.file => Icons.attach_file_outlined,
    ServiceFieldType.dataSource => Icons.support_agent_outlined,
    ServiceFieldType.user => Icons.badge_outlined,
    _ => Icons.tune_outlined,
  };
}

/// 字段卡片外壳：标题 + 必填标记 + 内容。
class ServiceFieldCard extends StatelessWidget {
  final String label;
  final bool isRequired;
  final IconData icon;
  final Widget child;

  const ServiceFieldCard({
    super.key,
    required this.label,
    required this.isRequired,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CardWithTitle(
      title: label,
      icon: Icon(icon),
      requiredMark: isRequired,
      child: child,
    );
  }
}

/// 单选字段（Radio）。
class ServiceRadioField extends StatelessWidget {
  final ServiceFormPlugin plugin;
  final String? value;
  final bool isRequired;
  final ValueChanged<String> onChanged;

  const ServiceRadioField({
    super.key,
    required this.plugin,
    required this.value,
    required this.isRequired,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ServiceFieldCard(
      label: plugin.label,
      isRequired: isRequired,
      icon: iconForServiceFieldType(plugin.type),
      child: RadioGroup<String>(
        groupValue: value,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        child: Column(
          children: [
            for (final opt in plugin.options)
              RadioListTile<String>(
                value: opt.value,
                title: Text(opt.label),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}

/// 下拉选择字段（Select）。
class ServiceSelectField extends StatelessWidget {
  final ServiceFormPlugin plugin;
  final String? value;
  final bool isRequired;
  final String hint;
  final ValueChanged<String> onChanged;

  const ServiceSelectField({
    super.key,
    required this.plugin,
    required this.value,
    required this.isRequired,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ServiceFieldCard(
      label: plugin.label,
      isRequired: isRequired,
      icon: iconForServiceFieldType(plugin.type),
      child: DropdownButtonFormField<String>(
        initialValue: plugin.options.any((o) => o.value == value)
            ? value
            : null,
        decoration: InputDecoration(
          hintText: plugin.hint ?? hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final opt in plugin.options)
            DropdownMenuItem(value: opt.value, child: Text(opt.label)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// 多选字段（Checkbox）。
class ServiceCheckboxField extends StatelessWidget {
  final ServiceFormPlugin plugin;
  final Set<String> values;
  final bool isRequired;
  final ValueChanged<Set<String>> onChanged;

  const ServiceCheckboxField({
    super.key,
    required this.plugin,
    required this.values,
    required this.isRequired,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ServiceFieldCard(
      label: plugin.label,
      isRequired: isRequired,
      icon: iconForServiceFieldType(plugin.type),
      child: Column(
        children: [
          for (final opt in plugin.options)
            CheckboxListTile(
              value: values.contains(opt.value),
              title: Text(opt.label),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (checked) {
                final next = {...values};
                if (checked ?? false) {
                  next.add(opt.value);
                } else {
                  next.remove(opt.value);
                }
                onChanged(next);
              },
            ),
        ],
      ),
    );
  }
}

/// 日期字段（Calendar）。
class ServiceCalendarField extends StatelessWidget {
  final ServiceFormPlugin plugin;
  final DateTime? value;
  final bool isRequired;
  final String Function(DateTime) format;
  final ValueChanged<DateTime> onChanged;

  const ServiceCalendarField({
    super.key,
    required this.plugin,
    required this.value,
    required this.isRequired,
    required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ServiceFieldCard(
      label: plugin.label,
      isRequired: isRequired,
      icon: iconForServiceFieldType(plugin.type),
      child: ListTile(
        leading: const Icon(Icons.event_outlined),
        title: Text(
          value == null ? (plugin.hint ?? '') : format(value!),
          style: value == null
              ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              : null,
        ),
        trailing: const Icon(Icons.chevron_right),
        contentPadding: EdgeInsets.zero,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? now,
            firstDate: now.subtract(const Duration(days: 365 * 2)),
            lastDate: now.add(const Duration(days: 365 * 2)),
          );
          if (picked != null) onChanged(picked);
        },
      ),
    );
  }
}

/// 单行文本字段（Input）。内部持有 controller，通过 [onChanged] 上报。
class ServiceInputField extends StatefulWidget {
  final ServiceFormPlugin plugin;
  final String initialValue;
  final bool isRequired;
  final ValueChanged<String> onChanged;

  const ServiceInputField({
    super.key,
    required this.plugin,
    this.initialValue = '',
    required this.isRequired,
    required this.onChanged,
  });

  @override
  State<ServiceInputField> createState() => _ServiceInputFieldState();
}

class _ServiceInputFieldState extends State<ServiceInputField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ServiceFieldCard(
      label: widget.plugin.label,
      isRequired: widget.isRequired,
      icon: iconForServiceFieldType(widget.plugin.type),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.plugin.hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

/// 多行文本字段（MultiInput）。
class ServiceMultiInputField extends StatefulWidget {
  final ServiceFormPlugin plugin;
  final String initialValue;
  final bool isRequired;
  final ValueChanged<String> onChanged;

  const ServiceMultiInputField({
    super.key,
    required this.plugin,
    this.initialValue = '',
    required this.isRequired,
    required this.onChanged,
  });

  @override
  State<ServiceMultiInputField> createState() => _ServiceMultiInputFieldState();
}

class _ServiceMultiInputFieldState extends State<ServiceMultiInputField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ServiceFieldCard(
      label: widget.plugin.label,
      isRequired: widget.isRequired,
      icon: iconForServiceFieldType(widget.plugin.type),
      child: TextField(
        controller: _controller,
        maxLines: 3,
        maxLength: 500,
        decoration: InputDecoration(
          hintText: widget.plugin.hint,
          border: const OutlineInputBorder(),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

/// 地区字段（Region，包装 [ServiceRegionPicker]）。
class ServiceRegionField extends StatelessWidget {
  final ServiceFormPlugin plugin;
  final ServiceRegionSelection? value;
  final bool isRequired;
  final List<ServiceRegionNode> provinces;
  final ServiceRegionLabels labels;
  final ValueChanged<ServiceRegionSelection> onChanged;

  const ServiceRegionField({
    super.key,
    required this.plugin,
    required this.value,
    required this.isRequired,
    required this.provinces,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ServiceFieldCard(
      label: plugin.label,
      isRequired: isRequired,
      icon: iconForServiceFieldType(plugin.type),
      child: ServiceRegionPicker(
        provinces: provinces,
        initial: value,
        labels: labels,
        onChanged: onChanged,
      ),
    );
  }
}

/// 附件字段（File，image_picker 选图，最多 [ServiceFormPlugin.maxCount] 张）。
class ServiceFileField extends StatelessWidget {
  final ServiceFormPlugin plugin;
  final List<File> files;
  final bool isRequired;
  final String hint;
  final String addLabel;
  final ValueChanged<List<File>> onChanged;

  const ServiceFileField({
    super.key,
    required this.plugin,
    required this.files,
    required this.isRequired,
    required this.hint,
    required this.addLabel,
    required this.onChanged,
  });

  Future<void> _pick() async {
    if (files.length >= plugin.maxCount) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    if (!await file.exists()) return;
    onChanged([...files, file]);
  }

  @override
  Widget build(BuildContext context) {
    return ServiceFieldCard(
      label: plugin.label,
      isRequired: isRequired,
      icon: iconForServiceFieldType(plugin.type),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (files.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < files.length; i++) _thumb(i, context),
                if (files.length < plugin.maxCount) _addTile(context),
              ],
            ),
          if (files.isEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(addLabel),
              ),
            ),
        ],
      ),
    );
  }

  Widget _thumb(int index, BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            files[index],
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: InkWell(
            onTap: () {
              final next = [...files]..removeAt(index);
              onChanged(next);
            },
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addTile(BuildContext context) {
    return InkWell(
      onTap: _pick,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.add,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
