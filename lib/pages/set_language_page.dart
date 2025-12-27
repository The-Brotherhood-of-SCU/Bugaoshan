import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rubbish_plan/injection/injector.dart';
import 'package:rubbish_plan/l10n/app_localizations.dart';
import 'package:rubbish_plan/providers/app_config_provider.dart';
import 'package:rubbish_plan/utils/locale_utils.dart';

class SetLanguagePage extends StatefulWidget {
  const SetLanguagePage({super.key});

  @override
  State<SetLanguagePage> createState() => _SetLanguagePageState();
}

class _SetLanguagePageState extends State<SetLanguagePage> {
  late List<Locale> locales = AppLocalizations.supportedLocales;
  final appSetting = getIt<AppConfigProvider>();
  String? selected;

  @override
  void initState() {
    selected = appSetting.locale.value?.toLanguageTag();
    super.initState();
  }

  void onValueChanged(String? v) {
    setState(() {
      selected = v;
    });
    scheduleMicrotask(() {
      appSetting.locale.value = parseLocale(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[];
    children.add(
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: FollowSystemRadioButton(
          index: null,
          selected: selected,
          onChanged: onValueChanged,
          text: AppLocalizations.of(context)!.followSystem,
          appSetting: appSetting,
        ),
      ),
    );
    for (var i in locales) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Localizations.override(
            context: context,
            locale: i,
            child: Builder(
              builder: (context) {
                return RadioButton(
                  index: i.toLanguageTag(),
                  selected: selected,
                  onChanged: onValueChanged,
                  text: AppLocalizations.of(context)!.selfLanguage,
                );
              },
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.modifyLanguage)),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}

class RadioButton extends StatelessWidget {
  final String? selected;
  final String? index;
  final String text;
  final void Function(String? v) onChanged;

  const RadioButton({
    super.key,
    required this.selected,
    required this.index,
    required this.text,
    required this.onChanged,
  });

  void onPress() {
    onChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    var selfSelected = selected == index;
    Widget child = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(text, textScaler: const TextScaler.linear(1.1)),
        ),
        AnimatedOpacity(
          opacity: selfSelected ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: const Icon(Icons.check),
        ),
      ],
    );

    return OutlinedButton(onPressed: onPress, child: child);
  }
}

class FollowSystemRadioButton extends RadioButton {
  const FollowSystemRadioButton({
    super.key,
    required super.selected,
    required super.index,
    required super.text,
    required super.onChanged,
    required this.appSetting,
  });

  final AppConfigProvider appSetting;

  @override
  Widget build(BuildContext context) {
    var selfSelected = selected == index;
    Widget child = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          key: ValueKey(text),
          text,
          textScaler: const TextScaler.linear(1.1),
        ),
        AnimatedOpacity(
          opacity: selfSelected ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: const Icon(Icons.check),
        ),
      ],
    );
    var appLang = AppLocalizations.of(context)!;
    return OutlinedButton(
      onPressed: onPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
        child: AnimatedSize(
          duration: appSetting.cardSizeAnimationDuration.value,
          curve: Curves.easeOutQuart,
          child: selfSelected
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    child,
                    Text("${appLang.current}: ${appLang.selfLanguage}"),
                  ],
                )
              : child,
        ),
      ),
    );
  }
}
