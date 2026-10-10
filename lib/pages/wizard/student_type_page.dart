import 'package:flutter/material.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/common/student_type_selector.dart';

/// 引导页身份选择步骤：本科生 / 研究生。
///
/// 选择立即写入 [AppConfigProvider.studentType]（默认本科生），
/// 决定后续登录步骤的课表导入入口与校园页功能分区。
/// 选择卡片复用公共组件 [StudentTypeSelector]，与设置页保持一致。
class StudentTypePage extends StatelessWidget {
  const StudentTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
            ),
            child: Icon(
              Icons.badge_rounded,
              size: 36,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.wizardStudentTypeTitle,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.wizardStudentTypeDesc,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ValueListenableBuilder<StudentType>(
            valueListenable: appConfig.studentType,
            builder: (context, studentType, _) => StudentTypeSelector(
              value: studentType,
              onChanged: (type) => appConfig.studentType.value = type,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
