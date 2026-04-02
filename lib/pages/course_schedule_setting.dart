import 'package:flutter/material.dart';
import 'package:rubbish_plan/injection/injector.dart';
import 'package:rubbish_plan/l10n/app_localizations.dart';
import 'package:rubbish_plan/models/course.dart';
import 'package:rubbish_plan/pages/time_slot_setting_page.dart';
import 'package:rubbish_plan/providers/course_provider.dart';
import 'package:rubbish_plan/widgets/common/styled_card.dart';
import 'package:rubbish_plan/widgets/route/router_utils.dart';

class CourseScheduleSetting extends StatefulWidget {
  const CourseScheduleSetting({super.key});

  @override
  State<CourseScheduleSetting> createState() => _CourseScheduleSettingState();
}

class _CourseScheduleSettingState extends State<CourseScheduleSetting> {
  final courseProvider = getIt<CourseProvider>();

  late DateTime _startDate;
  late int _totalWeeks;
  late int _morningSections;
  late int _afternoonSections;
  late int _eveningSections;
  late int _courseDuration;
  late int _breakDuration;
  late bool _autoSyncTime;
  late List<TimeSlot> _timeSlots;
  late bool _showTeacher;
  late bool _showLocation;
  late bool _showWeekend;

  @override
  void initState() {
    super.initState();
    final config = courseProvider.scheduleConfig.value;
    _startDate = config.semesterStartDate;
    _totalWeeks = config.totalWeeks;
    _morningSections = config.morningSections;
    _afternoonSections = config.afternoonSections;
    _eveningSections = config.eveningSections;
    _courseDuration = config.courseDuration;
    _breakDuration = config.breakDuration;
    _autoSyncTime = config.autoSyncTime;
    _timeSlots = List.from(config.timeSlots);
    _showTeacher = config.showTeacherName;
    _showLocation = config.showLocation;
    _showWeekend = config.showWeekend;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scheduleSetting),
        actions: [TextButton(onPressed: _save, child: Text(l10n.save))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            // Semester config section
            _SectionTitle(l10n.semesterConfig),
            _DatePickerField(
              label: l10n.semesterStartDate,
              date: _startDate,
              onTap: () => _pickDate(context),
            ),
            _buildTotalWeeksPicker(context, l10n),
            const Divider(),
            // Time slots
            _SectionTitle(l10n.timeSlot),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.timeSlot),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await Navigator.push<TimeSlotSettingResult>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TimeSlotSettingPage(
                      morningSections: _morningSections,
                      afternoonSections: _afternoonSections,
                      eveningSections: _eveningSections,
                      initialCourseDuration: _courseDuration,
                      initialBreakDuration: _breakDuration,
                      initialAutoSyncTime: _autoSyncTime,
                      initialTimeSlots: _timeSlots,
                    ),
                  ),
                );

                if (result != null && mounted) {
                  setState(() {
                    _morningSections = result.morningSections;
                    _afternoonSections = result.afternoonSections;
                    _eveningSections = result.eveningSections;
                    _courseDuration = result.courseDuration;
                    _breakDuration = result.breakDuration;
                    _autoSyncTime = result.autoSyncTime;
                    _timeSlots = result.timeSlots;
                  });
                }
              },
            ),
            const Divider(),
            // Display settings
            _SectionTitle(l10n.displaySetting),
            // Show teacher
            SwitchListTile(
              title: Text(l10n.showTeacher),
              value: _showTeacher,
              onChanged: (v) => setState(() => _showTeacher = v),
              contentPadding: EdgeInsets.zero,
            ),
            // Show location
            SwitchListTile(
              title: Text(l10n.showLocation),
              value: _showLocation,
              onChanged: (v) => setState(() => _showLocation = v),
              contentPadding: EdgeInsets.zero,
            ),
            // Show weekend
            SwitchListTile(
              title: Text(l10n.showWeekend),
              value: _showWeekend,
              onChanged: (v) => setState(() => _showWeekend = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalWeeksPicker(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          l10n.totalWeeks(20).split(':')[0],
        ), // Using a trick to get the label
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: _totalWeeks > 1
                  ? () => setState(() => _totalWeeks--)
                  : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$_totalWeeks',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _totalWeeks < 52
                  ? () => setState(() => _totalWeeks++)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _save() async {
    final currentConfig = courseProvider.scheduleConfig.value;
    final config = currentConfig.copyWith(
      semesterStartDate: _startDate,
      totalWeeks: _totalWeeks,
      morningSections: _morningSections,
      afternoonSections: _afternoonSections,
      eveningSections: _eveningSections,
      courseDuration: _courseDuration,
      breakDuration: _breakDuration,
      autoSyncTime: _autoSyncTime,
      timeSlots: _timeSlots,
      showTeacherName: _showTeacher,
      showLocation: _showLocation,
      showWeekend: _showWeekend,
    );
    await courseProvider.updateScheduleConfig(config);
    if (logicRootContext.mounted) Navigator.pop(logicRootContext);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

// _TimeSlotEditor moved to time_slot_setting_page.dart
