import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

/// 深色模式设置页：跟随系统 / 浅色 / 深色，点选后立即生效并持久化。
/// 每个选项渲染一张迷你界面预览卡，「跟随系统」左右分屏展示浅深两种外观。
class SetThemeModePage extends StatelessWidget {
  const SetThemeModePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.darkMode)),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: appConfig.themeMode,
        builder: (context, mode, _) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Row(
              children: [
                _ThemeModeCard(
                  selected: mode == ThemeMode.system,
                  // 用较短的 "System"/「跟随系统」词条，避免窄卡内文字溢出
                  label: l10n.themeColorModeSystem,
                  previews: const [Brightness.light, Brightness.dark],
                  onTap: () => appConfig.themeMode.value = ThemeMode.system,
                ),
                const SizedBox(width: 10),
                _ThemeModeCard(
                  selected: mode == ThemeMode.light,
                  label: l10n.themeModeLight,
                  previews: const [Brightness.light],
                  onTap: () => appConfig.themeMode.value = ThemeMode.light,
                ),
                const SizedBox(width: 10),
                _ThemeModeCard(
                  selected: mode == ThemeMode.dark,
                  label: l10n.themeModeDark,
                  previews: const [Brightness.dark],
                  onTap: () => appConfig.themeMode.value = ThemeMode.dark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  final bool selected;
  final String label;
  final List<Brightness> previews;
  final VoidCallback onTap;

  const _ThemeModeCard({
    required this.selected,
    required this.label,
    required this.previews,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: appCurve,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              _MockupPreview(previews: previews),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                  // 选中时才显示对勾占位，避免未选中时文字偏移
                  if (selected) const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: selected ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 迷你界面预览：按传入的亮度列表平铺（1 个 = 单一模式，2 个 = 跟随系统分屏）。
class _MockupPreview extends StatelessWidget {
  final List<Brightness> previews;

  const _MockupPreview({required this.previews});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final brightness in previews)
                Expanded(
                  child: _MockupContent(
                    scheme: ColorScheme.fromSeed(
                      seedColor: colorScheme.primary,
                      brightness: brightness,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 用容器拼出的抽象应用界面：顶栏 + 三行内容 + 右下角悬浮按钮。
class _MockupContent extends StatelessWidget {
  final ColorScheme scheme;

  const _MockupContent({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.all(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(child: _bar(scheme, 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          _bar(scheme, 0.92),
          const SizedBox(height: 5),
          _bar(scheme, 0.72),
          const SizedBox(height: 5),
          _bar(scheme, 0.82),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _bar(ColorScheme scheme, double widthFactor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: 5,
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
