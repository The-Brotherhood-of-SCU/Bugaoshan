import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/service_hall/my_applications_page.dart';
import 'package:bugaoshan/pages/campus/service_hall/service_app_catalog.dart';
import 'package:bugaoshan/pages/campus/service_hall/service_form_page.dart';
import 'package:bugaoshan/pages/campus_page/list_card.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:material_ui/material_ui.dart';

/// 办事大厅入口页。
///
/// 列出 [kServiceAppCatalog] 中的可办理事项（离校请假 350 / 返校报备 337 /
/// 暑假离校 356 / 留校登记 357），点击进入 [ServiceFormPage] 通用动态表单页；
/// 底部为「我的申请」（[MyApplicationsPage]）。
///
/// 入口卡片复用 [CampusListCard]，与校园页各功能入口保持一致的外观与尺寸。
class ServiceHallPage extends StatelessWidget {
  const ServiceHallPage({super.key});

  void _openMatter(BuildContext context, ServiceAppInfo app) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ServiceFormPage(app: app)));
  }

  void _openMyApplications(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MyApplicationsPage()));
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
                for (final app in kServiceAppCatalog) ...[
                  CampusListCard(
                    icon: app.icon,
                    title: app.title(l10n),
                    desc: app.desc(l10n),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onTap: () => _openMatter(context, app),
                  ),
                  const SizedBox(height: 12),
                ],
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
