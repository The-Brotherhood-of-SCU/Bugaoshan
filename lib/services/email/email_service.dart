import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bugaoshan/services/email/email_account.dart';
import 'package:bugaoshan/utils/secure_storage.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

enum EmailConnectionStage { imapLogin, inbox, smtpLogin }

/// Identifies the failed step without exposing server responses or credentials.
class EmailConnectionException implements Exception {
  const EmailConnectionException(this.stage);

  final EmailConnectionStage stage;
}

class EmailAttachment {
  const EmailAttachment({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  int get size => bytes.length;
}

/// Email has its own credentials and is deliberately outside ScuAuth.
class EmailService {
  EmailService();

  static const _accountKey = 'campus_email_account_v1';
  MailClient? _client;
  EmailAccount? _account;

  EmailAccount? get account => _account;

  Future<EmailAccount?> loadSavedAccount() async {
    final saved = await SecureStorageProvider.instance.read(key: _accountKey);
    if (saved == null) return null;
    try {
      return EmailAccount.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<List<MimeMessage>> connect(EmailAccount account) async {
    final mailAccount = MailAccount.fromManualSettings(
      name: 'SCU student mail',
      email: account.address,
      password: account.password,
      incomingHost: account.imapHost,
      incomingPort: account.imapPort,
      outgoingHost: account.smtpHost,
      outgoingPort: account.smtpPort,
      outgoingClientDomain: 'stu.scu.edu.cn',
    );
    final next = MailClient(mailAccount, isLogEnabled: false);
    try {
      try {
        await next.connect(timeout: const Duration(seconds: 15));
      } catch (_) {
        throw const EmailConnectionException(EmailConnectionStage.imapLogin);
      }
      late final List<MimeMessage> messages;
      try {
        await next.selectInbox();
        messages = await next.fetchMessages(
          count: 30,
          fetchPreference: FetchPreference.envelope,
        );
      } catch (_) {
        throw const EmailConnectionException(EmailConnectionStage.inbox);
      }
      // Authenticate SMTP before saving credentials, without sending a message.
      try {
        await next.supports8BitEncoding();
      } catch (_) {
        throw const EmailConnectionException(EmailConnectionStage.smtpLogin);
      }
      try {
        await next.lowLevelOutgoingMailClient.disconnect();
      } catch (_) {
        // SMTP authentication succeeded; keep the verified IMAP connection.
      }
      final previous = _client;
      _client = next;
      _account = account;
      if (previous != null) {
        try {
          await previous.disconnect();
        } catch (_) {
          // The new authenticated connection is ready even if cleanup fails.
        }
      }
      return messages.reversed.toList();
    } catch (_) {
      try {
        await next.disconnect();
      } catch (_) {
        // Keep the original connection failure.
      }
      rethrow;
    }
  }

  Future<void> saveAccount(EmailAccount account) => SecureStorageProvider
      .instance
      .write(key: _accountKey, value: jsonEncode(account.toJson()));

  Future<void> forgetAccount() async {
    await SecureStorageProvider.instance.delete(key: _accountKey);
    await disconnect();
  }

  Future<List<MimeMessage>> fetchInbox({int page = 1}) async {
    final client = _requireClient();
    await client.selectInbox();
    final messages = await client.fetchMessages(
      count: 30,
      page: page,
      fetchPreference: FetchPreference.envelope,
    );
    return messages.reversed.toList();
  }

  Future<MimeMessage> readMessage(MimeMessage message) async {
    final loaded = await _requireClient().fetchMessageContents(
      message,
      maxSize: 1024 * 1024,
      markAsSeen: true,
    );
    message.isSeen = true;
    return loaded;
  }

  Future<void> send({
    required String recipient,
    required String subject,
    required String body,
    List<EmailAttachment> attachments = const [],
  }) async {
    final from = _account?.address;
    if (from == null) throw StateError('Email account is not connected');
    final builder = MessageBuilder.prepareMultipartMixedMessage()
      ..from = [MailAddress(null, from)]
      ..to = [MailAddress(null, recipient)]
      ..subject = subject
      ..addTextPlain(body);
    for (final attachment in attachments) {
      builder.addBinary(
        attachment.bytes,
        MediaType.guessFromFileName(attachment.name),
        filename: attachment.name,
      );
    }
    await _requireClient().sendMessageBuilder(builder, appendToSent: false);
  }

  Future<File> downloadAttachment(MimeMessage message, ContentInfo info) async {
    final part = await _requireClient().fetchMessagePart(message, info.fetchId);
    final bytes = part.decodeContentBinary();
    if (bytes == null) throw StateError('Attachment content is unavailable');
    final base = path.basename(info.fileName ?? 'attachment');
    final safeName = base.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      path.join(root.path, 'Bugaoshan', 'email_attachments'),
    );
    await directory.create(recursive: true);
    final file = File(
      path.join(
        directory.path,
        '${DateTime.now().microsecondsSinceEpoch}_$safeName',
      ),
    );
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<void> disconnect() async {
    final old = _client;
    _client = null;
    _account = null;
    if (old != null) {
      try {
        await old.disconnect();
      } catch (_) {
        // A dropped connection may already be closed by the server.
      }
    }
  }

  MailClient _requireClient() {
    final client = _client;
    if (client == null) throw StateError('Email account is not connected');
    return client;
  }

  static String plainText(MimeMessage message) {
    final plain = message.decodeTextPlainPart();
    if (plain != null && plain.trim().isNotEmpty) return plain;
    final html = message.decodeTextHtmlPart();
    if (html == null) return '';
    final readableHtml = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</(?:p|div|li|tr|h[1-6])\s*>', caseSensitive: false),
          '\n',
        );
    final document = html_parser.parse(readableHtml);
    document.querySelectorAll('script, style, noscript').forEach((node) {
      node.remove();
    });
    return document.body?.text.trim() ?? '';
  }
}
