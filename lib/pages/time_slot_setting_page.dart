import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';

class TimeSlotSettingPage extends StatefulWidget {
  final List<TimeSlot> initialMorningSlots;
  final List<TimeSlot> initialAfternoonSlots;
  final List<TimeSlot> initialEveningSlots;
  final int initialCourseDuration;
  final int initialBreakDuration;
  final bool initialAutoSyncTime;

  const TimeSlotSettingPage({
    super.key,
    required this.initialMorningSlots,
    required this.initialAfternoonSlots,
    required this.initialEveningSlots,
    required this.initialCourseDuration,
    required this.initialBreakDuration,
    required this.initialAutoSyncTime,
  });

  @override
  State<TimeSlotSettingPage> createState() => _TimeSlotSettingPageState();
}

class _TimeSlotSettingPageState extends State<TimeSlotSettingPage> {
  final courseProvider = getIt<CourseProvider>();
  late List<TimeSlot> _morningSlots;
  late List<TimeSlot> _afternoonSlots;
  late List<TimeSlot> _eveningSlots;
  late int _courseDuration;
  late int _breakDuration;
  late bool _autoSyncTime;

  List<TimeSlot> get _timeSlots => [
        ..._morningSlots,
        ..._afternoonSlots,
        ..._eveningSlots,
      ];

  set _timeSlots(List<TimeSlot> flatList) {
    int mLen = _morningSlots.length;
    int aLen = _afternoonSlots.length;
    int eLen = _eveningSlots.length;

    _morningSlots = flatList.sublist(0, mLen);
    _afternoonSlots = flatList.sublist(mLen, mLen + aLen);
    _eveningSlots = flatList.sublist(mLen + aLen, mLen + aLen + eLen);
  }

  int get _morningSections => _morningSlots.length;
  int get _afternoonSections => _afternoonSlots.length;
  int get _eveningSections => _eveningSlots.length;

  @override
  void initState() {
    super.initState();
    _morningSlots = List.from(widget.initialMorningSlots);
    _afternoonSlots = List.from(widget.initialAfternoonSlots);
    _eveningSlots = List.from(widget.initialEveningSlots);
    _courseDuration = widget.initialCourseDuration;
    _breakDuration = widget.initialBreakDuration;
    _autoSyncTime = widget.initialAutoSyncTime;
  }

  void _autoSave() {
    final currentConfig = courseProvider.scheduleConfig.value;
    final config = currentConfig.copyWith(
      morningSlots: _morningSlots,
      afternoonSlots: _afternoonSlots,
      eveningSlots: _eveningSlots,
      courseDuration: _courseDuration,
      breakDuration: _breakDuration,
      autoSyncTime: _autoSyncTime,
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

    final flat = _timeSlots;
    for (int i = index + 1; i < endIdx; i++) {
      if (i >= flat.length) break;

      final prevSlot = flat[i - 1];
      int startMin = prevSlot.endTime.minute + _breakDuration;
      int startHour = prevSlot.endTime.hour + (startMin ~/ 60);
      startMin = startMin % 60;

      int endMin = startMin + _courseDuration;
      int endHour = startHour + (endMin ~/ 60);
      endMin = endMin % 60;

      flat[i] = TimeSlot(
        startTime: TimeOfDay(hour: startHour % 24, minute: startMin),
        endTime: TimeOfDay(hour: endHour % 24, minute: endMin),
      );
    }
    _timeSlots = flat;
  }

  void _adjustSlotList(List<TimeSlot> list, int newLength) {
    while (list.length < newLength) {
      final hour = 8 + _timeSlots.length;
      list.add(
        TimeSlot(
          startTime: TimeOfDay(hour: hour % 24, minute: 0),
          endTime: TimeOfDay(hour: hour % 24, minute: _courseDuration),
        ),
      );
    }
    if (list.length > newLength) {
      list.removeRange(newLength, list.length);
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
                _adjustSlotList(_morningSlots, v);
              });
              _autoSave();
            }),
            _buildSectionCounter(l10n.afternoon, _afternoonSections, (v) {
              setState(() {
                _adjustSlotList(_afternoonSlots, v);
              });
              _autoSave();
            }),
            _buildSectionCounter(l10n.evening, _eveningSections, (v) {
              setState(() {
                _adjustSlotList(_eveningSlots, v);
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
                        final flat = _timeSlots;
                        if (isStart && _autoSyncTime) {
                          int endMin = slot.startTime.minute + _courseDuration;
                          int endHour = slot.startTime.hour + (endMin ~/ 60);
                          flat[i] = slot.copyWith(
                            endTime: TimeOfDay(
                              hour: endHour % 24,
                              minute: endMin % 60,
                            ),
                          );
                        } else {
                          flat[i] = slot;
                        }
                        _timeSlots = flat;

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
                  _morningSlots = [
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
                  ];
                  _afternoonSlots = [
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
                  ];
                  _eveningSlots = [
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('四川大学望江/华西校区'),
              subtitle: const Text('自动设置 4-5-3 节数及对应时间点'),
              trailing: const Icon(Icons.auto_fix_high),
              onTap: () {
                setState(() {
                  _morningSlots = [
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 8, minute: 0),
                      endTime: TimeOfDay(hour: 8, minute: 45),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 8, minute: 55),
                      endTime: TimeOfDay(hour: 9, minute: 40),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 10, minute: 0),
                      endTime: TimeOfDay(hour: 10, minute: 45),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 10, minute: 55),
                      endTime: TimeOfDay(hour: 11, minute: 40),
                    ),
                  ];
                  _afternoonSlots = [
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 14, minute: 0),
                      endTime: TimeOfDay(hour: 14, minute: 45),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 14, minute: 55),
                      endTime: TimeOfDay(hour: 15, minute: 40),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 15, minute: 50),
                      endTime: TimeOfDay(hour: 16, minute: 35),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 16, minute: 55),
                      endTime: TimeOfDay(hour: 17, minute: 40),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 17, minute: 50),
                      endTime: TimeOfDay(hour: 18, minute: 35),
                    ),
                  ];
                  _eveningSlots = [
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 19, minute: 30),
                      endTime: TimeOfDay(hour: 20, minute: 15),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 20, minute: 25),
                      endTime: TimeOfDay(hour: 21, minute: 10),
                    ),
                    const TimeSlot(
                      startTime: TimeOfDay(hour: 21, minute: 20),
                      endTime: TimeOfDay(hour: 22, minute: 5),
                    ),
                  ];
                });
                _autoSave();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已应用四川大学望江/华西校区时间表预设')),
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
