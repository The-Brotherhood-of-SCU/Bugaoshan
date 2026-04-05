import 'package:flutter/material.dart';
import 'package:rubbish_plan/l10n/app_localizations.dart';
import 'package:rubbish_plan/pages/about_page.dart';
import 'package:rubbish_plan/pages/course_schedule_setting.dart';
import 'package:rubbish_plan/pages/schedule_management_page.dart';
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
          icon: Icon(Icons.list_alt),
          onPressed: () {
            popupOrNavigate(context, const ScheduleManagementPage());
          },
          child: Text(localizations.scheduleManagement),
        ),
        ButtonWithMaxWidth(
          icon: Icon(Icons.schedule),
          onPressed: () {
            popupOrNavigate(context, CourseScheduleSetting());
          },
          child: Text(localizations.scheduleSetting),
        ),
        ButtonWithMaxWidth(
          onPressed: () {
            popupOrNavigate(context, SoftwareSettingPage());
          },
          icon: Icon(Icons.settings),
          child: Text(localizations.softwareSetting),
        ),
        ButtonWithMaxWidth(
          onPressed: () {
            popupOrNavigate(context, AboutPage());
          },
          icon: Icon(Icons.info_outline),
          child: Text(localizations.about),
        ),
      ],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: body,
        ),
      ),
    );
  }
}
