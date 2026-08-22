import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/services/sentry/sentry_service.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

/// 问题反馈页。自动错误弹窗与用户手动打开共用此页。
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({
    super.key,
    required this.sentryService,
    this.trigger = FeedbackTrigger.manual,
    this.initialErrorSummary,
  });

  final SentryService sentryService;
  final FeedbackTrigger trigger;
  final String? initialErrorSummary;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();

  final List<FeedbackLogAttachment> _logFiles = [];
  Uint8List? _screenshotBytes;
  String? _screenshotName;
  bool _includeAppLog = true;
  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _screenshotBytes = bytes;
        _screenshotName = picked.name;
      });
    } catch (err) {
      if (!mounted) return;
      _showMessage(_l10n.feedbackScreenshotPickFailed(err.toString()));
    }
  }

  void _removeScreenshot() {
    setState(() {
      _screenshotBytes = null;
      _screenshotName = null;
    });
  }

  Future<void> _pickLogFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['log', 'txt'],
      );
      if (result == null || !mounted) return;

      final pickedFiles = <FeedbackLogAttachment>[];
      for (final platformFile in result.files) {
        try {
          final bytes = await platformFile.readAsBytes();
          if (bytes.isEmpty) continue;
          pickedFiles.add(
            FeedbackLogAttachment(fileName: platformFile.name, bytes: bytes),
          );
        } catch (_) {
          // 单个文件读取失败时跳过，继续处理其余文件。
        }
      }
      if (pickedFiles.isEmpty || !mounted) return;
      setState(() => _logFiles.addAll(pickedFiles));
    } catch (err) {
      if (!mounted) return;
      _showMessage(_l10n.feedbackLogPickFailed(err.toString()));
    }
  }

  void _removeLogFile(FeedbackLogAttachment file) {
    setState(() => _logFiles.remove(file));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      await widget.sentryService.submitFeedback(
        FeedbackSubmission(
          description: _descriptionController.text.trim(),
          contact: _contactController.text.trim().isEmpty
              ? null
              : _contactController.text.trim(),
          trigger: widget.trigger,
          errorSummary: widget.initialErrorSummary,
          screenshotBytes: _screenshotBytes,
          logFiles: List.unmodifiable(_logFiles),
          includeAppLog: _includeAppLog,
        ),
      );
      if (!mounted) return;
      final rootContext = logicRootContext;
      Navigator.of(context, rootNavigator: true).pop();
      if (rootContext.mounted) {
        ScaffoldMessenger.of(
          rootContext,
        ).showSnackBar(SnackBar(content: Text(_l10n.feedbackSubmitSuccess)));
      }
    } on SentryNotConfiguredException {
      _showMessage(_l10n.feedbackSentryNotConfigured);
    } catch (err) {
      _showMessage(_l10n.feedbackSubmitFailed(err.toString()));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    final localizations = _l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.feedback)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (widget.trigger == FeedbackTrigger.crash)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations.feedbackCrashTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              localizations.feedbackCrashDesc,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                localizations.feedbackManualDesc,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: localizations.feedbackDescription,
                hintText: localizations.feedbackDescriptionHint,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? localizations.feedbackDescriptionRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: localizations.feedbackContact,
                hintText: localizations.feedbackContactHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              theme: theme,
              title: localizations.feedbackScreenshot,
              subtitle: localizations.feedbackScreenshotHint,
              child: _screenshotBytes == null
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickScreenshot,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(localizations.feedbackAddScreenshot),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240),
                            child: Image.memory(
                              _screenshotBytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _screenshotName ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _submitting ? null : _removeScreenshot,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: Text(localizations.delete),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              theme: theme,
              title: localizations.feedbackLogs,
              subtitle: localizations.feedbackLogHint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(localizations.feedbackIncludeAppLog),
                    subtitle: Text(
                      localizations.feedbackIncludeAppLogHint,
                      style: theme.textTheme.bodySmall,
                    ),
                    value: _includeAppLog,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _includeAppLog = value),
                  ),
                  for (final file in _logFiles)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        file.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _submitting
                            ? null
                            : () => _removeLogFile(file),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : _pickLogFiles,
                      icon: const Icon(Icons.note_add_outlined),
                      label: Text(localizations.feedbackAddLogFile),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localizations.feedbackPrivacyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _submitting
                    ? localizations.feedbackSubmitting
                    : localizations.feedbackSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
