import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/exit_service.dart';
import 'package:bugaoshan/widgets/eula_content.dart';

/// 显示 EULA 同意对话框
/// 同意则自动更新 AppConfigProvider，不同意则退出应用
Future<bool> showEulaDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const EulaDialog(),
  );
  return result ?? false;
}

/// 检查并确保用户已同意 EULA，未同意时弹窗处理
Future<void> ensureEulaAgreement(BuildContext context) async {
  final appConfig = getIt<AppConfigProvider>();
  if (appConfig.acceptedEulaVersion.value >= currentEulaVersion) return;
  await showEulaDialog(context);
}

class EulaDialog extends StatefulWidget {
  const EulaDialog({super.key});

  @override
  State<EulaDialog> createState() => _EulaDialogState();
}

class _EulaDialogState extends State<EulaDialog> {
  bool _agreed = false;

  void _onAgree() {
    getIt<AppConfigProvider>().acceptedEulaVersion.value = currentEulaVersion;
    Navigator.of(context).pop(true);
  }

  Future<void> _onDisagree() async {
    await getIt<ExitService>().exitApp();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      child: Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth > 600 ? 560 : screenWidth * 0.94,
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.eulaTitle,
                  style: colorScheme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: EulaContent(
                    onAgreedChanged: (agreed) {
                      setState(() => _agreed = agreed);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GlassButton.custom(
                      onTap: _onDisagree,
                      width: 100,
                      height: 40,
                      child: Text(
                        l10n.eulaDisagree,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlassButton.custom(
                      onTap: _agreed ? _onAgree : () {},
                      width: 100,
                      height: 40,
                      enabled: _agreed,
                      child: Text(
                        l10n.eulaAgree,
                        style: TextStyle(
                          color: _agreed ? Colors.white : Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
