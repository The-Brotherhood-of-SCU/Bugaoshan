import 'package:bugaoshan/widgets/common/section_title.dart';
import 'package:flutter/material.dart';

import 'package:bugaoshan/pages/dev/live_activity_probe_view.dart';
import 'package:bugaoshan/pages/dev/reminder_probe_view.dart';
import 'package:bugaoshan/utils/system_insets.dart';

/// 开发者页面子页：探针合集。
///
/// 两条探针各自保持独立组件与状态（[ReminderProbeView] / [LiveActivityProbeView]），
/// 本页只负责把它们同时渲染出来，便于一次操作对照两端行为。
/// dev page 面向开发者，不做 i18n，标题文案直接硬编码。
class ProbePage extends StatelessWidget {
  const ProbePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification & Live Activity')),
      body: ListView(
        padding: withSystemBottomInset(context, const EdgeInsets.all(24)),
        children: const [
          SectionTitle(title: 'Reminder'),
          ReminderProbeView(),
          SizedBox(height: 18),
          SectionTitle(title: 'Live Activity'),
          LiveActivityProbeView(),
        ],
      ),
    );
  }
}
