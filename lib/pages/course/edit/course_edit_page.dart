import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/widgets/week_selector_grid.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class CourseEditPage extends StatefulWidget {
  final ScheduleConfig scheduleConfig;
  final Course? course;
  final int? prefillDayOfWeek;
  final int? prefillSection;

  /// 副本模式：`course` 是「待新增的副本」而非既有课程，保存走新增。
  final bool _isCopy;

  const CourseEditPage({
    super.key,
    required this.scheduleConfig,
    this.course,
    this.prefillDayOfWeek,
    this.prefillSection,
  }) : _isCopy = false;

  /// 以 [source] 为蓝本新建副本：副本使用全新 id（避免按 id 覆盖源课程），
  /// 保存时按新增落库。
  ///
  /// 草稿保留源课程的全部字段并把 [nameSuffix] 追加到名称后，用户可先调整
  /// 时段；保存前走与新增一致的冲突校验，因此保持原时段会被判定为与源课程
  /// 冲突。取消返回不会产生任何副本。
  CourseEditPage.createCopy({
    super.key,
    required this.scheduleConfig,
    required Course source,
    required String nameSuffix,
  }) : course = source.duplicate(nameSuffix: nameSuffix),
       prefillDayOfWeek = null,
       prefillSection = null,
       _isCopy = true;

  @override
  State<CourseEditPage> createState() => _CourseEditPageState();
}

class _CourseEditPageState extends State<CourseEditPage> {
  final courseProvider = getIt<CourseProvider>();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _teacherController;
  late TextEditingController _locationController;
  late Color _selectedColor;
  late int _startWeek;
  late int _endWeek;
  late int _dayOfWeek;
  late int _startSection;
  late int _endSection;
  late WeekType _weekType;
  late Set<int> _selectedWeeks;

  /// 编辑既有课程。副本模式下 [CourseEditPage.course] 非空，但它是一门
  /// 尚未入库的新课程，保存时必须走新增，否则会按 id 覆盖源课程。
  bool get _isEditMode => widget.course != null && !widget._isCopy;

  static Set<int> _computeWeeksForRange(int start, int end, WeekType type) {
    final result = <int>{};
    for (int w = start; w <= end; w++) {
      if (type == WeekType.odd && w.isEven) continue;
      if (type == WeekType.even && w.isOdd) continue;
      result.add(w);
    }
    return result;
  }

  bool get _isCustomDiscrete {
    final regular = _computeWeeksForRange(_startWeek, _endWeek, _weekType);
    return !setEquals(_selectedWeeks, regular);
  }

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    final config = widget.scheduleConfig;
    final maxSections = config.sectionsPerDay;

