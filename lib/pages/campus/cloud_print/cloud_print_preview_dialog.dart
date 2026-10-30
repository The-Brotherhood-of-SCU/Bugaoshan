part of 'cloud_print_page.dart';

/// 打印任务预览：服务端按页返回 PNG，翻页时才请求下一页并缓存已看过的页。
class _CloudPrintPreviewDialog extends StatefulWidget {
  const _CloudPrintPreviewDialog({required this.provider, required this.job});
  final CloudPrintProvider provider;
  final CloudPrintJob job;
  @override
  State<_CloudPrintPreviewDialog> createState() =>
      _CloudPrintPreviewDialogState();
}

class _CloudPrintPreviewDialogState extends State<_CloudPrintPreviewDialog> {
  static const _tag = 'CloudPrintPreview';
  final Map<int, Uint8List> _pages = {};
  int _page = 1;
  bool _loading = true, _failed = false, _invalidated = false;

  bool get _current => mounted && !_invalidated;

  int get _total => widget.job.pages > 0 ? widget.job.pages : 1;

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderChanged);
    unawaited(_load(1));
  }

  void _onProviderChanged() {
    if (_invalidated) return;
    if (widget.provider.jobs.any((j) => j.id == widget.job.id)) return;
    setState(() {
      _invalidated = true;
      _pages.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      // 只移除本预览，避免弹出的登录页被误关闭。
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route);
      }
    });
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChanged);
    _pages.clear();
    super.dispose();
  }

  Future<void> _load(int page) async {
    if (!_current) return;
    final cached = _pages[page];
    setState(() {
      _page = page;
      _failed = false;
      _loading = cached == null;
    });
    if (cached != null) return;
    try {
      final bytes = await widget.provider.previewPage(widget.job, page);
      if (!_current) return;
      _pages[page] = bytes;
      setState(() => _loading = false);
    } catch (_, stack) {
      if (!_current) return;
      AppLog.w(
        _tag,
        '打印任务预览加载失败',
        error: const ServiceException('预览失败'),
        stackTrace: stack,
      );
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_invalidated) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bytes = _pages[_page];
    final canTurn = !_loading;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
        child: Column(
          children: [
            ListTile(
              title: Text(
                widget.job.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(l10n.cloudPrintPreviewPage(_page, _total)),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.close,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : _failed || bytes == null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.cloudPrintPreviewFailed,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () => _load(_page),
                                icon: const Icon(Icons.refresh),
                                label: Text(l10n.retry),
                              ),
                            ],
                          ),
                        )
                      : InteractiveViewer(
                          maxScale: 5,
                          child: Image.memory(bytes, fit: BoxFit.contain),
                        ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: canTurn && _page > 1
                        ? () => _load(_page - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: l10n.cloudPrintPreview,
                  ),
                  Text(l10n.cloudPrintPreviewPage(_page, _total)),
                  IconButton(
                    onPressed: canTurn && _page < _total
                        ? () => _load(_page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: l10n.cloudPrintPreview,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
