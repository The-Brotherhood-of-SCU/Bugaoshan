import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/exit_service.dart';
import 'package:bugaoshan/widgets/eula_content.dart';

/// 显示 EULA 同意对话框
/// 返回 true 表示用户同意，false 表示不同意
Future<bool> showEulaDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const EulaDialog(),
  );
  return result ?? false;
}

/// 检查并确保用户已同意 EULA
/// 返回 true 表示可以继续，false 表示已退出应用
Future<bool> ensureEulaAgreement(BuildContext context) async {
  try {
    final appConfig = getIt<AppConfigProvider>();
    if (appConfig.acceptedEulaVersion.value >= currentEulaVersion) return true;
    final agreed = await showEulaDialog(context);
    if (agreed) {
      appConfig.acceptedEulaVersion.value = currentEulaVersion;
      return true;
    } else {
      await getIt<ExitService>().exitApp();
      return false;
    }
  } catch (e) {
    debugPrint('EULA check error: $e');
    return true;
  }
}

class EulaDialog extends StatefulWidget {
  const EulaDialog({super.key});

  @override
  State<EulaDialog> createState() => _EulaDialogState();
}

class _EulaDialogState extends State<EulaDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenWidth > 600 ? 500 : screenWidth * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.eulaTitle,
                style: colorScheme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: EulaContent(
                  onAgreedChanged: (agreed) {
                    setState(() => _agreed = agreed);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.eulaDisagree),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _agreed
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    child: Text(l10n.eulaAgree),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
