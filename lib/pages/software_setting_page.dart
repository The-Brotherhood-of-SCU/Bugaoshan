import 'package:flutter/material.dart';
import 'package:rubbish_plan/l10n/app_localizations.dart';
import 'package:rubbish_plan/pages/set_duration_page.dart';
import 'package:rubbish_plan/pages/set_language_page.dart';
import 'package:rubbish_plan/pages/set_theme_color_page.dart';
import 'package:rubbish_plan/widgets/common/styled_widget.dart';
import 'package:rubbish_plan/widgets/route/router_utils.dart';

class SoftwareSettingPage extends StatelessWidget {
  const SoftwareSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final content = Column(
      spacing: 16,
      children: [
        ButtonWithMaxWidth(
          onPressed: () {
            popupOrNavigate(context, SetLanguagePage());
          },
          icon: Icon(Icons.language),
          child: Text(localizations.modifyLanguage),
        ),
        ButtonWithMaxWidth(
          onPressed: () {
            popupOrNavigate(context, SetDurationPage());
          },
          icon: Icon(Icons.access_time),
          child: Text(localizations.animationDuration),
        ),
        ButtonWithMaxWidth(
          onPressed: () {
            popupOrNavigate(context, SetThemeColorPage());
          },
          icon: Icon(Icons.color_lens),
          child: Text(localizations.themeColor),
        ),
      ],
    );
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: content,
    );
    return Scaffold(
      appBar: AppBar(title: Text(localizations.softwareSetting)),
      body: body,
    );
  }
}
