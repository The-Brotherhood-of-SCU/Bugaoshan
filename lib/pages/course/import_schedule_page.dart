import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/scu_auth_service.dart';
import 'package:bugaoshan/utils/session_expiry_handler.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

enum ImportMode { share, jwxt, online }

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
                onPressed: () => Navigator.pop(logicRootContext),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  final t = nameController.text.trim();
                  if (t.isNotEmpty) {
                    Navigator.pop(logicRootContext, t);
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

      // For share mode, check for conflict. For jwxt, we already got a name from user.
      if (widget.mode == ImportMode.share) {
        // Initial suggested name
        String baseName = config.semesterName.isEmpty
            ? l10n.importedScheduleDefaultName
            : config.semesterName;
        String finalName = baseName;

        // Check for conflict and ask for rename if necessary
        if (widget.courseProvider.isScheduleNameTaken(finalName)) {
          // Try appending '(导入)' if it doesn't already have it
          if (!finalName.contains(l10n.importNameSuffix)) {
            finalName = '$finalName ${l10n.importNameSuffix}';
          }

          // If it still conflicts (or if it already had '(导入)'), show rename dialog
          if (widget.courseProvider.isScheduleNameTaken(finalName)) {
            final controller = TextEditingController(text: finalName);
            final newName = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.duplicateScheduleName),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.importNameConflictHint(finalName)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(hintText: l10n.semesterName),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(logicRootContext),
                    child: Text(l10n.cancel),
                  ),
                  TextButton(
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isNotEmpty) {
                        if (widget.courseProvider.isScheduleNameTaken(text)) {
                          // Still taken
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.duplicateScheduleName)),
                          );
                        } else {
                          Navigator.pop(logicRootContext, text);
                        }
                      }
                    },
                    child: Text(l10n.save),
                  ),
                ],
              ),
            );

            if (newName == null) return; // User cancelled
            finalName = newName;
          }
        }
        config.semesterName = finalName;
      } else {
        // For jwxt, we already have a name from the first dialog.
        // Just ensure it doesn't conflict or handle it simply.
        if (widget.courseProvider.isScheduleNameTaken(config.semesterName)) {
          config.semesterName =
              '${config.semesterName} (${DateTime.now().millisecondsSinceEpoch % 1000})';
        }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.importSuccess)));
        if (Navigator.of(logicRootContext).canPop()) {
          Navigator.of(logicRootContext).pop();
        }
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

    setState(() => _loading = true);

    // 1. 获取学期列表
    List<({String value, String label})> semesters;
    try {
      semesters = await authProvider.service.fetchSemesters();
    } on ScuLoginException catch (e) {
      if (e.sessionExpired) await SessionExpiryHandler.handle(authProvider);
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

    // 2. 让用户选择学期（单个或全部）
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

    setState(() {
      _loading = true;
      _totalToImport = toImport.length;
      _currentProgress = 0;
    });
    try {
      for (final semester in toImport) {
        setState(() => _currentProgress++);
        final data = await authProvider.service.fetchJwxtSchedule(
          planCode: semester.value,
        );
        if (!mounted) return;

        String scheduleName = semester.label;

        // 单个导入时让用户自定义名称
        if (!importAll) {
          final nameController = TextEditingController(text: scheduleName);
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

        if (widget.courseProvider.isScheduleNameTaken(config.semesterName)) {
          config.semesterName =
              '${config.semesterName} (${DateTime.now().millisecondsSinceEpoch % 1000})';
        }

        await widget.courseProvider.addSchedule(config);
        for (final course in parsed.courses) {
          await widget.courseProvider.addCourse(course);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.importSuccess)));
        if (Navigator.of(logicRootContext).canPop()) {
          Navigator.of(logicRootContext).pop();
        }
      }
    } on ScuLoginException catch (e) {
      if (e.sessionExpired) {
        await SessionExpiryHandler.handle(authProvider);
      }
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

          // Parse weeks from classWeek bitstring (e.g. "111111111111111100000000")
          int startWeek = -1;
          int endWeek = -1;
          List<int> activeWeeks = [];
          for (int i = 0; i < classWeek.length; i++) {
            if (classWeek[i] == '1') {
              int w = i + 1;
              if (startWeek == -1) startWeek = w;
              endWeek = w;
              activeWeeks.add(w);
            }
          }

          if (startWeek != -1) {
            WeekType weekType = WeekType.every;
            if (activeWeeks.length > 1) {
              bool allOdd = activeWeeks.every((w) => w % 2 != 0);
              bool allEven = activeWeeks.every((w) => w % 2 == 0);
              if (allOdd) {
                weekType = WeekType.odd;
              } else if (allEven) {
                weekType = WeekType.even;
              }
            }

            courses.add(
              Course(
                name: courseName,
                teacher: teacher,
                location: location,
                startWeek: startWeek,
                endWeek: endWeek,
                dayOfWeek: dayOfWeek,
                startSection: startSection,
                endSection: endSection,
                colorValue: colors[colorIdx % colors.length].toARGB32(),
                weekType: weekType,
              ),
            );
            colorIdx++;
          }
        }
      });
    }

    final hasWeekend = courses.any((c) => c.dayOfWeek == 6 || c.dayOfWeek == 7);
    config.showWeekend = hasWeekend;

    return (config: config, courses: courses);
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
