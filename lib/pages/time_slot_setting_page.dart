import 'package:flutter/material.dart';
import 'package:rubbish_plan/l10n/app_localizations.dart';
import 'package:rubbish_plan/models/course.dart';
import 'package:rubbish_plan/widgets/route/router_utils.dart';

class TimeSlotSettingResult {
  final int courseDuration;
  final int breakDuration;
  final bool autoSyncTime;
  final List<TimeSlot> timeSlots;

  TimeSlotSettingResult({
    required this.courseDuration,
    required this.breakDuration,
    required this.autoSyncTime,
    required this.timeSlots,
  });
}

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
  late int _courseDuration;
  late int _breakDuration;
  late bool _autoSyncTime;
  late List<TimeSlot> _timeSlots;

  @override
  void initState() {
    super.initState();
    _courseDuration = widget.initialCourseDuration;
    _breakDuration = widget.initialBreakDuration;
    _autoSyncTime = widget.initialAutoSyncTime;
    _timeSlots = List.from(widget.initialTimeSlots);
  }

  void _syncFollowingSlots(int index) {
    int startIdx = 0;
    int endIdx = 0;
    
    if (index < widget.morningSections) {
      startIdx = 0;
      endIdx = widget.morningSections;
    } else if (index < widget.morningSections + widget.afternoonSections) {
      startIdx = widget.morningSections;
      endIdx = widget.morningSections + widget.afternoonSections;
    } else {
      startIdx = widget.morningSections + widget.afternoonSections;
      endIdx = widget.morningSections + widget.afternoonSections + widget.eveningSections;
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
        startTime: TimeOfDay(hour: startHour, minute: startMin),
        endTime: TimeOfDay(hour: endHour, minute: endMin),
      );
    }
  }

  void _save() {
    Navigator.pop(
      context,
      TimeSlotSettingResult(
        courseDuration: _courseDuration,
        breakDuration: _breakDuration,
        autoSyncTime: _autoSyncTime,
        timeSlots: _timeSlots,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.timeSlot),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text(l10n.autoSyncTime),
              value: _autoSyncTime,
              onChanged: (v) => setState(() => _autoSyncTime = v),
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
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(_timeSlots.length, (i) {
              return _TimeSlotEditor(
                index: i,
                slot: _timeSlots[i],
                onChanged: (slot, isStart) {
                  setState(() {
                    if (isStart && _autoSyncTime) {
                      int endMin = slot.startTime.minute + _courseDuration;
                      int endHour = slot.startTime.hour + (endMin ~/ 60);
                      _timeSlots[i] = slot.copyWith(
                        endTime: TimeOfDay(hour: endHour % 24, minute: endMin % 60),
                      );
                    } else {
                      _timeSlots[i] = slot;
                    }

                    if (_autoSyncTime) {
                      _syncFollowingSlots(i);
                    }
                  });
                },
              );
            }),
          ],
        ),
      ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
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