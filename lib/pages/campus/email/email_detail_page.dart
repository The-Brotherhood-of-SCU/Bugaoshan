import 'dart:typed_data';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/services/email/email_service.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
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
  Map<String, Uint8List> _inlineImages = const {};

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
      Map<String, Uint8List> inlineImages = const {};
      try {
        inlineImages = await widget.service.fetchInlineImages(message);
      } catch (_) {
        // The message itself is still readable when an inline image fails.
      }
      if (mounted) {
        setState(() {
          _loaded = message;
          _inlineImages = inlineImages;
        });
      }
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
        _buildBody(message),
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

  Widget _buildBody(MimeMessage message) {
    final html = message.decodeTextHtmlPart();
    if (html != null &&
        RegExp(r'<img\b', caseSensitive: false).hasMatch(html)) {
      return _EmailHtmlBody(source: html, images: _inlineImages);
    }
    return _PlainEmailBody(
      text: EmailService.plainText(message),
      images: _inlineImages,
    );
  }
}

class _PlainEmailBody extends StatelessWidget {
  const _PlainEmailBody({required this.text, required this.images});

  final String text;
  final Map<String, Uint8List> images;

  @override
  Widget build(BuildContext context) {
    final cidPattern = RegExp(r'\[cid:([^\]]+)\]', caseSensitive: false);
    final matches = cidPattern.allMatches(text).toList();
    if (matches.isEmpty) return SelectableText(text);

    final children = <Widget>[];
    var offset = 0;
    for (final match in matches) {
      final before = text.substring(offset, match.start).trim();
      if (before.isNotEmpty) children.add(SelectableText(before));
      final cid = match.group(1)!.trim().toLowerCase();
      final image = images[cid];
      if (image != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Image.memory(image, fit: BoxFit.contain),
          ),
        );
      } else {
        children.add(SelectableText(match.group(0)!));
      }
      offset = match.end;
    }
    final after = text.substring(offset).trim();
    if (after.isNotEmpty) children.add(SelectableText(after));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _EmailHtmlBody extends StatelessWidget {
  const _EmailHtmlBody({required this.source, required this.images});

  final String source;
  final Map<String, Uint8List> images;

  @override
  Widget build(BuildContext context) {
    final document = html_parser.parse(source);
    final nodes = _buildNodes(document.body?.nodes ?? const []);
    if (nodes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: nodes,
    );
  }

  List<Widget> _buildNodes(List<dom.Node> nodes) {
    final result = <Widget>[];
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = node.data.trim();
        if (text.isNotEmpty) result.add(SelectableText(text));
        continue;
      }
      if (node is! dom.Element) continue;
      final tag = node.localName?.toLowerCase();
      if (tag == 'script' || tag == 'style' || tag == 'noscript') continue;
      if (tag == 'img') {
        final cid = _contentId(node.attributes['src']);
        final image = cid == null ? null : images[cid];
        if (image != null) {
          result.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Image.memory(image, fit: BoxFit.contain),
            ),
          );
        }
        continue;
      }
      result.addAll(_buildNodes(node.nodes));
    }
    return result;
  }

  String? _contentId(String? value) {
    if (value == null) return null;
    var cid = value.trim().toLowerCase();
    if (cid.startsWith('cid:')) cid = cid.substring(4);
    if (cid.startsWith('<') && cid.endsWith('>')) {
      cid = cid.substring(1, cid.length - 1);
    }
    return cid.isEmpty ? null : cid;
  }
}
