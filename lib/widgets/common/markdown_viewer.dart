import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/utils/app_log.dart';

/// 统一的 Markdown 渲染组件。
///
/// 全应用的文档类 Markdown（协议、隐私政策、更新日志等）都走这里，
/// 保证段落字号、引用块底色与圆角、超链接行为一致。
class MarkdownViewer extends StatelessWidget {
  final String data;
  final ScrollController? controller;
  final EdgeInsets padding;
  final bool selectable;

  const MarkdownViewer({
    super.key,
    required this.data,
    this.controller,
    this.padding = const EdgeInsets.all(16),
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Markdown(
      data: data,
      selectable: selectable,
      controller: controller,
      padding: padding,
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href));
        }
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium,
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppShapes.small),
        ),
      ),
    );
  }
}

/// 按 asset 路径加载并整页展示 Markdown 文档。
///
/// 用于应用内阅读随包发布的文档（`docs/legal/` 下的协议、隐私政策、支持说明）。
class MarkdownAssetPage extends StatefulWidget {
  final String assetPath;
  final String title;

  const MarkdownAssetPage({
    super.key,
    required this.assetPath,
    required this.title,
  });

  @override
  State<MarkdownAssetPage> createState() => _MarkdownAssetPageState();
}

class _MarkdownAssetPageState extends State<MarkdownAssetPage> {
  String? _content;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final content = await rootBundle.loadString(widget.assetPath);
      if (!mounted) return;
      setState(() => _content = content);
    } catch (e) {
      AppLog.e('MarkdownAssetPage', 'load ${widget.assetPath} failed: $e');
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final content = _content;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _failed
          ? Center(child: Text(l10n.docLoadFailed))
          : content == null
          ? const Center(child: CircularProgressIndicator())
          : MarkdownViewer(data: content),
    );
  }
}
