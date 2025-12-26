import 'package:flutter/material.dart';
import 'package:rubbish_plan/l10n/app_localizations.dart';

class CourseScheduleSetting extends StatefulWidget {
  const CourseScheduleSetting({super.key});

  @override
  State<CourseScheduleSetting> createState() => _CourseScheduleSettingState();
}

class _CourseScheduleSettingState extends State<CourseScheduleSetting> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(localizations.scheduleSetting)),
      body: const Placeholder(),
    );
  }
}
