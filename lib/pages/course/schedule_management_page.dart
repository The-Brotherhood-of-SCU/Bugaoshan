import 'package:bugaoshan/widgets/common/third_center.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/import_schedule_page.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:bugaoshan/utils/export_schedule_utils.dart';
import 'package:bugaoshan/utils/app_shapes.dart';

/// 弹窗让用户输入新课表名称，校验重名后通过 [courseProvider.addSchedule] 添加。
/// 复用当前选中的课表配置（timeSlots 等）作为模板。
/// 供 [ScheduleManagementPage] 的 AppBar `+` 按钮和 [CoursePage] 空状态视图调用。
Future<void> promptForNewScheduleConfig(
  BuildContext context,
  CourseProvider courseProvider,
) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  final newName = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.semesterName),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.semesterName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            final t = controller.text.trim();
            if (t.isNotEmpty) Navigator.pop(ctx, t);
          },
          child: Text(l10n.save),
        ),
      ],
    ),
  );

  if (newName == null || newName.isEmpty) return;
  if (!context.mounted) return;

  if (courseProvider.isScheduleNameTaken(newName)) {
    showInfoDialog(title: l10n.duplicateScheduleName, content: '');
    return;
  }

  // 复用当前选中的课表配置（timeSlots 等）作为模板
  final currentConfig = courseProvider.scheduleConfig.value;
  final newConfig = currentConfig.copyWith(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    semesterName: newName,
    semesterStartDate: DateTime.now().toMonday(),
  );
  await courseProvider.addSchedule(newConfig);
}

class ScheduleManagementPage extends StatelessWidget {
  const ScheduleManagementPage({super.key});

  void _onImport(BuildContext context, CourseProvider courseProvider) {
    final l10n = AppLocalizations.of(context)!;
    final outerContext = context; // Capture the stable context
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppShapes.extraLarge),
        ),
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

    return ScaffoldMessenger(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.scheduleManagement),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _onImport(context, courseProvider),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () =>
                  promptForNewScheduleConfig(context, courseProvider),
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

            if (allSchedules.isEmpty) {
              return ThirdCenter(
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
              );
            }

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
                    Navigator.pop(context);
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.send_outlined),
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
      ),
    );
  }
}
