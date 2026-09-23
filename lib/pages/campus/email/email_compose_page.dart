import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/services/email/email_service.dart';
import 'package:flutter/material.dart';

class EmailComposePage extends StatefulWidget {
  const EmailComposePage({super.key, required this.service});

  final EmailService service;

  @override
  State<EmailComposePage> createState() => _EmailComposePageState();
}

class _EmailComposePageState extends State<EmailComposePage> {
  final _formKey = GlobalKey<FormState>();
  final _recipient = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    if (!_formKey.currentState!.validate() || _sending) return;
    setState(() => _sending = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await widget.service.send(
        recipient: _recipient.text.trim(),
        subject: _subject.text.trim(),
        body: _body.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.emailSent)));
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.emailSendFailed)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _recipient.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.emailCompose)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _recipient,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: l10n.emailRecipient),
              validator: (value) =>
                  RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(value?.trim() ?? '')
                  ? null
                  : l10n.emailRequired,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subject,
              decoration: InputDecoration(labelText: l10n.emailSubject),
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.emailRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _body,
              minLines: 10,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(labelText: l10n.emailBody),
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.emailRequired
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(l10n.emailSend),
            ),
          ],
        ),
      ),
    );
  }
}
