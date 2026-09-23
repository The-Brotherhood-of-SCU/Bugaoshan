import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/services/email/email_service.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

class EmailDetailPage extends StatefulWidget {
  const EmailDetailPage({
    super.key,
    required this.service,
    required this.message,
    required this.subject,
  });

  final EmailService service;
  final MimeMessage message;

  /// The decoded IMAP envelope subject, before full-message header parsing.
  final String subject;

  @override
  State<EmailDetailPage> createState() => _EmailDetailPageState();
}

class _EmailDetailPageState extends State<EmailDetailPage> {
  MimeMessage? _loaded;
  bool _busy = true;
  String? _downloading;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final message = await widget.service.readMessage(widget.message);
      if (mounted) setState(() => _loaded = message);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAttachment(ContentInfo info) async {
    if (_downloading != null) return;
    setState(() => _downloading = info.fetchId);
    final l10n = AppLocalizations.of(context)!;
    try {
      final file = await widget.service.downloadAttachment(_loaded!, info);
      final result = await OpenFilex.open(file.path);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.emailOpenFailed)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.emailAttachmentFailed)));
      }
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = _loaded;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.campusEmail)),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _failed || message == null
          ? Center(
              child: FilledButton(
                onPressed: _load,
                child: Text(l10n.emailReadFailed),
              ),
            )
          : _buildMessage(message, l10n),
    );
  }

  Widget _buildMessage(MimeMessage message, AppLocalizations l10n) {
    final sender = message.from?.firstOrNull;
    final senderText = sender == null
        ? ''
        : sender.personalName?.isNotEmpty == true
        ? '${sender.personalName} <${sender.email}>'
        : sender.email;
    final date = message.decodeDate();
    final attachments = message.findContentInfo();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(widget.subject, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text(senderText, style: Theme.of(context).textTheme.titleSmall),
        if (date != null) ...[
          const SizedBox(height: 4),
          Text(
            DateFormat('yyyy-MM-dd HH:mm').format(date),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const Divider(height: 32),
        SelectableText(EmailService.plainText(message)),
        if (attachments.isNotEmpty) ...[
          const Divider(height: 32),
          Text(
            l10n.emailAttachment,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final info in attachments)
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(info.fileName ?? l10n.emailAttachment),
              subtitle: info.size == null ? null : Text('${info.size} B'),
              trailing: _downloading == info.fetchId
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_new),
              onTap: () => _openAttachment(info),
            ),
        ],
      ],
    );
  }
}
