import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:Bugaoshan/l10n/app_localizations.dart';
import 'package:Bugaoshan/models/course.dart';
import 'package:Bugaoshan/providers/course_provider.dart';
import 'package:Bugaoshan/widgets/dialog/dialog.dart';
import 'package:Bugaoshan/widgets/route/router_utils.dart';

enum ImportMode { share, jwxt }

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
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
      for (final course in courses) {
        await widget.courseProvider.addCourse(course);
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
      if (mounted) {
        showInfoDialog(title: l10n.importFailed, content: e.toString());
      }
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

    return (config: config, courses: courses);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.mode == ImportMode.jwxt
        ? l10n.importFromJwxt
        : l10n.importFromShare;

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
