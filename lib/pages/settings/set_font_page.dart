import 'package:material_ui/material_ui.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

class SetFontPage extends StatelessWidget {
  const SetFontPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.setFont)),
      body: ListenableBuilder(
        listenable: appConfig.useGoogleFonts,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            SwitchListTile(
              title: Text(localizations.useGoogleFonts),
              subtitle: const Text('Noto Sans SC'),
              value: appConfig.useGoogleFonts.value,
              onChanged: (v) => appConfig.useGoogleFonts.value = v,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                localizations.fontHint,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
