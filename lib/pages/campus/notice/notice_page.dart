import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/notice/jwc/campus_notice_page.dart';
import 'package:bugaoshan/pages/campus/notice/xgb/party_notice_page.dart';
import 'package:bugaoshan/pages/campus/notice/tuanwei/tuanwei_notice_page.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class NoticePage extends StatelessWidget {
  const NoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.noticeSection)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _NoticeCard(
            icon: Icons.campaign,
            title: l10n.campusNotices,
            desc: l10n.campusNoticesDesc,
            onTap: () => popupOrNavigate(
              logicRootContext,
              const CampusNoticePage(),
            ),
          ),
          const SizedBox(height: 8),
          _NoticeCard(
            icon: Icons.flag,
            title: l10n.partyNotice,
            desc: l10n.partyNoticeDesc,
            onTap: () => popupOrNavigate(
              logicRootContext,
              const PartyNoticePage(),
            ),
          ),
          const SizedBox(height: 8),
          _NoticeCard(
            icon: Icons.volunteer_activism,
            title: l10n.tuanweiNotice,
            desc: l10n.tuanweiNoticeDesc,
            onTap: () => popupOrNavigate(
              logicRootContext,
              const TuanweiNoticePage(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;

  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(desc),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
