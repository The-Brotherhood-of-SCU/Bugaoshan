import 'dart:async';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/email/email_compose_page.dart';
import 'package:bugaoshan/pages/campus/email/email_detail_page.dart';
import 'package:bugaoshan/services/email/email_account.dart';
import 'package:bugaoshan/services/email/email_service.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailPage extends StatefulWidget {
  const EmailPage({super.key});

  @override
  State<EmailPage> createState() => _EmailPageState();
}

class _EmailPageState extends State<EmailPage> {
  final _service = EmailService();
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _imapHost = TextEditingController(text: EmailAccount.defaultHost);
  final _imapPort = TextEditingController(text: '993');
  final _smtpHost = TextEditingController(text: EmailAccount.defaultHost);
  final _smtpPort = TextEditingController(text: '465');
  List<MimeMessage> _messages = [];
  bool _busy = true;
  bool _connected = false;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _obscurePassword = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final saved = await _service.loadSavedAccount();
      if (saved == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      _fill(saved);
      await _connect(saved, persist: false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AppLocalizations.of(context)!.emailConnectFailed;
        });
      }
    }
  }

  void _fill(EmailAccount account) {
    _address.text = account.address;
    _password.text = account.password;
    _imapHost.text = account.imapHost;
    _imapPort.text = account.imapPort.toString();
    _smtpHost.text = account.smtpHost;
    _smtpPort.text = account.smtpPort.toString();
  }

  Future<void> _connect(EmailAccount account, {required bool persist}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final messages = await _service.connect(account);
      if (persist) await _service.saveAccount(account);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _page = 1;
        _hasMore = messages.length == 30;
        _connected = true;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _connectionError(AppLocalizations.of(context)!, error);
      });
    }
  }

  String _connectionError(AppLocalizations l10n, Object error) {
    if (error is EmailConnectionException) {
      return switch (error.stage) {
        EmailConnectionStage.imapLogin => l10n.emailImapConnectionFailed,
        EmailConnectionStage.inbox => l10n.emailInboxConnectionFailed,
        EmailConnectionStage.smtpLogin => l10n.emailSmtpConnectionFailed,
      };
    }
    return l10n.emailConnectFailed;
  }

  Future<void> _openWebmail() async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://mail.stu.scu.edu.cn/'),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.emailOpenWebmailFailed),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final account = EmailAccount(
      address: _address.text.trim(),
      password: _password.text,
      imapHost: _imapHost.text.trim(),
      imapPort: int.parse(_imapPort.text.trim()),
      smtpHost: _smtpHost.text.trim(),
      smtpPort: int.parse(_smtpPort.text.trim()),
    );
    unawaited(_connect(account, persist: true));
  }

  Future<void> _refresh() async {
    try {
      final messages = await _service.fetchInbox();
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _page = 1;
        _hasMore = messages.length == 30;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.emailLoadFailed),
          ),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _service.fetchInbox(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _messages.addAll(more);
        _page++;
        _hasMore = more.length == 30;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.emailLoadFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _unlink() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.emailUnlink),
        content: Text(l10n.emailUnlinkConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.emailUnlink),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.forgetAccount();
    if (!mounted) return;
    _password.clear();
    setState(() {
      _messages = [];
      _connected = false;
      _error = null;
    });
  }

  @override
  void dispose() {
    unawaited(_service.disconnect());
    _address.dispose();
    _password.dispose();
    _imapHost.dispose();
    _imapPort.dispose();
    _smtpHost.dispose();
    _smtpPort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.campusEmail),
        actions: _connected
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.refresh,
                  onPressed: _refresh,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'unlink') unawaited(_unlink());
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'unlink',
                      child: Text(l10n.emailUnlink),
                    ),
                  ],
                ),
              ]
            : null,
      ),
      floatingActionButton: _connected
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => EmailComposePage(service: _service),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.emailCompose),
            )
          : null,
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _connected
          ? _buildInbox(l10n)
          : _buildSetup(l10n),
    );
  }

  Widget _buildInbox(AppLocalizations l10n) => RefreshIndicator(
    onRefresh: _refresh,
    child: _messages.isEmpty
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 320,
                child: Center(child: Text(l10n.emailInboxEmpty)),
              ),
            ],
          )
        : _buildMessageList(l10n),
  );

  Widget _buildMessageList(AppLocalizations l10n) => ListView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    itemCount: _messages.length + (_hasMore ? 1 : 0),
    itemBuilder: (context, index) {
      if (index == _messages.length) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: _loadingMore
                ? const CircularProgressIndicator()
                : TextButton(
                    onPressed: _loadMore,
                    child: Text(l10n.courseCurriculumLoadMore),
                  ),
          ),
        );
      }
      final message = _messages[index];
      final sender = message.from?.firstOrNull;
      final title = sender?.personalName?.isNotEmpty == true
          ? sender!.personalName!
          : sender?.email ?? '';
      final subject = message.decodeSubject();
      final date = message.decodeDate();
      return ListTile(
        leading: Icon(
          message.isSeen
              ? Icons.mark_email_read_outlined
              : Icons.mark_email_unread,
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: message.isSeen
              ? null
              : const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subject?.isNotEmpty == true ? subject! : l10n.emailSubject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: date == null ? null : Text(DateFormat('M/d').format(date)),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => EmailDetailPage(
                service: _service,
                message: message,
                subject: subject ?? '',
              ),
            ),
          );
          if (mounted) setState(() {});
        },
      );
    },
  );

  Widget _buildSetup(AppLocalizations l10n) => Form(
    key: _formKey,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          l10n.emailSetupTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(l10n.emailSetupHint),
        const SizedBox(height: 8),
        Text(l10n.emailVerificationHint),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _openWebmail,
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.emailOpenWebmail),
          ),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
        ],
        TextFormField(
          controller: _address,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(labelText: l10n.emailAddress),
          validator: (value) =>
              RegExp(
                r'^[^@\s]+@stu\.scu\.edu\.cn$',
                caseSensitive: false,
              ).hasMatch(value?.trim() ?? '')
              ? null
              : l10n.emailInvalidAddress,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _password,
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: l10n.emailPassword,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
          validator: (value) =>
              value == null || value.isEmpty ? l10n.emailRequired : null,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _imapHost,
          decoration: InputDecoration(labelText: l10n.emailImapHost),
          validator: (value) =>
              value == null || value.trim().isEmpty ? l10n.emailRequired : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _imapPort,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.emailImapPort),
          validator: (value) =>
              _validPort(value) ? null : l10n.emailInvalidPort,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _smtpHost,
          decoration: InputDecoration(labelText: l10n.emailSmtpHost),
          validator: (value) =>
              value == null || value.trim().isEmpty ? l10n.emailRequired : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _smtpPort,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.emailSmtpPort),
          validator: (value) =>
              _validPort(value) ? null : l10n.emailInvalidPort,
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _submit, child: Text(l10n.emailConnect)),
      ],
    ),
  );

  bool _validPort(String? value) {
    final port = int.tryParse(value?.trim() ?? '');
    return port != null && port >= 1 && port <= 65535;
  }
}
