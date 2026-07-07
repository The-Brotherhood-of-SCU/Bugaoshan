import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/time_slot_setting_page.dart';
import 'package:bugaoshan/pages/settings/set_course_style_page.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/info_card.dart';
import 'package:bugaoshan/widgets/common/styled_tile.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:bugaoshan/utils/app_shapes.dart';

class CourseScheduleSetting extends StatefulWidget {
  const CourseScheduleSetting({super.key});

  @override
  State<CourseScheduleSetting> createState() => _CourseScheduleSettingState();
}

class _CourseScheduleSettingState extends State<CourseScheduleSetting> {
  final courseProvider = getIt<CourseProvider>();
  final authProvider = getIt<ScuAuthProvider>();

  late DateTime _startDate;
  late int _totalWeeks;
  late int _morningSections;
  late int _afternoonSections;
  late int _eveningSections;
  late int _courseDuration;
  late int _breakDuration;
  late bool _autoSyncTime;
  late List<TimeSlot> _timeSlots;
  bool _fetchingCurrentWeek = false;

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
  }

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _fetchCurrentWeek() async {
    if (!authProvider.isLoggedIn) return;
    setState(() => _fetchingCurrentWeek = true);
    try {
      final week = await getIt<ZhjwApiService>().fetchCurrentWeek();
      if (!mounted) return;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentSunday = today.toSunday();
      final newStartDate = currentSunday.subtract(
        Duration(days: (week - 1) * 7),
      );
      setState(() {
        _startDate = newStartDate;
      });
      _save();
    } on ScuException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _fetchingCurrentWeek = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scheduleSetting)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Semester config section
          _SectionTitle(title: l10n.semesterConfig),
          _buildSemesterConfigGroup(context, l10n),
          const SizedBox(height: 14),

          // Time slots
          _SectionTitle(title: l10n.timeSlot),
          InfoCard(
            children: [
              IconTile(
                icon: Icons.schedule_rounded,
                label: l10n.timeSlot,
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
            ],
          ),
          const SizedBox(height: 14),

          // Course style entry
          _SectionTitle(title: l10n.courseStyleSetting),
          InfoCard(
            children: [
              IconTile(
                icon: Icons.style,
                label: l10n.courseStyleSetting,
                onTap: () =>
                    popupOrNavigate(context, const SetCourseStylePage()),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSemesterConfigGroup(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(_startDate).inDays;
    int currentWeek = diff >= 0 ? (diff ~/ 7) + 1 : 1;
    if (currentWeek < 1) currentWeek = 1;
    if (currentWeek > _totalWeeks) currentWeek = _totalWeeks;

    final isLoggedIn = authProvider.isLoggedIn;
    final totalWeeksTitle = l10n.totalWeeks(20).split(':')[0];
    final divider = Divider(
      height: 1,
      indent: 0,
      color: theme.dividerColor.withValues(alpha: 0.08),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SemesterRow(
              label: l10n.semesterStartDate,
              trailing: Text(
                '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              onTap: () => _pickDate(context),
            ),
            divider,
            _SemesterRow(
              label: l10n.setCurrentWeek,
              hint: l10n.setCurrentWeekHint,
              trailing: Text(
                l10n.currentWeek(currentWeek),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              onTap: () => _pickCurrentWeek(context, currentWeek, l10n),
            ),
            divider,
            _SemesterRow(
              label: l10n.autoFetchCurrentWeek,
              hint: isLoggedIn
                  ? l10n.autoFetchCurrentWeekHint
                  : l10n.loginRequired,
              trailing: _fetchingCurrentWeek
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.download,
                      color: isLoggedIn
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
              labelStyle: isLoggedIn
                  ? null
                  : TextStyle(color: theme.colorScheme.outline),
              onTap: isLoggedIn && !_fetchingCurrentWeek
                  ? _fetchCurrentWeek
                  : null,
            ),
            divider,
            _SemesterRow(
              label: totalWeeksTitle,
              trailing: Text(
                '$_totalWeeks',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              onTap: () async {
                final selected = await _showNumberPicker(
                  context,
                  initialValue: _totalWeeks,
                  minValue: 1,
                  maxValue: 52,
                  title: totalWeeksTitle,
                );
                if (!mounted) return;
                if (selected != null && selected != _totalWeeks) {
                  setState(() {
                    _totalWeeks = selected;
                  });
                  _save();
                }
              },
            ),
          ],
        ),
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppShapes.largeIncreased),
        ),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
      // 教务系统以周日为每周第一天
      final currentSunday = today.toSunday();
      final newStartDate = currentSunday.subtract(
        Duration(days: (selectedWeek - 1) * 7),
      );

      setState(() {
        _startDate = newStartDate;
      });
      _save();
    }
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
      if (picked.weekday != DateTime.sunday) {
        finalDate = picked.toSunday();
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已自动调整为该周周日')));
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
    );
    await courseProvider.updateScheduleConfig(config);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 10, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SemesterRow extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget trailing;
  final VoidCallback? onTap;
  final TextStyle? labelStyle;

  const _SemesterRow({
    required this.label,
    required this.trailing,
    this.hint,
    this.onTap,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: labelStyle ?? theme.textTheme.bodyLarge),
                    if (hint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
