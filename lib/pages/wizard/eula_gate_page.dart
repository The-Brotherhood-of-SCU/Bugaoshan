import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/exit_service.dart';
import 'package:bugaoshan/widgets/eula_content.dart';

class EulaGatePage extends StatefulWidget {
  const EulaGatePage({super.key});

  @override
  State<EulaGatePage> createState() => _EulaGatePageState();
}

class _EulaGatePageState extends State<EulaGatePage> {
  bool _agreed = false;

  void _onAgree() {
    getIt<AppConfigProvider>().acceptedEulaVersion.value = currentEulaVersion;
  }

  Future<void> _onDisagree() async {
    await getIt<ExitService>().exitApp();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.eulaTitle)),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: EulaContent(
                  onAgreedChanged: (agreed) {
                    setState(() => _agreed = agreed);
                  },
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _onDisagree,
                        child: Text(l10n.eulaDisagree),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _agreed ? _onAgree : null,
                        child: Text(l10n.eulaAgree),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
