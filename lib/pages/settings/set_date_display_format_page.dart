import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/date_display_format.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/system_insets.dart';

/// 课表日期格式设置页：下拉选择一种完整日期格式，立即生效并持久化。
///
/// 顶栏显示完整日期，表头窄列只取其中的月/日片段，两者共用同一顺序与
/// 分隔符，避免两处显示成两种格式。
class SetDateDisplayFormatPage extends StatelessWidget {
  const SetDateDisplayFormatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();
    final theme = Theme.of(context);
    // 用今天的日期做示例，用户不必切到课表页就能看出顺序与分隔符。
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dateFormatSetting)),
      body: ValueListenableBuilder<DateDisplayFormat>(
        valueListenable: appConfig.dateDisplayFormat,
        builder: (context, format, _) => ListView(
          padding: withSystemBottomInset(
            context,
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          children: [
            DropdownButtonFormField<DateDisplayFormat>(
              initialValue: format,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.dateFormatLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final option in DateDisplayFormat.values)
                  DropdownMenuItem(
                    value: option,
                    child: Text(option.formatFull(today)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) appConfig.dateDisplayFormat.value = value;
              },
            ),
            const SizedBox(height: 16),
            Text(
              l10n.dateFormatSamples(
                format.formatFull(today),
                format.formatMonthDay(today),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.dateFormatHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
