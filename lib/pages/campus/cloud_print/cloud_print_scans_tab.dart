part of 'cloud_print_page.dart';

extension _CloudPrintScansTab on _CloudPrintPageState {
  /// 选中集包含过期项：下载/分享只取未过期的，删除与清理按选中记录执行。
  List<CloudScanJob> get _selectedScanJobs => _provider.scans
      .where((scan) => _selectedScans.contains(scan.id))
      .toList();

  List<CloudScanJob> get _downloadableScans =>
      _selectedScanJobs.where((scan) => !scan.expired).toList();

  Widget _scansTab(AppLocalizations l10n) {
    final expired = _provider.scans.where((scan) => scan.expired).toList();
    final all = _provider.scans.map((scan) => scan.id).toSet();
    _selectedScans.removeWhere((id) => !all.contains(id));
    return RefreshIndicator(
      onRefresh: _provider.refreshScans,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: withSystemBottomInset(context, const EdgeInsets.all(16)),
        children: [
          _hint(l10n.cloudPrintScanHint),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _provider.loadingScans
                    ? null
                    : _provider.refreshScans,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.refresh),
              ),
              FilledButton.tonalIcon(
                onPressed: _downloadableScans.isEmpty || _provider.downloading
                    ? null
                    : () => _downloadScans(l10n),
                icon: const Icon(Icons.download),
                label: Text(l10n.cloudPrintDownloadSelected),
              ),
              OutlinedButton.icon(
                onPressed: _downloadableScans.isEmpty || _provider.downloading
                    ? null
                    : () => _downloadScans(l10n, share: true),
                icon: const Icon(Icons.share_outlined),
                label: Text(l10n.cloudPrintShareSelected),
              ),
              OutlinedButton.icon(
                onPressed: _selectedScans.isEmpty
                    ? null
                    : () => _deleteScans(l10n, _selectedScanJobs),
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  l10n.cloudPrintDeleteSelected(_selectedScans.length),
                ),
              ),
              if (expired.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () =>
                      _deleteScans(l10n, expired, cleanExpired: true),
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: Text(l10n.cloudPrintCleanExpired),
                ),
            ],
          ),
          if (all.isNotEmpty)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.cloudPrintSelectAll),
              value: _selectedScans.length == all.length,
              onChanged: (value) => _update(() {
                _selectedScans.clear();
                if (value == true) _selectedScans.addAll(all);
              }),
            ),
          if (_provider.loadingScans) const LinearProgressIndicator(),
          if (_provider.scansFailed) _hint(l10n.cloudPrintLoadFailed),
          if (!_provider.loadingScans &&
              !_provider.scansFailed &&
              _provider.scans.isEmpty)
            _hint(l10n.cloudPrintScanEmpty),
          for (final scan in _provider.scans)
            StyledCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _selectedScans.contains(scan.id),
                    onChanged: (value) => _update(() {
                      if (value == true) {
                        _selectedScans.add(scan.id);
                      } else {
                        _selectedScans.remove(scan.id);
                      }
                    }),
                    title: Text(
                      scan.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_size(scan.size)} · ${scan.displayDate}${scan.expired ? ' · ${l10n.cloudPrintScanExpired}' : ''}',
                    ),
                  ),
                  if (_provider.scanProgress[scan.id] case final progress?)
                    LinearProgressIndicator(value: progress),
                  if (_provider.scanFailures.contains(scan.id))
                    Text(
                      l10n.cloudPrintDownloadFailed,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      // 服务端没有扫描件预览接口：先下载到应用目录，再交给系统打开。
                      TextButton.icon(
                        onPressed: _provider.downloading
                            ? null
                            : () => _previewScan(scan, l10n),
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(l10n.cloudPrintPreview),
                      ),
                      if (!scan.expired)
                        TextButton.icon(
                          onPressed: _provider.downloading
                              ? null
                              : () => _downloadScans(l10n, only: scan),
                          icon: const Icon(Icons.download),
                          label: Text(l10n.cloudPrintDownload),
                        ),
                      if (!scan.expired)
                        TextButton.icon(
                          onPressed: _provider.downloading
                              ? null
                              : () =>
                                    _downloadScans(l10n, only: scan, share: true),
                          icon: const Icon(Icons.share_outlined),
                          label: Text(l10n.cloudPrintShare),
                        ),
                      TextButton.icon(
                        onPressed: () => _deleteScans(l10n, [scan]),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text(l10n.cloudPrintDelete),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _downloadScans(
    AppLocalizations l10n, {
    CloudScanJob? only,
    bool share = false,
  }) async {
    final selected = only != null
        ? [only]
        : _provider.scans
              .where(
                (scan) => _selectedScans.contains(scan.id) && !scan.expired,
              )
              .toList();
    final generation = _provider.sessionGeneration;
    try {
      final directory = Directory(
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          'Bugaoshan',
          'scans',
        ),
      );
      if (!mounted || generation != _provider.sessionGeneration) return;
      await _provider.downloadScans(selected, directory);
      if (!mounted || generation != _provider.sessionGeneration) return;
      final paths = selected
          .map((scan) => _provider.scanFiles[scan.id])
          .whereType<String>()
          .toList();
      if (share && paths.isNotEmpty) {
        if (paths.length != selected.length) {
          _snack(l10n.cloudPrintDownloadFailed);
        }
        await shareMultipleFiles(paths, context: context);
      } else if (!share) {
        _snack(
          paths.length == selected.length
              ? l10n.cloudPrintDownloadDone
              : l10n.cloudPrintDownloadFailed,
        );
      }
    } catch (_, stack) {
      AppLog.e(
        _CloudPrintPageState._tag,
        '扫描文档保存或分享失败',
        error: const ServiceException('保存或分享失败'),
        stackTrace: stack,
      );
      _snack(
        share ? l10n.cloudPrintShareFailed : l10n.cloudPrintDownloadFailed,
      );
    }
  }

  /// 预览 = 先下载到应用目录，再交给系统程序打开；已下载过的直接打开。
  Future<void> _previewScan(CloudScanJob scan, AppLocalizations l10n) async {
    if (scan.expired) {
      _snack(l10n.cloudPrintScanExpired);
      return;
    }
    final cached = _provider.scanFiles[scan.id];
    if (cached == null || !await File(cached).exists()) {
      await _downloadScans(l10n, only: scan);
      if (!mounted) return;
    }
    if (_provider.scanFiles[scan.id] == null) return;
    await _openScan(scan, l10n);
  }

  Future<void> _deleteScans(
    AppLocalizations l10n,
    List<CloudScanJob> targets, {
    bool cleanExpired = false,
  }) async {
    if (targets.isEmpty) return;
    final confirmed = await _confirmDelete(
      l10n.cloudPrintDelete,
      cleanExpired
          ? l10n.cloudPrintCleanExpiredConfirm(targets.length)
          : targets.length == 1
          ? l10n.cloudPrintScanDeleteConfirm(targets.single.name)
          : l10n.cloudPrintScanDeleteSelectedConfirm(targets.length),
      l10n,
    );
    if (!confirmed) return;
    final result = await _provider.deleteScans(targets);
    if (!mounted) return;
    _update(() {
      _selectedScans.removeWhere(
        (id) => !_provider.scans.any((scan) => scan.id == id),
      );
    });
    _snackDeleteResult(result.deleted, result.failed, l10n);
  }

  Future<void> _openScan(CloudScanJob scan, AppLocalizations l10n) async {
    final path = _provider.scanFiles[scan.id];
    if (path == null) return;
    try {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        throw const ServiceException('无可用的文件打开方式');
      }
    } catch (_, stack) {
      AppLog.e(
        _CloudPrintPageState._tag,
        '扫描文档打开失败',
        error: const ServiceException('打开失败'),
        stackTrace: stack,
      );
      _snack(l10n.cloudPrintOpenFailed);
    }
  }
}
