part of 'course_page.dart';

/// 课表为空时显示的占位视图：图标 + 「暂无课表」+ 「课表管理」/「导入课表」/「新建课表」按钮。
class _NoScheduleView extends StatelessWidget {
  final VoidCallback onOpenManagement;
  final VoidCallback onImport;
  final VoidCallback onAddSchedule;

  const _NoScheduleView({
    required this.onOpenManagement,
    required this.onImport,
    required this.onAddSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 圆形 tint 图标背景，跟 wizard 流程的视觉语言一致
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: 48,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.noSchedule,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.noScheduleHint,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenManagement,
                  icon: const Icon(Icons.list_alt_rounded),
                  label: Text(l10n.scheduleManagement),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(l10n.importSchedule),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddSchedule,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addSchedule),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
