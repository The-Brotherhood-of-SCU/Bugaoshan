import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/set_theme_color_provider.dart';
import 'package:system_theme/system_theme.dart';

class SetThemeColorPage extends StatefulWidget {
  const SetThemeColorPage({super.key});

  @override
  State<SetThemeColorPage> createState() => _SetThemeColorPageState();
}

class _SetThemeColorPageState extends State<SetThemeColorPage> {
  final appConfigService = getIt<AppConfigProvider>();
  final themeColorProvider = SetThemeColorProvider(getIt<AppConfigProvider>());

  late Color pickerColor;
  late ThemeColorMode _selectedMode;
  ColorScheme? colorScheme;

  @override
  void initState() {
    super.initState();
    pickerColor = appConfigService.themeColor.value;
    _selectedMode = appConfigService.themeColorMode.value;
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
        await _previewSystemColor();
        break;
      case ThemeColorMode.backgroundImage:
        await _previewBackgroundImageColor();
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
            body: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  commonCard(
                    context: context,
                    child: Text(l10n.customizedColorHint),
                    title: l10n.tips,
                    icon: const Icon(Icons.warning_amber),
                  ),
                  Expanded(
                    child: MultiColorPicker(
                      initColor: pickerColor,
                      onColorChanged: changeColor,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: SegmentedButton<ThemeColorMode>(
                      segments: [
                        ButtonSegment<ThemeColorMode>(
                          value: ThemeColorMode.system,
                          label: Text(l10n.followSystem),
                          icon: const Icon(Icons.settings_suggest),
                        ),
                        ButtonSegment<ThemeColorMode>(
                          value: ThemeColorMode.backgroundImage,
                          label: Text(l10n.backgroundImage),
                          icon: const Icon(Icons.wallpaper),
                        ),
                        ButtonSegment<ThemeColorMode>(
                          value: ThemeColorMode.custom,
                          label: Text(l10n.custom),
                          icon: const Icon(Icons.palette),
                        ),
                      ],
                      selected: {_selectedMode},
                      onSelectionChanged: (selected) {
                        _onModeChanged(selected.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmChanges() {
    appConfigService.themeColor.value = pickerColor;
    appConfigService.themeColorMode.value = _selectedMode;
    Navigator.of(context).pop();
  }

  Future<void> _previewSystemColor() async {
    await SystemTheme.accentColor.load();
    final systemColor = SystemTheme.accentColor.accent;
    setState(() {
      pickerColor = systemColor;
      colorScheme = ColorScheme.fromSeed(
        seedColor: pickerColor,
        brightness: Theme.of(context).brightness,
      );
    });
  }

  Future<void> _previewBackgroundImageColor() async {
    if (appConfigService.backgroundImagePath.value == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.themeColorModeBackgroundImageNotSet,
          ),
        ),
      );
      final previousMode = appConfigService.themeColorMode.value;
      setState(() {
        _selectedMode = previousMode;
      });
      if (previousMode == ThemeColorMode.system) {
        await _previewSystemColor();
      } else if (previousMode == ThemeColorMode.custom) {
        setState(() {
          pickerColor = appConfigService.themeColor.value;
          colorScheme = ColorScheme.fromSeed(
            seedColor: pickerColor,
            brightness: Theme.of(context).brightness,
          );
        });
      }
      return;
    }
    final result = await themeColorProvider.extractColorFromBackgroundImage();
    if (!mounted) return;
    switch (result) {
      case ExtractColorResult.noBackgroundImage:
        break;
      case ExtractColorResult.success:
        setState(() {
          pickerColor = themeColorProvider.extractedColor!;
          colorScheme = ColorScheme.fromSeed(
            seedColor: pickerColor,
            brightness: Theme.of(context).brightness,
          );
        });
        break;
      case ExtractColorResult.failure:
        break;
    }
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: BlockPicker(
          useInShowDialog: false,
          pickerColor: widget.initColor,
          onColorChanged: widget.onColorChanged,
        ),
      ),
    );
  }
}

class BasicCard extends StatelessWidget {
  final void Function(BuildContext context)? onTap;
  final Widget? child;

  const BasicCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget? realChild;
    if (onTap == null) {
      realChild = child;
    } else {
      realChild = InkWell(
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        onTap: () {
          onTap!(context);
        },
        child: SizedBox(width: double.infinity, child: child),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        alignment: Alignment.topLeft,
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusDirectional.circular(20),
          ),
          color: Theme.of(context).colorScheme.secondaryContainer,
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              spreadRadius: 0.1,
              blurRadius: 10,
            ),
          ],
        ),
        width: double.infinity,
        child: realChild,
      ),
    );
  }
}

Widget commonCard({
  required BuildContext context,
  required String title,
  required Widget? child,
  Widget? icon,
  void Function(BuildContext context)? onTap,
}) {
  return BasicCard(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [titleText(title), icon ?? Container()],
          ),
          child ?? Container(),
        ],
      ),
    ),
  );
}

Widget titleText(String text) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
    child: Text(
      text,
      textScaler: const TextScaler.linear(1.3),
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}
