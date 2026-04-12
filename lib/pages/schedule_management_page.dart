import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Bugaoshan/injection/injector.dart';
import 'package:Bugaoshan/l10n/app_localizations.dart';
import 'package:Bugaoshan/models/course.dart';
import 'package:Bugaoshan/pages/import_schedule_page.dart';
import 'package:Bugaoshan/providers/course_provider.dart';
import 'package:Bugaoshan/widgets/dialog/dialog.dart';
import 'package:Bugaoshan/widgets/route/router_utils.dart';

class ScheduleManagementPage extends StatelessWidget {
  const ScheduleManagementPage({super.key});

  void _onImport(BuildContext context, CourseProvider courseProvider) {
    final l10n = AppLocalizations.of(context)!;
    final outerContext = context; // Capture the stable context
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Text(
                  l10n.importSchedule,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.share),
                title: Text(l10n.importFromShare),
                onTap: () {
                  Navigator.pop(context);
                  popupOrNavigate(
                    outerContext,
                    ImportSchedulePage(
                      courseProvider: courseProvider,
                      mode: ImportMode.share,
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.school),
                title: Text(l10n.importFromJwxt),
                onTap: () {
                  Navigator.pop(context);
                  popupOrNavigate(
                    outerContext,
                    ImportSchedulePage(
                      courseProvider: courseProvider,
                      mode: ImportMode.jwxt,
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.cloud_download_outlined),
                title: Text(l10n.importFromJwxtOnline),
                onTap: () {
                  Navigator.pop(context);
                  popupOrNavigate(
                    outerContext,
                    ImportSchedulePage(
                      courseProvider: courseProvider,
                      mode: ImportMode.online,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final courseProvider = getIt<CourseProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scheduleManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _onImport(context, courseProvider),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final controller = TextEditingController();
              final newName = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.semesterName),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(hintText: l10n.semesterName),
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
                          Navigator.pop(context, text);
                        } else {
                          // Could optionally show a small snackbar/hint here
                          Navigator.pop(context);
                        }
                      },
                      child: Text(l10n.save),
                    ),
                  ],
                ),
              );

              if (newName != null && newName.isNotEmpty) {
                if (courseProvider.isScheduleNameTaken(newName)) {
                  if (context.mounted) {
                    showInfoDialog(
                      title: l10n.duplicateScheduleName,
                      content: '',
                    );
                  }
                  return;
                }

                // 复用当前选中的课表配置（TimeSlot 等）
                final currentConfig = courseProvider.scheduleConfig.value;
                final newConfig = currentConfig.copyWith(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  semesterName: newName,
                  semesterStartDate: DateTime.now().toMonday(),
                );
                await courseProvider.addSchedule(newConfig);
              }
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          courseProvider.allSchedules,
          courseProvider.scheduleConfig,
        ]),
        builder: (context, _) {
          final allSchedules = courseProvider.allSchedules.value;
          final currentId = courseProvider.scheduleConfig.value.id;

          return ListView.builder(
            itemCount: allSchedules.length,
            itemBuilder: (context, index) {
              final schedule = allSchedules[index];
              final isCurrent = schedule.id == currentId;
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
                ),
                subtitle: Text(l10n.totalWeeksSubtitle(schedule.totalWeeks)),
                onTap: () {
                  courseProvider.switchSchedule(schedule.id);
                  Navigator.pop(logicRootContext);
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.send_outlined),
                      onPressed: () async {
                        final courses = await courseProvider
                            .getCoursesForSchedule(schedule.id);
                        final data = {
                          'config': schedule.toJson(),
                          'courses': courses.map((e) => e.toJson()).toList(),
                        };
                        final jsonStr = json.encode(data);
                        await Clipboard.setData(ClipboardData(text: jsonStr));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.exportSuccess)),
                          );
                        }
                      },
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
                          if (courseProvider.isScheduleNameTaken(
                            newName,
                            excludeId: schedule.id,
                          )) {
                            if (context.mounted) {
                              showInfoDialog(
                                title: l10n.duplicateScheduleName,
                                content: '',
                              );
                            }
                            return;
                          }
                          final updatedConfig = schedule.copyWith(
                            semesterName: newName,
                          );
                          await courseProvider.updateScheduleConfig(
                            updatedConfig,
                          );
                        }
                      },
                    ),
                    if (allSchedules.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          final confirm = await showYesNoDialog(
                            title: l10n.delete,
                            content: l10n.deleteScheduleConfirm(
                              schedule.semesterName,
                            ),
                          );
                          if (confirm == true) {
                            await courseProvider.deleteSchedule(schedule.id);
                          }
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
