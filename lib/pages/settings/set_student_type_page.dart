import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/widgets/common/student_type_selector.dart';
import 'package:bugaoshan/utils/system_insets.dart';

/// 学生类型（本科生 / 研究生）切换页。
///
/// 切换立即生效并持久化：课表导入入口与校园页功能分区随之调整，
/// 不改动已保存的课表与 dock 自定义配置。
/// 选择卡片复用公共组件 [StudentTypeSelector]，与引导页保持一致。
class SetStudentTypePage extends ConsumerWidget {
  const SetStudentTypePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final studentType = ref.watch(studentTypeSettingProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.studentTypeSetting)),
      body: ListView(
        padding: withSystemBottomInset(
          context,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        children: [
          StudentTypeSelector(
            value: studentType,
            onChanged: (type) =>
                ref.read(studentTypeSettingProvider.notifier).update(type),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              l10n.studentTypeHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
