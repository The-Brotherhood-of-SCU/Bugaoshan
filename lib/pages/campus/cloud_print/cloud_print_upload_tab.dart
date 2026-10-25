part of 'cloud_print_page.dart';

extension _CloudPrintUploadTab on _CloudPrintPageState {
  Widget _uploadTab(AppLocalizations l10n) {
    final busy = _provider.uploading || _provider.selecting;
    return ListView(
      padding: withSystemBottomInset(context, const EdgeInsets.all(16)),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : () => _pickFiles(l10n),
              icon: const Icon(Icons.add),
              label: Text(l10n.cloudPrintChoose),
            ),
            if (_provider.failedCount > 0)
              OutlinedButton(
                onPressed: busy ? null : _provider.retryFailed,
                child: Text(l10n.cloudPrintRetryFailed),
              ),
            if (_provider.queue.any(
              (item) => item.status == CloudPrintQueueStatus.uploaded,
            ))
              TextButton(
                onPressed: busy ? null : _provider.clearFinished,
                child: Text(l10n.cloudPrintClearFinished),
              ),
          ],
        ),
        const SizedBox(height: 12),
        StyledCard(
          child: ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.cloudPrintSettings),
            subtitle: Text(_optionsSummary(_provider.defaults, l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: busy ? null : () => _settings(l10n),
          ),
        ),
        _hint(l10n.cloudPrintHint),
        if (_provider.selecting) const LinearProgressIndicator(),
        if (_provider.queue.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(
                  Icons.upload_file,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(l10n.cloudPrintEmptyQueue),
              ],
            ),
          ),
        for (final item in _provider.queue) _queueCard(item, l10n),
        if (_provider.queue.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _provider.uploading
                ? OutlinedButton.icon(
                    onPressed: _provider.stopRequested
                        ? null
                        : _provider.stopAfterCurrent,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(
                      _provider.stopRequested
                          ? l10n.cloudPrintStopping
                          : l10n.cloudPrintStop,
                    ),
                  )
                : FilledButton.icon(
                    onPressed:
                        _provider.pendingCount == 0 || _provider.selecting
                        ? null
                        : _provider.uploadPending,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(l10n.cloudPrintStart(_provider.pendingCount)),
                  ),
          ),
      ],
    );
  }

  Widget _queueCard(CloudPrintQueueItem item, AppLocalizations l10n) {
    final status = item.status;
    final editable =
        !_provider.uploading &&
        [
          CloudPrintQueueStatus.pending,
          CloudPrintQueueStatus.failed,
        ].contains(status);
    final message = switch (status) {
      CloudPrintQueueStatus.pending => l10n.cloudPrintPending,
      CloudPrintQueueStatus.uploading =>
        item.progress >= 1
            ? l10n.cloudPrintProcessing
            : l10n.cloudPrintUploading((item.progress * 100).round()),
      CloudPrintQueueStatus.uploaded => l10n.cloudPrintUploaded,
      CloudPrintQueueStatus.failed => l10n.cloudPrintFailed,
      CloudPrintQueueStatus.uncertain => l10n.cloudPrintUncertain,
    };
    final color =
        [
          CloudPrintQueueStatus.failed,
          CloudPrintQueueStatus.uncertain,
        ].contains(status)
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return StyledCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == CloudPrintQueueStatus.uploaded
                    ? Icons.check_circle_outline
                    : Icons.description_outlined,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!_provider.uploading)
                IconButton(
                  onPressed: () => _provider.remove(item),
                  tooltip: l10n.cloudPrintRemove,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          Text(
            '${_size(item.file.size)} · ${_optionsSummary(item.options, l10n)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: color)),
          if (status == CloudPrintQueueStatus.uploading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: item.progress < 1 ? item.progress : null,
            ),
          ],
          if (status == CloudPrintQueueStatus.failed)
            Text(switch (item.failure) {
              CloudPrintFailure.authentication => l10n.cloudPrintFailureAuth,
              CloudPrintFailure.tooLarge => l10n.cloudPrintFailureSize,
              _ => l10n.cloudPrintFailureRequest,
            }),
          if (item.verificationPending &&
              status == CloudPrintQueueStatus.uploaded)
            Text(l10n.cloudPrintVerificationPending),
          Wrap(
            spacing: 8,
            children: [
              if (editable)
                TextButton.icon(
                  onPressed: () => _settings(l10n, item: item),
                  icon: const Icon(Icons.tune),
                  label: Text(l10n.cloudPrintFileSettings),
                ),
              if (status == CloudPrintQueueStatus.failed)
                TextButton(
                  onPressed: _provider.uploading
                      ? null
                      : () => _provider.requeue(item),
                  child: Text(l10n.cloudPrintRequeue),
                ),
              if (status == CloudPrintQueueStatus.uncertain ||
                  item.verificationPending)
                TextButton.icon(
                  onPressed: () {
                    _tabs.animateTo(1);
                    unawaited(_provider.refreshJobs());
                  },
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(l10n.cloudPrintVerify),
                ),
              if (status == CloudPrintQueueStatus.uncertain)
                TextButton(
                  onPressed: _provider.uploading
                      ? null
                      : () => _confirmMissing(item, l10n),
                  child: Text(l10n.cloudPrintMissingConfirm),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
