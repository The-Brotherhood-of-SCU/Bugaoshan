import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/time_slot_setting_page.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';

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

  void _loadConfig() {
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
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scheduleSetting)),
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
            _buildSetCurrentWeekField(context, l10n),
            _buildTotalWeeksPicker(context, l10n),
            const Divider(),
            // Time slots
            _SectionTitle(l10n.timeSlot),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.timeSlot),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
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

                if (mounted) {
                  setState(() {
                    _loadConfig();
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
              onChanged: (v) {
                setState(() => _showTeacher = v);
                _save();
              },
              contentPadding: EdgeInsets.zero,
            ),
            // Show location
            SwitchListTile(
              title: Text(l10n.showLocation),
              value: _showLocation,
              onChanged: (v) {
                setState(() => _showLocation = v);
                _save();
              },
              contentPadding: EdgeInsets.zero,
            ),
            // Show weekend
            SwitchListTile(
              title: Text(l10n.showWeekend),
              value: _showWeekend,
              onChanged: (v) {
                setState(() => _showWeekend = v);
                _save();
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetCurrentWeekField(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    // Calculate current week based on _startDate
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(_startDate).inDays;
    int currentWeek = diff >= 0 ? (diff ~/ 7) + 1 : 1;
    if (currentWeek < 1) currentWeek = 1;
    if (currentWeek > _totalWeeks) currentWeek = _totalWeeks;

    return StyledCard(
      onTap: () => _pickCurrentWeek(context, currentWeek, l10n),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.setCurrentWeek),
                const SizedBox(height: 2),
                Text(
                  l10n.setCurrentWeekHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Text(
            l10n.currentWeek(currentWeek),
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Future<int?> _showNumberPicker(
    BuildContext context, {
    required int initialValue,
    required int minValue,
    required int maxValue,
    required String title,
  }) async {
    int tempValue = initialValue;
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SizedBox(
          height: 350,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, tempValue),
                      child: Text(AppLocalizations.of(context)!.confirm),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: initialValue - minValue,
                  ),
                  itemExtent: 40.0,
                  onSelectedItemChanged: (int index) {
                    tempValue = index + minValue;
                  },
                  children: List<Widget>.generate(maxValue - minValue + 1, (
                    int index,
                  ) {
                    return Center(
                      child: Text(
                        '${index + minValue}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickCurrentWeek(
    BuildContext context,
    int initialWeek,
    AppLocalizations l10n,
  ) async {
    final selectedWeek = await _showNumberPicker(
      context,
      initialValue: initialWeek,
      minValue: 1,
      maxValue: _totalWeeks,
      title: l10n.setCurrentWeek,
    );

    if (!mounted) return;

    if (selectedWeek != null && selectedWeek != initialWeek) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Calculate new start date based on selected current week
      // The current week's Monday is: today.toMonday()
      // So week 1's Monday is: today.toMonday() - (selectedWeek - 1) * 7 days
      final currentMonday = today.toMonday();
      final newStartDate = currentMonday.subtract(
        Duration(days: (selectedWeek - 1) * 7),
      );

      setState(() {
        _startDate = newStartDate;
      });
      _save();
    }
  }

  Widget _buildTotalWeeksPicker(BuildContext context, AppLocalizations l10n) {
    final String title = l10n.totalWeeks(20).split(':')[0]; // Get label part
    return StyledCard(
      onTap: () async {
        final selected = await _showNumberPicker(
          context,
          initialValue: _totalWeeks,
          minValue: 1,
          maxValue: 52,
          title: title,
        );
        if (!mounted) return;
        if (selected != null && selected != _totalWeeks) {
          setState(() {
            _totalWeeks = selected;
          });
          _save();
        }
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            '$_totalWeeks',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
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
      DateTime finalDate = picked;
      if (picked.weekday != DateTime.monday) {
        finalDate = picked.toMonday();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已自动调整为该周周一')));
        }
      }
      setState(() {
        _startDate = finalDate;
      });
      _save();
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
