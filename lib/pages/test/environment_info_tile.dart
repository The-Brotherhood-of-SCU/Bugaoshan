import 'package:flutter/material.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/test/environment_info_page.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

/// TestPage 入口：环境信息。
class EnvironmentInfoTile extends StatelessWidget {
  const EnvironmentInfoTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: Text(l10n.environmentInfo),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => popupOrNavigate(context, const EnvironmentInfoPage()),
    );
  }
}
