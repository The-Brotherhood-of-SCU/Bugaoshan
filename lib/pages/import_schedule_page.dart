import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:rubbish_plan/l10n/app_localizations.dart';
import 'package:rubbish_plan/models/course.dart';
import 'package:rubbish_plan/providers/course_provider.dart';
import 'package:rubbish_plan/widgets/dialog/dialog.dart';

class ImportSchedulePage extends StatefulWidget {
  final CourseProvider courseProvider;

  const ImportSchedulePage({super.key, required this.courseProvider});

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
      final data = json.decode(text) as Map<String, dynamic>;
      
      // Parse config
      final configJson = data['config'] as Map<String, dynamic>;
      final config = ScheduleConfig.fromJson(configJson);
      config.id = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Initial suggested name: append '(导入)'
      String baseName = config.semesterName.isEmpty ? '导入的课表' : config.semesterName;
      if (!baseName.contains('(导入)')) {
        baseName = '$baseName (导入)';
      }
      
      String finalName = baseName;
      
      // Check for conflict and ask for rename if necessary
      if (widget.courseProvider.isScheduleNameTaken(finalName)) {
        final controller = TextEditingController(text: finalName);
        final newName = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.duplicateScheduleName),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('名称 "${finalName}" 已存在，请重命名：'),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.semesterName,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
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
                      Navigator.pop(context, text);
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
      
      config.semesterName = finalName;

      // Parse courses
      final coursesJson = data['courses'] as List<dynamic>;
      final courses = coursesJson.map((e) => Course.fromJson(e as Map<String, dynamic>)).toList();

      // Save to DB via provider
      await widget.courseProvider.addSchedule(config);
      // Switch is automatic in addSchedule, now add courses
      for (final course in courses) {
        await widget.courseProvider.addCourse(course);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importSuccess)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showInfoDialog(title: l10n.importFailed, content: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.importFromText),
        actions: [
          TextButton(
            onPressed: _import,
            child: Text(l10n.save),
          ),
        ],
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
