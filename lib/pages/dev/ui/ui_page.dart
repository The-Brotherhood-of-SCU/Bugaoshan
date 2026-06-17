import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/widgets/dialog/download_progress_dialog.dart';
import 'package:bugaoshan/widgets/dialog/update_dialog.dart';
import 'package:flutter/material.dart';

class UiPage extends StatefulWidget {
  const UiPage({super.key});

  @override
  State<UiPage> createState() => _UiPageState();
}

class _UiPageState extends State<UiPage> {
  void _showDownloadingDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) => DownloadProgressDialogView(
        progressState: UpdateProgressState(),
        l10n: l10n,
        onDownloadInBackground: () => Navigator.of(dialogContext).pop(),
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => UpdateDialogContent(
        version: "11.45.14",
        releaseNotes: "这是一个新的版本\n\n" * 10,
        isPreview: false,
        onStartUpdate: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = [
      _Tile(text: "Downloading Dialog", onTap: _showDownloadingDialog),
      _Tile(text: "Update Dialog", onTap: _showUpdateDialog),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text("UI Preview")),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SingleChildScrollView(child: Column(children: children)),
      ),
    );
  }
}

class _Tile extends StatefulWidget {
  final String text;
  final void Function() onTap;
  const _Tile({required this.text, required this.onTap});

  @override
  State<_Tile> createState() => __TileState();
}

class __TileState extends State<_Tile> {
  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(widget.text), onTap: widget.onTap);
  }
}
