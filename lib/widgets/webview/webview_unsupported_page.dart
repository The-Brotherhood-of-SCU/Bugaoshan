import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/open_link.dart';
import 'package:bugaoshan/widgets/common/third_center.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:os_type/os_type.dart';
import 'package:url_launcher/url_launcher.dart';

/// 当前平台是否没有可用的原生 WebView 后端。
///
/// Linux 侧的 `flutter_inappwebview` 只解析到纯 Dart 占位实现（无任何原生代码），
/// 任何 `InAppWebView` 都会在运行时抛 `UnimplementedError`。
bool get hasNoWebViewBackend => OS.isLinux;

/// Placeholder page shown when the current platform cannot host a WebView.
///
/// 传入 [url] 时（Linux 通知页 / 志愿四川等），页面会变成「交给系统浏览器」
/// 的交接页：展示目标地址，并提供打开与复制链接操作，而不是只给一句
/// 「当前平台不支持此功能」。
class WebViewUnsupportedPage extends StatelessWidget {
  const WebViewUnsupportedPage({super.key, required this.title, this.url});

  final String title;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final target = url;
    if (target != null && target.isNotEmpty) {
      return _WebViewExternalBrowserPage(title: title, url: target);
    }
    return _buildUnsupported(context);
  }

  Widget _buildUnsupported(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: _buildAppBar(l10n),
      body: ThirdCenter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.browser_not_supported_outlined,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.featureNotSupported,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations l10n) {
    return AppBar(
      centerTitle: true,
      title: Text(title),
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.close,
        onPressed: _closePage,
      ),
    );
  }
}

/// 关闭当前 WebView 兜底页；与通知页保持一致，统一从根 Navigator 弹出。
void _closePage() {
  if (logicRootContext.mounted) {
    Navigator.of(logicRootContext).pop();
  }
}

class _WebViewExternalBrowserPage extends StatefulWidget {
  const _WebViewExternalBrowserPage({required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<_WebViewExternalBrowserPage> createState() =>
      _WebViewExternalBrowserPageState();
}

class _WebViewExternalBrowserPageState
    extends State<_WebViewExternalBrowserPage> {
  static const String _tag = 'WebViewExternalBrowserPage';

  bool _opening = false;

  Future<void> _openInBrowser() async {
    if (_opening) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.hasScheme) {
      AppLog.w(_tag, 'Failed to parse URL');
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.webViewFallbackOpenFailed)),
      );
      return;
    }

    setState(() => _opening = true);
    var opened = false;
    try {
      opened = await openUri(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // openUri 内部已经记录异常，这里只需回到可点击状态。
      opened = false;
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.webViewFallbackOpenFailed)),
      );
    }
  }

  Future<void> _copyLink() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: widget.url));
    } catch (error, stackTrace) {
      AppLog.e(
        _tag,
        'Failed to copy link',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.webViewFallbackCopyFailed)),
      );
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.webViewFallbackLinkCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.close,
          onPressed: _closePage,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: ThirdCenter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: _buildBadge(colorScheme)),
                        const SizedBox(height: 28),
                        Text(
                          l10n.webViewFallbackTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.webViewFallbackBody,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _buildAddressCard(context, l10n),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _opening ? null : _openInBrowser,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            textStyle: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          icon: _opening
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.open_in_new_rounded),
                          label: Text(l10n.webViewFallbackOpen),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadge(ColorScheme colorScheme) {
    return SizedBox(
      width: 116,
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            top: 0,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer,
                    Color.lerp(
                      colorScheme.primaryContainer,
                      colorScheme.tertiaryContainer,
                      0.7,
                    )!,
                  ],
                ),
              ),
              child: Icon(
                Icons.public_rounded,
                size: 50,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surface,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(AppShapes.large);

    return Tooltip(
      message: l10n.webViewFallbackCopyLink,
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _copyLink,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppShapes.medium),
                  ),
                  child: Icon(
                    Icons.language_rounded,
                    size: 19,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.url,
                    softWrap: true,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.content_copy_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
