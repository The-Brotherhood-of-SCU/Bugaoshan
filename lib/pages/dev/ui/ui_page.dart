import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/release_info.dart';
import 'package:bugaoshan/pages/dev/update_card.dart';
import 'package:bugaoshan/providers/update_provider.dart';
import 'package:bugaoshan/services/update_service.dart';
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
        filename: 'bugaoshan-11.45.14.apk',
        onDownloadInBackground: () => Navigator.of(dialogContext).pop(),
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showUpdateDialog(bool isPreview) {
    showDialog(
      context: context,
      builder: (dialogContext) => UpdateDialogContent(
        version: "11.45.14",
        releaseNotes: "这是一个新的版本，这是一个新的版本\n\n" * 10,
        isPreview: isPreview,
        onStartUpdate: () {},
      ),
    );
  }

  void _showUpdateCardAnimation() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _UpdateCardAnimationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = [
      _Tile(text: "Downloading Dialog", onTap: _showDownloadingDialog),
      _Tile(text: "Update Dialog", onTap: () => _showUpdateDialog(false)),
      _Tile(
        text: "Preview Update Dialog",
        onTap: () => _showUpdateDialog(true),
      ),
      _Tile(text: "Update Card Animation", onTap: _showUpdateCardAnimation),
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

/// 演示 Dev 页 UpdateCard 的完整更新动画：
/// 检查 0.5s → 卡片展开 → 点击按钮后模拟下载进度。
class _UpdateCardAnimationPage extends StatefulWidget {
  const _UpdateCardAnimationPage();

  @override
  State<_UpdateCardAnimationPage> createState() =>
      _UpdateCardAnimationPageState();
}

class _UpdateCardAnimationPageState extends State<_UpdateCardAnimationPage> {
  static const ReleaseInfo _demoRelease = ReleaseInfo(
    tagName: 'v2.6.0',
    downloadUrl: 'https://example.com/bugaoshan-2.6.0.apk',
    filename: 'bugaoshan-2.6.0.apk',
  );

  final ValueNotifier<UpdateCheckResult> _result = ValueNotifier(
    UpdateCheckResult.initial(),
  );
  Timer? _checkTimer;
  Timer? _progressTimer;
  bool _simulatingDownload = false;

  UpdateProvider get _provider => getIt<UpdateProvider>();

  @override
  void dispose() {
    _checkTimer?.cancel();
    _progressTimer?.cancel();
    _stopDownloadSimulation();
    _result.dispose();
    super.dispose();
  }

  void _play() {
    _checkTimer?.cancel();
    _progressTimer?.cancel();
    _stopDownloadSimulation();
    _result.value = UpdateCheckResult.checking();
    _checkTimer = Timer(const Duration(milliseconds: 500), () {
      _result.value = UpdateCheckResult.hasUpdate(_demoRelease);
    });
  }

  /// 借用真实 [UpdateProvider] 的下载状态字段播放进度，不发起任何网络请求。
  void _startDownloadSimulation() {
    if (_simulatingDownload || _provider.isDownloading.value) return;
    _simulatingDownload = true;
    var received = 0;
    _provider.isDownloading.value = true;
    _provider.downloadingVersion.value = _demoRelease.tagName;
    _provider.progressState.reset();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      received += 1;
      _provider.progressState.setProgress(received, 100);
      if (received >= 100) {
        timer.cancel();
        _stopDownloadSimulation();
      }
    });
  }

  void _stopDownloadSimulation() {
    if (!_simulatingDownload) return;
    _simulatingDownload = false;
    _provider.isDownloading.value = false;
    _provider.downloadingVersion.value = null;
    _provider.progressState.reset();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Update Card Animation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UpdateCard(
              icon: Icons.system_update_alt,
              title: l10n.updateToLatest,
              result: _result,
              onUpdate: _startDownloadSimulation,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _play, child: const Text('Replay')),
          ],
        ),
      ),
    );
  }
}
