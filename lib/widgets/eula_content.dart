import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

/// EULA 版本号，需要与 eula.md 中的 version 保持一致
const int currentEulaVersion = 1;

/// EULA 内容展示组件，包含滚动检测和同意复选框
class EulaContent extends StatefulWidget {
  final ValueChanged<bool>? onAgreedChanged;
  final bool showCheckbox;

  const EulaContent({
    super.key,
    this.onAgreedChanged,
    this.showCheckbox = true,
  });

  @override
  State<EulaContent> createState() => _EulaContentState();
}

class _EulaContentState extends State<EulaContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  String _eulaContent = '';
  bool _isLoading = true;
  bool _agreed = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadEulaContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEulaContent() async {
    try {
      final content = await rootBundle.loadString('assets/eula.md');
      if (mounted) {
        setState(() {
          _eulaContent = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _eulaContent = 'Failed to load EULA content';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleAgreed(bool? value) {
    setState(() {
      _agreed = value ?? false;
    });
    widget.onAgreedChanged?.call(_agreed);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Markdown(
                      data: _eulaContent,
                      selectable: true,
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ).copyWith(
                            p: colorScheme.textTheme.bodyMedium,
                            blockquoteDecoration: BoxDecoration(
                              color: colorScheme
                                  .colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                    ),
                  ),
                ),
        ),
        if (widget.showCheckbox) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _agreed,
                onChanged: _toggleAgreed,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _toggleAgreed(!_agreed),
                  child: Text(l10n.eulaAgreeCheckbox),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
