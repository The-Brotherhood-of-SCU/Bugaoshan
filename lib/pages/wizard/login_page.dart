import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/pages/course/import/import_schedule_page.dart';
import 'package:bugaoshan/pages/graduate/schedule_import_page.dart';
import 'package:bugaoshan/pages/auth/scu_login_page.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/course/course_pods.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  /// 课表导入入口随学生身份切换：本科生走教务在线拉取，研究生走研究生系统。
  void _openImportPage() {
    final studentType = ref.read(studentTypeSettingProvider);
    if (studentType == StudentType.graduate) {
      popupOrNavigate(context, const GraduateScheduleImportPage());
      return;
    }
    popupOrNavigate(
      context,
      ImportSchedulePage(
        courseProvider: ref.read(courseProviderBridge),
        mode: ImportMode.online,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final authProvider = ref.watch(scuAuthProviderBridge);
    final hasSchedule = ref.watch(hasScheduleProvider);

    final checkedIcon = Icon(
      Icons.check_circle,
      size: 18,
      color: colorScheme.primary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
              Icons.login_rounded,
              size: 36,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.wizardLoginTitle,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _StepCard(
            step: '1',
            icon: Icons.login_rounded,
            title: l10n.wizardLoginStep1,
            trailing: authProvider.isLoggedIn
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      checkedIcon,
                      const SizedBox(width: 4),
                      Text(
                        l10n.wizardLoginDone,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  )
                : FilledButton.tonal(
                    onPressed: () async {
                      await popupOrNavigate(
                        context,
                        const ScuLoginPage(),
                      );
                    },
                    child: Text(l10n.wizardLoginButton),
                  ),
          ),
          const SizedBox(height: 12),
          _StepCard(
            step: '2',
            icon: Icons.download_rounded,
            title: l10n.wizardLoginStep2,
            subtitle: l10n.wizardImportHint,
            trailing: FilledButton.tonal(
              onPressed: _openImportPage,
              child: hasSchedule
                  ? Row(
                      children: [
                        checkedIcon,
                        const SizedBox(width: 4),
                        Text(l10n.wizardHasSchedule),
                      ],
                    )
                  : Text(l10n.wizardImportButton),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;

  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppShapes.medium),
              ),
              child: Center(
                child: Text(
                  step,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: textTheme.bodyLarge),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
