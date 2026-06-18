import 'package:bugaoshan/pages/about/release_notes_page.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/utils/app_shapes.dart';
import 'package:bugaoshan/widgets/route/popup_context.dart';

/// 显示更新弹窗
///
/// [context] 当前上下文
/// [version] 新版本号
/// [releaseNotes] 更新日志内容（可选）
/// [isPreview] 是否为预览版本
/// [onStartUpdate] 点击"开始更新"按钮的回调
Future<void> showUpdateDialog({
  required BuildContext context,
  required String version,
  String? releaseNotes,
  bool isPreview = false,
  required VoidCallback onStartUpdate,
}) async {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return PopupContext(
        isInPopup: true,
        child: UpdateDialogContent(
          version: version,
          releaseNotes: releaseNotes,
          isPreview: isPreview,
          onStartUpdate: onStartUpdate,
        ),
      );
    },
  );
}

class UpdateDialogContent extends StatelessWidget {
  final String version;
  final String? releaseNotes;
  final bool isPreview;
  final VoidCallback onStartUpdate;

  const UpdateDialogContent({
    super.key,
    required this.version,
    this.releaseNotes,
    this.isPreview = false,
    required this.onStartUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;

    final hasReleaseNotes = releaseNotes != null && releaseNotes!.isNotEmpty;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenWidth * 0.7 > 400 ? 400 : screenWidth * 0.7,
          maxHeight: screenHeight * (hasReleaseNotes ? 0.6 : 0.4),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon + Title (centered)
              Icon(
                isPreview ? Icons.science : Icons.system_update_alt,
                size: 36,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.newVersionAvailable,
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Body text
              ListTile(
                title: Text(
                  '${l10n.version}: $version',
                  style: textTheme.bodyLarge,
                ),
                onTap: releaseNotes != null
                    ? () {
                        popupOrNavigate(
                          context,
                          ReleaseNotesPage(
                            version: version,
                            releaseNotes: releaseNotes!,
                          ),
                        );
                      }
                    : null,
              ),
              if (isPreview) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.preReleaseWarning,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (releaseNotes != null && releaseNotes!.isNotEmpty) ...[
                Expanded(child: _buildReleaseNotes(context)),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 16),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.neverMind),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onStartUpdate();
                    },
                    child: Text(
                      isPreview ? l10n.startUpdatePreview : l10n.startUpdate,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReleaseNotes(BuildContext context) {
    //trim releaseNotes from ### Add
    final index = releaseNotes!.indexOf('\n### Add');
    var trimmedNotes = releaseNotes!;
    if (index != -1) {
      trimmedNotes = releaseNotes!.substring(index);
    }
    return Markdown(
      data: trimmedNotes,
      selectable: false,
      padding: const EdgeInsets.all(0),
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        blockquoteDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppShapes.small),
        ),
      ),
    );
  }
}
