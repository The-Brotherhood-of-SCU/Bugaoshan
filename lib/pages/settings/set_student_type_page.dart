import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/common/info_card.dart';

/// 学生类型（本科生 / 研究生）切换页。
///
/// 切换立即生效并持久化：课表导入入口与校园页功能分区随之调整，
/// 不改动已保存的课表与 dock 自定义配置。
class SetStudentTypePage extends StatelessWidget {
  const SetStudentTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.studentTypeSetting)),
      body: ListenableBuilder(
        listenable: appConfig.studentType,
        builder: (context, _) {
          final studentType = appConfig.studentType.value;
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 8.0,
                ),
                child: SegmentedButton<StudentType>(
                  segments: [
                    ButtonSegment<StudentType>(
                      value: StudentType.undergraduate,
                      label: Text(l10n.studentTypeUndergraduate),
                      icon: const Icon(Icons.school_outlined),
                    ),
                    ButtonSegment<StudentType>(
                      value: StudentType.graduate,
                      label: Text(l10n.studentTypeGraduate),
                      icon: const Icon(Icons.cast_for_education_outlined),
                    ),
                  ],
                  selected: {studentType},
                  onSelectionChanged: (selection) {
                    appConfig.studentType.value = selection.first;
                  },
                ),
              ),
              const SizedBox(height: 12),
              InfoCard(
                children: [
                  ListTile(
                    leading: Icon(
                      studentType == StudentType.graduate
                          ? Icons.cast_for_education_outlined
                          : Icons.school_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      studentType == StudentType.graduate
                          ? l10n.studentTypeGraduateDesc
                          : l10n.studentTypeUndergraduateDesc,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  l10n.studentTypeHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
