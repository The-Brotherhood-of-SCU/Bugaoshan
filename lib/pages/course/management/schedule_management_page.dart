import 'dart:async';

import 'package:bugaoshan/widgets/common/third_center.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import '../import/import_source_sheet.dart';
import 'prompt_new_schedule.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/riverpod/course/course_pods.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/utils/export_schedule_utils.dart';

export 'prompt_new_schedule.dart';

class ScheduleManagementPage extends ConsumerWidget {
  const ScheduleManagementPage({super.key});

  void _onImport(BuildContext context, CourseProvider courseProvider) {
    showScheduleImportSheet(context, courseProvider: courseProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final courseProv = ref.watch(courseProvider);
    final allSchedules = ref.watch(allSchedulesProvider);
    final currentId = ref.watch(currentScheduleConfigProvider)?.id;

    return ScaffoldMessenger(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.scheduleManagement),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _onImport(context, courseProv),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () =>
                  promptForNewScheduleConfig(context, courseProv),
            ),
          ],
        ),
        body: allSchedules.isEmpty
            ? ThirdCenter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noSchedule,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
              itemCount: allSchedules.length,
              itemBuilder: (context, index) {
                final schedule = allSchedules[index];
                final isCurrent = currentId != null && schedule.id == currentId;
                return ListTile(
                  leading: Icon(
                    isCurrent ? Icons.check_circle : Icons.circle_outlined,
                    color: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  title: Text(
                    schedule.semesterName.isEmpty
                        ? l10n.defaultScheduleName
                        : schedule.semesterName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    l10n.totalWeeksSubtitle(schedule.totalWeeks),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    await courseProv.switchSchedule(schedule.id);
                    if (navigator.canPop()) {
                      navigator.pop();
                    }
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () => showExportScheduleSheet(
                          context,
                          schedule: schedule,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final controller = TextEditingController(
                            text: schedule.semesterName,
                          );
                          final newName = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(l10n.semesterName),
                              content: TextField(
                                controller: controller,
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: l10n.semesterName,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(l10n.cancel),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(
                                    context,
                                    controller.text.trim(),
                                  ),
                                  child: Text(l10n.save),
                                ),
                              ],
                            ),
                          );

                          if (newName != null && newName.isNotEmpty) {
                            if (courseProv.isScheduleNameTaken(
                              newName,
                              excludeId: schedule.id,
                            )) {
                              if (context.mounted) {
                                unawaited(
                                  showInfoDialog(
                                    title: l10n.duplicateScheduleName,
                                    content: '',
                                  ),
                                );
                              }
                              return;
                            }
                            final updatedConfig = schedule.copyWith(
                              semesterName: newName,
                            );
                            await courseProv.updateScheduleConfig(
                              updatedConfig,
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final confirm = await showYesNoDialog(
                            title: l10n.delete,
                            content: l10n.deleteScheduleConfirm(
                              schedule.semesterName,
                            ),
                          );
                          if (confirm == true) {
                            await courseProv.deleteSchedule(schedule.id);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      ),
    );
  }
}
