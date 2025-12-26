import 'package:flutter/material.dart';
import 'package:rubbish_plan/l10n/app_localizations.dart';
import 'package:rubbish_plan/pages/software_setting_page.dart';
import 'package:rubbish_plan/widgets/common/styled_widget.dart';
import 'package:rubbish_plan/widgets/route/router_utils.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final body = Column(
      spacing: 16,
      children: [
        SizedBox(height: 16),
        ButtonWithMaxWidth(
          onPressed: () {
            popupOrNavigate(context, SoftwareSettingPage());
          },
          icon: Icon(Icons.settings),
          child: Text(localizations.softwareSetting),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: body,
    );
  }
}
