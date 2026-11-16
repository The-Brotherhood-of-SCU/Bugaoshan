import 'package:flutter/material.dart';

import 'package:bugaoshan/pages/dev/probe_page.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

/// Dev 页入口：提醒排期 / 实时活动探针。
///
/// 两条探针同页渲染，见 [ProbePage]。
/// dev page 面向开发者，不做 i18n，文案直接硬编码。
class ProbeTile extends StatelessWidget {
  const ProbeTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.science_outlined),
      title: const Text('Notification & Live Activity'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => popupOrNavigate(context, const ProbePage()),
    );
  }
}
