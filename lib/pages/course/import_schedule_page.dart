import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/api/academic_calendar_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/class_week_parser.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

enum ImportMode { share, jwxt, online }

/// 课表名称冲突时的用户选择结果。
class _NameConflictResult {
  final bool isCancel;
  final bool isUpdate;
  final String? finalName;
  final String? existingScheduleId;

  _NameConflictResult._({
    this.isCancel = false,
    this.isUpdate = false,
    this.finalName,
    this.existingScheduleId,
  });

  factory _NameConflictResult.cancel() => _NameConflictResult._(isCancel: true);

  factory _NameConflictResult.addSuffix(String name) =>
      _NameConflictResult._(finalName: name);

  factory _NameConflictResult.update(String scheduleId) =>
      _NameConflictResult._(isUpdate: true, existingScheduleId: scheduleId);
}

/// 批量导入时的统一操作方式。
enum _BatchAction { addSuffix, update }

class ImportSchedulePage extends StatefulWidget {
  final CourseProvider courseProvider;
  final ImportMode mode;

  const ImportSchedulePage({
    super.key,
    required this.courseProvider,
    this.mode = ImportMode.share,
  });

  @override
  State<ImportSchedulePage> createState() => _ImportSchedulePageState();
}

class _ImportSchedulePageState extends State<ImportSchedulePage> {
  final _controller = TextEditingController();
  bool _loading = false;
  int _currentProgress = 0;
  int _totalToImport = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    // online 模式走独立流程
    if (widget.mode == ImportMode.online) {
      await _importOnline();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      final data = json.decode(text);
      ScheduleConfig config;
      List<Course> courses;

      if (widget.mode == ImportMode.jwxt) {
        // Prompt for schedule name first
        final nameController = TextEditingController(
          text: 'JWXT Import ${DateTime.now().month}-${DateTime.now().day}',
        );
        if (!mounted) return;
        final newName = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.importFromJwxt),
            content: TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(hintText: l10n.semesterName),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  final t = nameController.text.trim();
                  if (t.isNotEmpty) {
                    Navigator.pop(context, t);
                  }
                },
                child: Text(l10n.save),
              ),
            ],
          ),
        );

        if (newName == null) return; // User cancelled

        final parsed = _parseJwxtData(data);
        config = parsed.config;
        config.semesterName = newName;
        courses = parsed.courses;
      } else {
        final Map<String, dynamic> mapData = data as Map<String, dynamic>;
        // Parse config
        final configJson = mapData['config'] as Map<String, dynamic>;
        config = ScheduleConfig.fromJson(configJson);
        // Parse courses
        final coursesJson = mapData['courses'] as List<dynamic>;
        courses = coursesJson
            .map((e) => Course.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      config.id = DateTime.now().millisecondsSinceEpoch.toString();
      _validateImportedSchedule(config, courses);

      // Resolve name conflict if any
      final desiredName = config.semesterName.isEmpty
          ? l10n.importedScheduleDefaultName
          : config.semesterName;
      final resolution = await _resolveNameConflict(desiredName);

      if (resolution == null) {
        // No conflict — proceed with desired name
        config.semesterName = desiredName;
      } else if (resolution.isCancel) {
        return;
      } else if (resolution.isUpdate) {
        // Update existing schedule's courses instead of creating new.
        // Regenerate IDs to avoid PRIMARY KEY conflicts (source JSON may have
        // empty or duplicate IDs).
        final newCourses = courses
            .map(
              (c) => Course(
                name: c.name,
                teacher: c.teacher,
                location: c.location,
                startWeek: c.startWeek,
                endWeek: c.endWeek,
                dayOfWeek: c.dayOfWeek,
                startSection: c.startSection,
                endSection: c.endSection,
                colorValue: c.colorValue,
                weekType: c.weekType,
              ),
            )
            .toList();
        await widget.courseProvider.replaceScheduleCourses(
          resolution.existingScheduleId!,
          newCourses,
        );
        if (mounted) {
          _showSuccessAndPop();
        }
        return; // Done
      } else {
        // addSuffix
        config.semesterName = resolution.finalName!;
      }

      // Save to DB via provider
      await widget.courseProvider.addSchedule(config);
      // Switch is automatic in addSchedule, now add courses
      // Assign new IDs to avoid PRIMARY KEY conflicts with existing courses
      for (final course in courses) {
        await widget.courseProvider.addCourse(
          Course(
            name: course.name,
            teacher: course.teacher,
            location: course.location,
            startWeek: course.startWeek,
            endWeek: course.endWeek,
            dayOfWeek: course.dayOfWeek,
            startSection: course.startSection,
            endSection: course.endSection,
            colorValue: course.colorValue,
            weekType: course.weekType,
          ),
        );
      }

      if (mounted) {
        _showSuccessAndPop();
      }
    } catch (e) {
      debugPrint('Import from share error: $e');
      if (mounted) {
        showInfoDialog(title: l10n.importFailed, content: l10n.importFailed);
      }
    }
  }

  Future<void> _importOnline() async {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = getIt<ScuAuthProvider>();

    if (!authProvider.isLoggedIn) {
      if (mounted) {
        showInfoDialog(title: l10n.loginRequired, content: l10n.scuLogin);
      }
      return;
    }

    // 记录教务处标记为"（当前）"的学期名（剥离后缀后），导入完成后切到它
    String? currentSemesterCleanName;

    setState(() => _loading = true);

    // 1. 获取学期列表
    List<({String value, String label})> semesters;
    try {
      semesters = await getIt<ZhjwApiService>().fetchSemesters();

      for (final s in semesters) {
        if (s.label.contains('（当前）') || s.label.contains('(当前)')) {
          currentSemesterCleanName = _cleanSemesterLabel(s.label);
          break;
        }
      }
    } on ScuException catch (e) {
      if (mounted) showInfoDialog(title: l10n.importFailed, content: e.message);
      if (mounted) setState(() => _loading = false);
      return;
    } catch (e) {
      debugPrint('Import online error: $e');
      if (mounted) {
        showInfoDialog(title: l10n.importFailed, content: l10n.importFailed);
        setState(() => _loading = false);
      }
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;

    // 2. 让用户选择学期（单个或全部）—— 下拉框保持显示原始 label（含"（当前）"），方便用户识别
    String selectedValue = semesters.first.value;
    // null = 取消, true = 全部导入, false = 导入选中学期
    final choice = await showDialog<Object>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(l10n.selectSemester),
            content: DropdownButton<String>(
              value: selectedValue,
              isExpanded: true,
              items: semesters
                  .map(
                    (s) =>
                        DropdownMenuItem(value: s.value, child: Text(s.label)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setDialogState(() => selectedValue = v);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'all'),
                child: Text(l10n.importAll),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'one'),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        );
      },
    );
    if (choice == null || !mounted) return;

    final importAll = choice == 'all';
    final toImport = importAll
        ? semesters.reversed.toList()
        : [semesters.firstWhere((s) => s.value == selectedValue)];

    // 批量导入：先检查是否有名称冲突，询问统一操作方式
    _BatchAction? batchAction;
    if (importAll) {
      final hasConflict = toImport.any(
        (s) => widget.courseProvider.isScheduleNameTaken(
          _cleanSemesterLabel(s.label),
        ),
      );
      if (hasConflict && mounted) {
        batchAction = await showDialog<_BatchAction>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.duplicateScheduleName),
            content: Text(l10n.importAllConflictAction),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _BatchAction.addSuffix),
                child: Text(l10n.importAllConflictAddSuffix),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _BatchAction.update),
                child: Text(l10n.importAllConflictUpdate),
              ),
            ],
          ),
        );
        if (batchAction == null || !mounted) return;
      }
    }

    setState(() {
      _loading = true;
      _totalToImport = toImport.length;
      _currentProgress = 0;
    });
    final importedSchedules = <({String id, String name})>[];
    try {
      for (final semester in toImport) {
        setState(() => _currentProgress++);
        final data = await getIt<ZhjwApiService>().fetchJwxtSchedule(
          planCode: semester.value,
        );
        if (!mounted) return;

        // 剥离"（当前）"后缀，教务处用此标记当前学期，但不应出现在课表名中
        String scheduleName = _cleanSemesterLabel(semester.label);

        // 单个导入时让用户自定义名称
        if (!importAll) {
          final nameController = TextEditingController(text: scheduleName);
          if (!mounted) return;
          final newName = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.importFromJwxt),
              content: TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(hintText: l10n.semesterName),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () {
                    final t = nameController.text.trim();
                    if (t.isNotEmpty) Navigator.pop(ctx, t);
                  },
                  child: Text(l10n.save),
                ),
              ],
            ),
          );
          if (newName == null || !mounted) return;
          scheduleName = newName;
        }

        final parsed = _parseJwxtData(data);
        final config = parsed.config;
        config.semesterName = scheduleName;
        config.id = DateTime.now().millisecondsSinceEpoch.toString();
        _validateImportedSchedule(config, parsed.courses);

        if (!importAll) {
          // 单个导入：询问用户如何处理名称冲突
          final resolution = await _resolveNameConflict(scheduleName);
          if (resolution == null) {
            // 无冲突，保持原名
          } else if (resolution.isCancel) {
            return;
          } else if (resolution.isUpdate) {
            await widget.courseProvider.replaceScheduleCourses(
              resolution.existingScheduleId!,
              parsed.courses,
            );
            importedSchedules.add((
              id: resolution.existingScheduleId!,
              name: scheduleName,
            ));
            continue;
          } else {
            config.semesterName = resolution.finalName!;
          }
        } else if (batchAction == _BatchAction.update) {
          // 批量-全部更新：替换已有课表的全部课程
          final existingId = widget.courseProvider.findScheduleIdByName(
            scheduleName,
          );
          if (existingId != null) {
            await widget.courseProvider.replaceScheduleCourses(
              existingId,
              parsed.courses,
            );
            importedSchedules.add((id: existingId, name: scheduleName));
            continue;
          }
          // existingId == null 表示该学期无冲突，正常添加即可
        } else if (batchAction == _BatchAction.addSuffix) {
          // 批量-全部添加后缀：为每个冲突名称追加时间戳
          if (widget.courseProvider.isScheduleNameTaken(config.semesterName)) {
            config.semesterName =
                '${config.semesterName} (${DateTime.now().millisecondsSinceEpoch % 1000})';
          }
        }
        // batchAction == null 表示预检查时无冲突，保持原名正常导入

        await widget.courseProvider.addSchedule(config);
        importedSchedules.add((id: config.id, name: config.semesterName));
        for (final course in parsed.courses) {
          await widget.courseProvider.addCourse(course);
        }
      }

      // 导入完成后，将教务处标记为"（当前）"的课表设为当前
      if (currentSemesterCleanName != null && mounted) {
        final allSchedules = widget.courseProvider.allSchedules.value;
        final match = allSchedules.where(
          (s) => s.semesterName.trim() == currentSemesterCleanName,
        );
        if (match.isNotEmpty) {
          await widget.courseProvider.switchSchedule(match.first.id);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.importSuccess)));

        // 询问是否根据校历自动计算周数（批量导入只问一次）
        if (!mounted) return;
        final calcWeeks = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.autoCalcWeeksTitle),
            content: Text(l10n.autoCalcWeeksContent),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        );
        if (calcWeeks == true && mounted) {
          for (final imported in importedSchedules) {
            try {
              final weeks =
                  await AcademicCalendarService.findTotalWeeksFromCalendar(
                    imported.name,
                  );
              if (weeks != null) {
                final allSchedules = widget.courseProvider.allSchedules.value;
                final schedule = allSchedules
                    .where((s) => s.id == imported.id)
                    .firstOrNull;
                if (schedule != null) {
                  final updated = schedule.copyWith(totalWeeks: weeks);
                  await widget.courseProvider.updateScheduleConfig(updated);
                }
              }
            } catch (_) {
              // 单个匹配失败不阻断，继续下一个
            }
          }
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.autoCalcWeeksSuccess)));
          }
        }

        // 导入成功后，询问是否自动设置当前教学周
        if (!mounted) return;
        final setWeek = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.autoSetCurrentWeekTitle),
            content: Text(l10n.autoSetCurrentWeekContent),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        );
        if (setWeek == true && mounted) {
          try {
            final week = await getIt<ZhjwApiService>().fetchCurrentWeek();
            if (!mounted) return;
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final currentSunday = today.toSunday();
            final newStartDate = currentSunday.subtract(
              Duration(days: (week - 1) * 7),
            );
            final currentConfig = widget.courseProvider.scheduleConfig.value;
            final updatedConfig = currentConfig.copyWith(
              semesterStartDate: newStartDate,
            );
            await widget.courseProvider.updateScheduleConfig(updatedConfig);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.autoSetCurrentWeekSuccess)),
              );
            }
          } catch (_) {
            // 获取失败不阻断流程，静默忽略
          }
        }

        if (logicRootContext.mounted &&
            Navigator.of(logicRootContext).canPop()) {
          Navigator.of(logicRootContext).pop();
        }
      }
    } on ScuException catch (e) {
      if (mounted) showInfoDialog(title: l10n.importFailed, content: e.message);
    } catch (e) {
      debugPrint('Import from jwxt error: $e');
      if (mounted) {
        showInfoDialog(title: l10n.importFailed, content: l10n.importFailed);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 剥离教务处学期标签中的"（当前）"标记。
  String _cleanSemesterLabel(String label) {
    return label.replaceAll('（当前）', '').replaceAll('(当前)', '').trim();
  }

  ({ScheduleConfig config, List<Course> courses}) _parseJwxtData(dynamic data) {
    final Map<String, dynamic> jwxtData = data as Map<String, dynamic>;
    final List<dynamic> xkxx = jwxtData['xkxx'] as List<dynamic>;

    // Default config
    final config = ScheduleConfig(
      semesterStartDate: DateTime.now()
          .toMonday(), // User might need to adjust this later
      semesterName: 'JWXT Import ${DateTime.now().month}-${DateTime.now().day}',
    );

    final List<Course> courses = [];
    final colors = Colors.primaries;
    int colorIdx = 0;

    for (final item in xkxx) {
      final Map<String, dynamic> courseMap = item as Map<String, dynamic>;
      courseMap.forEach((key, value) {
        final Map<String, dynamic> details = value as Map<String, dynamic>;
        final String rawName = details['courseName'] as String? ?? 'Unknown';
        final String courseSequence =
            details['id']?['coureSequenceNumber'] as String? ?? '';
        final String courseName = '$rawName ($courseSequence)';
        final String teacher = details['attendClassTeacher'] as String? ?? '';
        final List<dynamic> timeAndPlaceList =
            details['timeAndPlaceList'] as List<dynamic>? ?? [];

        for (final tp in timeAndPlaceList) {
          final Map<String, dynamic> tpMap = tp as Map<String, dynamic>;
          final int dayOfWeek = tpMap['classDay'] as int;
          final int startSection = tpMap['classSessions'] as int;
          final int continuingSession = tpMap['continuingSession'] as int;
          final int endSection = startSection + continuingSession - 1;
          final String location =
              '${tpMap['teachingBuildingName'] ?? ''}${tpMap['classroomName'] ?? ''}';
          final String classWeek = tpMap['classWeek'] as String? ?? '';

          final weekSegments = parseClassWeekSegments(classWeek);
          if (weekSegments.isNotEmpty) {
            final colorValue = colors[colorIdx % colors.length].toARGB32();
            for (final segment in weekSegments) {
              courses.add(
                Course(
                  name: courseName,
                  teacher: teacher,
                  location: location,
                  startWeek: segment.startWeek,
                  endWeek: segment.endWeek,
                  dayOfWeek: dayOfWeek,
                  startSection: startSection,
                  endSection: endSection,
                  colorValue: colorValue,
                  weekType: segment.weekType,
                ),
              );
            }
            colorIdx++;
          }
        }
      });
    }

    final hasWeekend = courses.any((c) => c.dayOfWeek == 6 || c.dayOfWeek == 7);
    getIt<AppConfigProvider>().showWeekend.value = hasWeekend;

    return (config: config, courses: courses);
  }

  void _validateImportedSchedule(ScheduleConfig config, List<Course> courses) {
    if (config.totalWeeks < 1 || config.timeSlots.isEmpty) {
      throw const FormatException('Invalid schedule config');
    }
    final maxSection = config.timeSlots.length;
    for (final course in courses) {
      if (course.startWeek < 1 ||
          course.endWeek < course.startWeek ||
          course.endWeek > config.totalWeeks ||
          course.dayOfWeek < 1 ||
          course.dayOfWeek > 7 ||
          course.startSection < 1 ||
          course.endSection < course.startSection ||
          course.endSection > maxSection) {
        throw FormatException('Invalid course range: ${course.name}');
      }
    }
  }

  /// 检查课表名称是否冲突，如果冲突则弹出对话框询问用户操作。
  /// 返回 `null` 表示无冲突（可继续以原名称导入）。
  Future<_NameConflictResult?> _resolveNameConflict(String desiredName) async {
    final l10n = AppLocalizations.of(context)!;
    if (!widget.courseProvider.isScheduleNameTaken(desiredName)) {
      return null; // No conflict
    }

    final existingId = widget.courseProvider.findScheduleIdByName(desiredName);

    if (!mounted) return _NameConflictResult.cancel();
    return showDialog<_NameConflictResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.duplicateScheduleName),
        content: Text(l10n.importNameConflictAction(desiredName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              ctx,
              _NameConflictResult.addSuffix(
                '$desiredName ${l10n.importNameSuffix}',
              ),
            ),
            child: Text(l10n.importNameConflictAddSuffix),
          ),
          if (existingId != null)
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, _NameConflictResult.update(existingId)),
              child: Text(l10n.importNameConflictUpdate),
            ),
        ],
      ),
    );
  }

  /// 显示导入成功提示并关闭页面。
  void _showSuccessAndPop() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.importSuccess)));
    if (logicRootContext.mounted && Navigator.of(logicRootContext).canPop()) {
      Navigator.of(logicRootContext).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = switch (widget.mode) {
      ImportMode.jwxt => l10n.importFromJwxt,
      ImportMode.online => l10n.importFromJwxtOnline,
      ImportMode.share => l10n.importFromShare,
    };

    if (widget.mode == ImportMode.online) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                const Icon(Icons.cloud_download_outlined, size: 64),
                Text(
                  l10n.importFromJwxtOnlineHint,
                  textAlign: TextAlign.center,
                ),
                if (_loading && _totalToImport > 1) ...[
                  LinearProgressIndicator(
                    value: _totalToImport > 0
                        ? _currentProgress / _totalToImport
                        : null,
                  ),
                  Text(
                    l10n.importingProgress(_currentProgress, _totalToImport),
                  ),
                ],
                if (_loading && _totalToImport <= 1)
                  const CircularProgressIndicator(),
                if (!_loading)
                  FilledButton.icon(
                    onPressed: _import,
                    icon: const Icon(Icons.download),
                    label: Text(l10n.importFromJwxtOnline),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [TextButton(onPressed: _import, child: Text(l10n.save))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            hintText: l10n.importDataHint,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}
