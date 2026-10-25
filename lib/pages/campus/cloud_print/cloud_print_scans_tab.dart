part of 'cloud_print_page.dart';

extension _CloudPrintScansTab on _CloudPrintPageState {
  Widget _scansTab(AppLocalizations l10n) {
    final available = _provider.scans
        .where((scan) => !scan.expired)
        .map((scan) => scan.id)
        .toSet();
    _selectedScans.removeWhere((id) => !available.contains(id));
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
                onPressed: _selectedScans.isEmpty || _provider.downloading
                    ? null
                    : () => _downloadScans(l10n),
                icon: const Icon(Icons.download),
                label: Text(l10n.cloudPrintDownloadSelected),
              ),
              OutlinedButton.icon(
                onPressed: _selectedScans.isEmpty || _provider.downloading
                    ? null
                    : () => _downloadScans(l10n, share: true),
                icon: const Icon(Icons.share_outlined),
                label: Text(l10n.cloudPrintShareSelected),
              ),
            ],
          ),
          if (available.isNotEmpty)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.cloudPrintSelectAll),
              value: _selectedScans.length == available.length,
              onChanged: (value) => _update(() {
                if (value == true) {
                  _selectedScans.addAll(available);
                } else {
                  _selectedScans.clear();
                }
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
                    onChanged: scan.expired
                        ? null
                        : (value) => _update(() {
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
                  if (!scan.expired)
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: _provider.downloading
                              ? null
                              : () => _downloadScans(l10n, only: scan),
                          icon: const Icon(Icons.download),
                          label: Text(l10n.cloudPrintDownload),
                        ),
                        if (_provider.scanFiles.containsKey(scan.id))
                          TextButton.icon(
                            onPressed: () => _openScan(scan, l10n),
                            icon: const Icon(Icons.open_in_new),
                            label: Text(l10n.cloudPrintOpen),
                          ),
                        TextButton.icon(
                          onPressed: _provider.downloading
                              ? null
                              : () => _downloadScans(
                                  l10n,
                                  only: scan,
                                  share: true,
                                ),
                          icon: const Icon(Icons.share_outlined),
                          label: Text(l10n.cloudPrintShare),
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
