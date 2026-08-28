import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';

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
