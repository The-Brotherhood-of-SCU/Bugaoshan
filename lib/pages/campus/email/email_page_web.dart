import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class EmailPage extends StatelessWidget {
  const EmailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.campusEmail)),
      body: Center(child: Text(l10n.emailWebUnsupported)),
    );
  }
}
