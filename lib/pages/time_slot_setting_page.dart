import 'package:flutter/material.dart';
import 'package:rubbish_plan/injection/injector.dart';
import 'package:rubbish_plan/l10n/app_localizations.dart';
import 'package:rubbish_plan/models/course.dart';
import 'package:rubbish_plan/providers/course_provider.dart';

class TimeSlotSettingPage extends StatefulWidget {
  final int morningSections;
  final int afternoonSections;
  final int eveningSections;
  final int initialCourseDuration;
  final int initialBreakDuration;
  final bool initialAutoSyncTime;
  final List<TimeSlot> initialTimeSlots;

  const TimeSlotSettingPage({
    super.key,
    required this.morningSections,
    required this.afternoonSections,
    required this.eveningSections,
    required this.initialCourseDuration,
    required this.initialBreakDuration,
    required this.initialAutoSyncTime,
    required this.initialTimeSlots,
  });

  @override
  State<TimeSlotSettingPage> createState() => _TimeSlotSettingPageState();
}

class _TimeSlotSettingPageState extends State<TimeSlotSettingPage> {
  final courseProvider = getIt<CourseProvider>();
  late int _morningSections;
  late int _afternoonSections;
  late int _eveningSections;
  late int _courseDuration;
  late int _breakDuration;
  late bool _autoSyncTime;
  late List<TimeSlot> _timeSlots;

  @override
  void initState() {
    super.initState();
    _morningSections = widget.morningSections;
    _afternoonSections = widget.afternoonSections;
    _eveningSections = widget.eveningSections;
    _courseDuration = widget.initialCourseDuration;
    _breakDuration = widget.initialBreakDuration;
    _autoSyncTime = widget.initialAutoSyncTime;
    _timeSlots = List.from(widget.initialTimeSlots);
  }

  void _autoSave() {
    final currentConfig = courseProvider.scheduleConfig.value;
    final config = currentConfig.copyWith(
      morningSections: _morningSections,
      afternoonSections: _afternoonSections,
      eveningSections: _eveningSections,
      courseDuration: _courseDuration,
      breakDuration: _breakDuration,
      autoSyncTime: _autoSyncTime,
      timeSlots: _timeSlots,
    );
    courseProvider.updateScheduleConfig(config);
  }

  void _syncFollowingSlots(int index) {
    int endIdx = 0;

    if (index < _morningSections) {
      endIdx = _morningSections;
    } else if (index < _morningSections + _afternoonSections) {
      endIdx = _morningSections + _afternoonSections;
    } else {
      endIdx = _morningSections + _afternoonSections + _eveningSections;
    }

    for (int i = index + 1; i < endIdx; i++) {
      if (i >= _timeSlots.length) break;

      final prevSlot = _timeSlots[i - 1];
      int startMin = prevSlot.endTime.minute + _breakDuration;
      int startHour = prevSlot.endTime.hour + (startMin ~/ 60);
      startMin = startMin % 60;

      int endMin = startMin + _courseDuration;
      int endHour = startHour + (endMin ~/ 60);
      endMin = endMin % 60;

      _timeSlots[i] = TimeSlot(
        startTime: TimeOfDay(hour: startHour % 24, minute: startMin),
        endTime: TimeOfDay(hour: endHour % 24, minute: endMin),
      );
    }
  }