    _nameController = TextEditingController(text: course?.name ?? '');
    _teacherController = TextEditingController(text: course?.teacher ?? '');
    _locationController = TextEditingController(text: course?.location ?? '');
    _selectedColor =
        course?.color ?? _presetColors[Random().nextInt(_presetColors.length)];
    _startWeek = (course?.startWeek ?? 1).clamp(1, config.totalWeeks);
    _endWeek = (course?.endWeek ?? config.totalWeeks).clamp(
      1,
      config.totalWeeks,
    );
    _dayOfWeek = course?.dayOfWeek ?? widget.prefillDayOfWeek ?? 1;
    _startSection = (course?.startSection ?? widget.prefillSection ?? 1).clamp(
      1,
      maxSections,
    );
    _endSection = (course?.endSection ?? ((widget.prefillSection ?? 1) + 1))
        .clamp(1, maxSections);
    _weekType = course?.weekType ?? WeekType.every;
    if (course?.customWeeks != null && course!.customWeeks!.isNotEmpty) {
      _selectedWeeks = course.customWeeks!
          .where((w) => w <= config.totalWeeks)
          .toSet();
      if (_selectedWeeks.isEmpty) {
        _selectedWeeks = _computeWeeksForRange(_startWeek, _endWeek, _weekType);
      }
    } else {
      _selectedWeeks = _computeWeeksForRange(_startWeek, _endWeek, _weekType);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = widget.scheduleConfig;
    final totalWeeks = config.totalWeeks;
    final sections = config.sectionsPerDay;
    final dayNames = [
      l10n.sunday,
      l10n.monday,
      l10n.tuesday,
      l10n.wednesday,
      l10n.thursday,
      l10n.friday,
      l10n.saturday,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget._isCopy
              ? l10n.copyCourseTitle
              : (_isEditMode ? l10n.editCourse : l10n.addCourse),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(widget._isCopy ? l10n.copyCourseSave : l10n.save),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              // Course name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.courseName,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? l10n.fieldRequired : null,
              ),
              // Teacher
              TextFormField(
                controller: _teacherController,
                decoration: InputDecoration(
                  labelText: l10n.teacher,
                  border: const OutlineInputBorder(),
                ),
              ),
              // Location
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: l10n.location,
                  border: const OutlineInputBorder(),
                ),
              ),
              // Color picker
              _buildColorPicker(context, l10n),
              const Divider(),
              // Week range title with custom indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isCustomDiscrete && _selectedWeeks.isNotEmpty
                        ? '${Course.formatSegments(_selectedWeeks.toList())} 周'
                        : l10n.weekRange(_startWeek, _endWeek),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (_isCustomDiscrete)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.customWeeksHint,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text(l10n.startWeek)),
                  SizedBox(
                    width: 80,
                    child: DropdownButtonFormField<int>(
                      initialValue: _startWeek,
                      items: List.generate(totalWeeks, (i) => i + 1)
                          .map(
                            (w) =>
                                DropdownMenuItem(value: w, child: Text('$w')),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _startWeek = v;
                            if (_endWeek < _startWeek) {
                              _endWeek = _startWeek;
                            }
                            _selectedWeeks = _computeWeeksForRange(
                              _startWeek,
                              _endWeek,
                              _weekType,
                            );
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(l10n.endWeek)),
                  SizedBox(
                    width: 80,
                    child: DropdownButtonFormField<int>(
                      initialValue: _endWeek,
                      items:
                          List.generate(
                                totalWeeks - _startWeek + 1,
                                (i) => _startWeek + i,
                              )
                              .map(
                                (w) => DropdownMenuItem(
                                  value: w,
                                  child: Text('$w'),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _endWeek = v;
                            _selectedWeeks = _computeWeeksForRange(
                              _startWeek,
                              _endWeek,
                              _weekType,
                            );
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              // Week type
              Text(
                l10n.weekType,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l10n.everyWeek),
                    selected: _weekType == WeekType.every,
                    onSelected: (_) => setState(() {
                      _weekType = WeekType.every;
                      _selectedWeeks = _computeWeeksForRange(
                        _startWeek,
                        _endWeek,
                        _weekType,
                      );
                    }),
                  ),
                  ChoiceChip(
                    label: Text(l10n.oddWeek),
                    selected: _weekType == WeekType.odd,
                    onSelected: (_) => setState(() {
                      _weekType = WeekType.odd;
                      _selectedWeeks = _computeWeeksForRange(
                        _startWeek,
                        _endWeek,
                        _weekType,
                      );
                    }),
                  ),
                  ChoiceChip(
                    label: Text(l10n.evenWeek),
                    selected: _weekType == WeekType.even,
                    onSelected: (_) => setState(() {
                      _weekType = WeekType.even;
                      _selectedWeeks = _computeWeeksForRange(
                        _startWeek,
                        _endWeek,
                        _weekType,
                      );
                    }),
                  ),
                ],
              ),
              WeekSelectorGrid(
                totalWeeks: totalWeeks,
                selectedWeeks: _selectedWeeks,
                onWeekToggled: (w) {
                  setState(() {
                    if (_selectedWeeks.contains(w)) {
                      _selectedWeeks.remove(w);
                    } else {
                      _selectedWeeks.add(w);
                    }
                  });
                },
              ),
              const Divider(),
              Text(
                l10n.dayOfWeek,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Wrap(
                spacing: 8,
                children: List.generate(7, (i) {
                  final day = i == 0 ? 7 : i;
                  return ChoiceChip(
                    label: Text(dayNames[i]),
                    selected: _dayOfWeek == day,
                    onSelected: (selected) {
                      if (selected) setState(() => _dayOfWeek = day);
                    },
                  );
                }),
              ),
              const Divider(),
              // Section range
              Text(l10n.section, style: Theme.of(context).textTheme.titleSmall),
              Row(
                children: [
                  Expanded(child: Text(l10n.startSection)),
                  SizedBox(
                    width: 80,
                    child: DropdownButtonFormField<int>(
                      initialValue: _startSection,
                      items: List.generate(sections, (i) => i + 1)
                          .map(
                            (s) =>
                                DropdownMenuItem(value: s, child: Text('$s')),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _startSection = v;
                            if (_endSection < _startSection) {
                              _endSection = _startSection;
                            }
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(l10n.endSection)),
                  SizedBox(
                    width: 80,
                    child: DropdownButtonFormField<int>(
                      initialValue: _endSection,
                      items:
                          List.generate(
                                sections - _startSection + 1,
                                (i) => _startSection + i,
                              )
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text('$s'),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _endSection = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Delete button (only in edit mode)
              if (_isEditMode)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _deleteCourse,
                    icon: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    label: Text(
                      l10n.deleteCourse,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.courseColor, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._presetColors.map((color) {
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: _selectedColor.toARGB32() == color.toARGB32()
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3,
                          )
                        : null,
                  ),
                ),
              );
            }),
            GestureDetector(
              onTap: () => _pickCustomColor(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      _presetColors.every(
                        (c) => c.toARGB32() != _selectedColor.toARGB32(),
                      )
                      ? _selectedColor
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child:
                    _presetColors.every(
                      (c) => c.toARGB32() != _selectedColor.toARGB32(),
                    )
                    ? null
                    : const Icon(Icons.add, size: 18, color: Colors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _pickCustomColor(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.customColor),
        content: BlockPicker(
          pickerColor: _selectedColor,
          onColorChanged: (color) {
            setState(() => _selectedColor = color);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;

    // 重新读取当前课表的最新配置，避免打开编辑页后切表导致的快照错位
    final config = courseProvider.scheduleConfig.value;
    if (config == null) return;
    final morningEnd = config.morningSections;
    final afternoonEnd = config.morningSections + config.afternoonSections;

    bool isValidPeriod = false;
    if (_startSection <= morningEnd && _endSection <= morningEnd) {
      isValidPeriod = true; // Morning
    } else if (_startSection > morningEnd &&
        _startSection <= afternoonEnd &&
        _endSection > morningEnd &&
        _endSection <= afternoonEnd) {
      isValidPeriod = true; // Afternoon
    } else if (_startSection > afternoonEnd && _endSection > afternoonEnd) {
      isValidPeriod = true; // Evening
    }

    if (!isValidPeriod) {
      unawaited(
        showInfoDialog(
          title: l10n.crossPeriodError,
          content: l10n.crossPeriodErrorMessage,
        ),
      );
      return;
    }

    if (_selectedWeeks.isEmpty) {
      unawaited(
        showInfoDialog(
          title: l10n.activeWeeks,
          content: l10n.selectAtLeastOneWeek,
        ),
      );
      return;
    }

    final isCustom = _isCustomDiscrete;
    final sortedWeeks = _selectedWeeks.toList()..sort();
    final startWeek = isCustom ? sortedWeeks.first : _startWeek;
    final endWeek = isCustom ? sortedWeeks.last : _endWeek;
    final weekType = isCustom ? WeekType.every : _weekType;
    final customWeeks = isCustom ? sortedWeeks : null;

    final course = Course(
      id: widget.course?.id,
      name: _nameController.text.trim(),
      teacher: _teacherController.text.trim(),
      location: _locationController.text.trim(),
      // 编辑页不提供校区输入，保留原值避免教务导入的校区被清空。
      campus: widget.course?.campus ?? '',
      startWeek: startWeek,
      endWeek: endWeek,
      dayOfWeek: _dayOfWeek,
      startSection: _startSection,
      endSection: _endSection,
      colorValue: _selectedColor.toARGB32(),
      weekType: weekType,
      customWeeks: customWeeks,
    );

    // Check for conflicts
    // 编辑：排除自身，避免与旧记录冲突；副本：副本尚未入库，不排除任何
    // 课程，因此沿用源课程时段会被判为冲突，用户需先调整时段才能保存。
    final hasConflict = await courseProvider.hasConflict(
      course,
      excludeId: _isEditMode ? widget.course?.id : null,
    );

    if (hasConflict) {
      if (!mounted) return;
      unawaited(
        showInfoDialog(
          title: l10n.timeConflict,
          content: l10n.timeConflictMessage,
        ),
      );
      return;
    }

    if (_isEditMode) {
      await courseProvider.updateCourse(course);
    } else {
      await courseProvider.addCourse(course);
    }

    if (mounted) {
      final rootCtx = logicRootContext;
      if (rootCtx.mounted) Navigator.pop(rootCtx);
    }
  }

  Future<void> _deleteCourse() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showYesNoDialog(
      title: l10n.deleteCourse,
      content: l10n.deleteCourseConfirm,
    );
    if (confirm == true && widget.course != null) {
      await courseProvider.deleteCourse(widget.course!.id);
      if (mounted) {
        final rootCtx = logicRootContext;
        if (rootCtx.mounted) Navigator.pop(rootCtx);
      }
    }
  }

  static const List<Color> _presetColors = [
    Color(0xFFEF5350), // Red
    Color(0xFFEC407A), // Pink
    Color(0xFFAB47BC), // Purple
    Color(0xFF7E57C2), // Deep Purple
    Color(0xFF5C6BC0), // Indigo
    Color(0xFF42A5F5), // Blue
    Color(0xFF26C6DA), // Cyan
    Color(0xFF26A69A), // Teal
    Color(0xFF66BB6A), // Green
    Color(0xFF9CCC65), // Light Green
    Color(0xFFFFA726), // Orange
    Color(0xFF8D6E63), // Brown
  ];
}
