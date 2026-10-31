import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/providers/set_theme_color_provider.dart';
import 'package:bugaoshan/utils/system_insets.dart';
import 'package:system_theme/system_theme.dart';

class SetThemeColorPage extends ConsumerStatefulWidget {
  const SetThemeColorPage({super.key});

  @override
  ConsumerState<SetThemeColorPage> createState() => _SetThemeColorPageState();
}

class _SetThemeColorPageState extends ConsumerState<SetThemeColorPage> {
  late final SetThemeColorProvider _themeColorProvider;

  late Color pickerColor;
  late ThemeColorMode _selectedMode;
  ColorScheme? colorScheme;

  @override
  void initState() {
    super.initState();
    _themeColorProvider = SetThemeColorProvider(
      getBackgroundImagePath: () => ref.read(backgroundImagePathSettingProvider),
      getThemeColorMode: () => ref.read(themeColorModeSettingProvider),
      getThemeColor: () => ref.read(themeColorSettingProvider),
    );
    _selectedMode = ref.read(themeColorModeSettingProvider);
    if (_selectedMode == ThemeColorMode.system) {
      pickerColor = SystemTheme.accentColor.accent;
    } else {
      pickerColor = ref.read(themeColorSettingProvider);
    }
  }

  void changeColor(Color color) {
    setState(() {
      pickerColor = color;
      colorScheme = ColorScheme.fromSeed(
        seedColor: pickerColor,
        brightness: Theme.of(context).brightness,
      );
    });
    if (_selectedMode != ThemeColorMode.custom) {
      setState(() {
        _selectedMode = ThemeColorMode.custom;
      });
    }
  }

  void _onModeChanged(ThemeColorMode? mode) async {
    if (mode == null) return;
    setState(() {
      _selectedMode = mode;
    });
    switch (mode) {
      case ThemeColorMode.system:
        await _handleSystemMode();
        break;
      case ThemeColorMode.backgroundImage:
        await _handleBackgroundImageMode();
        break;
      case ThemeColorMode.custom:
        setState(() {
          pickerColor = Colors.blue;
          colorScheme = ColorScheme.fromSeed(
            seedColor: pickerColor,
            brightness: Theme.of(context).brightness,
          );
        });
    }
  }

  Future<void> _handleSystemMode() async {
    final result = await _themeColorProvider.previewSystemColor();
    if (!mounted) return;
    setState(() {
      pickerColor = result.color!;
      colorScheme = ColorScheme.fromSeed(
        seedColor: pickerColor,
        brightness: Theme.of(context).brightness,
      );
    });
  }

  Future<void> _handleBackgroundImageMode() async {
    final result = await _themeColorProvider.previewBackgroundImageColor();
    if (!mounted) return;
    if (result.color != null && result.mode == ThemeColorMode.backgroundImage) {
      setState(() {
        pickerColor = result.color!;
        colorScheme = ColorScheme.fromSeed(
          seedColor: pickerColor,
          brightness: Theme.of(context).brightness,
        );
      });
    } else {
      if (ref.read(backgroundImagePathSettingProvider) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.themeColorModeBackgroundImageNotSet,
            ),
          ),
        );
      }
      setState(() {
        _selectedMode = result.mode;
        pickerColor = result.color!;
        colorScheme = ColorScheme.fromSeed(
          seedColor: pickerColor,
          brightness: Theme.of(context).brightness,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    colorScheme ??= ColorScheme.fromSeed(
      seedColor: pickerColor,
      brightness: Theme.of(context).brightness,
    );
    return Theme(
      data: ThemeData(
        colorScheme: colorScheme,
        brightness: Theme.of(context).brightness,
      ),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.themeColor),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    onPressed: _confirmChanges,
                    child: Text(l10n.confirmButton),
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: withSystemBottomInset(
                context,
                EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              ),
              child: Column(
                children: [
                  CardWithTitle(
                    title: l10n.tips,
                    icon: const Icon(Icons.warning_amber),
                    backgroundColor: colorScheme?.secondaryContainer,
                    child: Text(l10n.customizedColorHint),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: SegmentedButton<ThemeColorMode>(
                      segments: [
                        ButtonSegment<ThemeColorMode>(
                          value: ThemeColorMode.system,
                          label: Text(l10n.themeColorModeSystem),
                          icon: const Icon(Icons.settings_suggest),
                        ),
                        ButtonSegment<ThemeColorMode>(
                          value: ThemeColorMode.backgroundImage,
                          label: Text(l10n.themeColorModeBackgroundImage),
                          icon: const Icon(Icons.wallpaper),
                        ),
                        ButtonSegment<ThemeColorMode>(
                          value: ThemeColorMode.custom,
                          label: Text(l10n.themeColorModeCustom),
                          icon: const Icon(Icons.palette),
                        ),
                      ],
                      selected: {_selectedMode},
                      onSelectionChanged: (selected) {
                        _onModeChanged(selected.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  MultiColorPicker(
                    initColor: pickerColor,
                    onColorChanged: changeColor,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmChanges() {
    ref.read(themeColorSettingProvider.notifier).update(pickerColor);
    ref.read(themeColorModeSettingProvider.notifier).update(_selectedMode);
    Navigator.of(context).pop();
  }
}

class MultiColorPicker extends StatefulWidget {
  final Color initColor;
  final void Function(Color color) onColorChanged;

  const MultiColorPicker({
    super.key,
    required this.onColorChanged,
    required this.initColor,
  });

  @override
  State<MultiColorPicker> createState() => _MultiColorPickerState();
}

class _MultiColorPickerState extends State<MultiColorPicker>
    with TickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(initialIndex: 0, length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: BlockPicker(
        useInShowDialog: false,
        pickerColor: widget.initColor,
        onColorChanged: widget.onColorChanged,
      ),
    );
  }
}