  void _adjustTimeSlots() {
    final totalSections =
        _morningSections + _afternoonSections + _eveningSections;

    while (_timeSlots.length < totalSections) {
      // Just append a dummy slot, the user or sync logic can adjust it
      final hour = 8 + _timeSlots.length;
      _timeSlots.add(
        TimeSlot(
          startTime: TimeOfDay(hour: hour % 24, minute: 0),
          endTime: TimeOfDay(hour: hour % 24, minute: 45),
        ),
      );
    }
    if (_timeSlots.length > totalSections) {
      _timeSlots = _timeSlots.sublist(0, totalSections);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.timeSlot)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section count settings
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.sectionCount,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            _buildSectionCounter(l10n.morning, _morningSections, (v) {
              setState(() {
                _morningSections = v;
                _adjustTimeSlots();
              });
              _autoSave();
            }),
            _buildSectionCounter(l10n.afternoon, _afternoonSections, (v) {
              setState(() {
                _afternoonSections = v;
                _adjustTimeSlots();
              });
              _autoSave();
            }),
            _buildSectionCounter(l10n.evening, _eveningSections, (v) {
              setState(() {
                _eveningSections = v;
                _adjustTimeSlots();
              });
              _autoSave();
            }),
            const Divider(height: 32),
            SwitchListTile(
              title: Text(l10n.autoSyncTime),
              value: _autoSyncTime,
              onChanged: (v) {
                setState(() => _autoSyncTime = v);
                _autoSave();
              },
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            Row(
              spacing: 16,
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _courseDuration.toString(),
                    decoration: InputDecoration(
                      labelText: l10n.courseDuration,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final val = int.tryParse(v);
                      if (val != null && val > 0) {
                        _courseDuration = val;
                        _autoSave();
                      }
                    },
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: _breakDuration.toString(),
                    decoration: InputDecoration(
                      labelText: l10n.breakDuration,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final val = int.tryParse(v);
                      if (val != null && val >= 0) {
                        _breakDuration = val;
                        _autoSave();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(_timeSlots.length, (i) {
              String groupTitle = '';
              if (i == 0) {
                groupTitle = l10n.morning;
              } else if (i == _morningSections) {
                groupTitle = l10n.afternoon;
              } else if (i == _morningSections + _afternoonSections) {
                groupTitle = l10n.evening;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (groupTitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        groupTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  _TimeSlotEditor(
                    index: i,
                    slot: _timeSlots[i],
                    onChanged: (slot, isStart) {
                      setState(() {
                        if (isStart && _autoSyncTime) {
                          int endMin = slot.startTime.minute + _courseDuration;
                          int endHour = slot.startTime.hour + (endMin ~/ 60);
                          _timeSlots[i] = slot.copyWith(
                            endTime: TimeOfDay(
                              hour: endHour % 24,
                              minute: endMin % 60,
                            ),
                          );
                        } else {
                          _timeSlots[i] = slot;
                        }

                        if (_autoSyncTime) {
                          _syncFollowingSlots(i);
                        }
                      });
                      _autoSave();
                    },
                  ),
                ],
              );
            }),
            const Divider(height: 32),
            // Quick set section
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '快速设置',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('四川大学江安校区'),
              subtitle: const Text('自动设置 4-5-3 节数及对应时间点'),
              trailing: const Icon(Icons.auto_fix_high),
              onTap: () {
                setState(() {
                  _morningSections = 4;
                  _afternoonSections = 5;
                  _eveningSections = 3;
                  // Use the hardcoded default logic for 4-5-3
                  _timeSlots = [
                    // Morning
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 8, minute: 15),
                      endTime: TimeOfDay(hour: 9, minute: 0),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 9, minute: 10),
                      endTime: TimeOfDay(hour: 9, minute: 55),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 10, minute: 15),
                      endTime: TimeOfDay(hour: 11, minute: 0),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 11, minute: 10),
                      endTime: TimeOfDay(hour: 11, minute: 55),
                    ),
                    // Afternoon
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 13, minute: 50),
                      endTime: TimeOfDay(hour: 14, minute: 35),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 14, minute: 45),
                      endTime: TimeOfDay(hour: 15, minute: 30),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 15, minute: 40),
                      endTime: TimeOfDay(hour: 16, minute: 25),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 16, minute: 45),
                      endTime: TimeOfDay(hour: 17, minute: 30),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 17, minute: 40),
                      endTime: TimeOfDay(hour: 18, minute: 25),
                    ),
                    // Evening
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 19, minute: 20),
                      endTime: TimeOfDay(hour: 20, minute: 5),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 20, minute: 15),
                      endTime: TimeOfDay(hour: 21, minute: 0),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 21, minute: 10),
                      endTime: TimeOfDay(hour: 21, minute: 55),
                    ),
                  ];
                });
                _autoSave();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已应用四川大学江安校区时间表预设')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCounter(
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 32,
          child: Center(
            child: Text(
              '$value',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: value < 10 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _TimeSlotEditor extends StatelessWidget {
  final int index;
  final TimeSlot slot;
  final void Function(TimeSlot slot, bool isStart) onChanged;

  const _TimeSlotEditor({
    required this.index,
    required this.slot,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final startStr = _formatTime(slot.startTime);
    final endStr = _formatTime(slot.endTime);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _pickTime(context, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(startStr),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('-'),
                ),
                GestureDetector(
                  onTap: () => _pickTime(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(endStr),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 64),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? slot.startTime : slot.endTime,
    );
    if (picked != null) {
      onChanged(
        slot.copyWith(
          startTime: isStart ? picked : null,
          endTime: isStart ? null : picked,
        ),
        isStart,
      );
    }
  }
}
