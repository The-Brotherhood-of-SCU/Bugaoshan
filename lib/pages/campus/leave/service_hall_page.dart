import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/leave/leave_application_page.dart';
import 'package:bugaoshan/pages/campus/leave/my_applications_page.dart';
import 'package:bugaoshan/pages/campus_page/list_card.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:flutter/material.dart';

/// 办事大厅入口页。
///
/// 列出可办理事项：
/// - **离校请假**（进入 [LeaveApplicationPage]）
/// - **我的申请**（进入 [MyApplicationsPage]）
///
/// 后续可按需追加返校报备、暑假离校、留校登记等事项（对应办事大厅
/// app_id 337 / 356 / 357）。
///
/// 入口卡片复用 [CampusListCard]，与校园页各功能入口保持一致的外观与尺寸。
class ServiceHallPage extends StatelessWidget {
  const ServiceHallPage({super.key});

  void _openLeave(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LeaveApplicationPage()),
    );
  }

  void _openMyApplications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyApplicationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.serviceHallTitle)),
      body: getIt<ScuAuthProvider>().isLoggedIn
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CampusListCard(
                  icon: Icons.fact_check_outlined,
                  title: l10n.serviceHallLeaveTitle,
                  desc: l10n.serviceHallLeaveDesc,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => _openLeave(context),
                ),
                const SizedBox(height: 12),
                CampusListCard(
                  icon: Icons.inbox_outlined,
                  title: l10n.serviceHallMyAppsTitle,
                  desc: l10n.serviceHallMyAppsDesc,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => _openMyApplications(context),
                ),
              ],
            )
          : const LoginRequiredWidget(),
    );
  }
}
