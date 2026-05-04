import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

class SetThemeColorPage extends StatefulWidget {
  const SetThemeColorPage({super.key});

  @override
  State<SetThemeColorPage> createState() => _SetThemeColorPageState();
}

class _SetThemeColorPageState extends State<SetThemeColorPage> {
  final appConfigService = getIt<AppConfigProvider>();

  late Color pickerColor;
  ColorScheme? colorScheme;
  _SetThemeColorPageState() {
    pickerColor = appConfigService.themeColor.value;
  }

  @override
  void initState() {
    super.initState();
  }

  void changeColor(Color color) {
    setState(() {
      pickerColor = color;
      colorScheme = ColorScheme.fromSeed(
        seedColor: pickerColor,
        brightness: Theme.of(context).brightness,
      );
    });
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
                TextButton(
                  onPressed: _confirmChanges,
                  child: Text(l10n.confirmButton),
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
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        changeColor(Colors.blue);
                      },
                      child: Text(l10n.resetToDefault),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      onPressed: _extractColorFromBackground,
                      child: Text(l10n.extractColorFromBackgroundImage),
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: _confirmChanges,
              child: const Icon(Icons.check),
            ),
          );
        },
      ),
    );
  }

  void _confirmChanges() {
    appConfigService.themeColor.value = pickerColor;
    Navigator.of(context).pop();
  }

  Future<void> _extractColorFromBackground() async {
    final bgPath = appConfigService.backgroundImagePath.value;
    if (bgPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.noBackgroundImageSet)),
        );
      }
      return;
    }

    final file = File(bgPath);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final pixels = <int>[];
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return;

    for (int i = 0; i < byteData.lengthInBytes; i += 4) {
      final r = byteData.getUint8(i);
      final g = byteData.getUint8(i + 1);
      final b = byteData.getUint8(i + 2);
      final a = byteData.getUint8(i + 3);
      if (a > 128) {
        pixels.add((r << 16) | (g << 8) | b);
      }
    }

    if (pixels.isEmpty) return;

    final colorCounts = <int, int>{};
    for (final px in pixels) {
      final quantized = px & 0xFFF8F8F8;
      colorCounts[quantized] = (colorCounts[quantized] ?? 0) + 1;
    }

    final dominantColorValue = colorCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    if (mounted) {
      changeColor(Color(dominantColorValue | 0xFF000000));
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
        // 透明色
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
              color: Colors.black.withValues(alpha: 0.1), //color of shadow
              spreadRadius: 0.1, //spread radius
              blurRadius: 10, // blur radius
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
