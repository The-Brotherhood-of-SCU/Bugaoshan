import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/widgets/common/markdown_viewer.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

/// EULA 版本号，需要与 eula.md 中的 version 保持一致
const int currentEulaVersion = 2;

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
  bool _loadFailed = false;
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
      final content = await rootBundle.loadString(kEulaAsset);
      if (mounted) {
        setState(() {
          _eulaContent = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLog.e('EulaContent', 'load $kEulaAsset failed: $e');
      if (mounted) {
        setState(() {
          _loadFailed = true;
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
              : _loadFailed
              ? Center(child: Text(l10n.docLoadFailed))
              : Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(AppShapes.small),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppShapes.small),
                    child: MarkdownViewer(
                      data: _eulaContent,
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
        ),
        // 相关文档入口
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => popupOrNavigate(
                  context,
                  MarkdownAssetPage(
                    assetPath: kPrivacyPolicyAsset,
                    title: l10n.privacyPolicy,
                  ),
                ),
                child: Text(l10n.privacyPolicy),
              ),
              TextButton(
                onPressed: () => popupOrNavigate(
                  context,
                  MarkdownAssetPage(
                    assetPath: kSupportAsset,
                    title: l10n.supportAndHelp,
                  ),
                ),
                child: Text(l10n.supportAndHelp),
              ),
            ],
          ),
        ),
        if (widget.showCheckbox) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Checkbox(value: _agreed, onChanged: _toggleAgreed),
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
