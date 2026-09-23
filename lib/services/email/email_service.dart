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

enum EmailFolder { inbox, junk, drafts, sent, trash }

extension EmailFolderFlag on EmailFolder {
  MailboxFlag get mailboxFlag => switch (this) {
    EmailFolder.inbox => MailboxFlag.inbox,
    EmailFolder.junk => MailboxFlag.junk,
    EmailFolder.drafts => MailboxFlag.drafts,
    EmailFolder.sent => MailboxFlag.sent,
    EmailFolder.trash => MailboxFlag.trash,
  };
}

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
    return fetchFolder(EmailFolder.inbox, page: page);
  }

  Future<List<MimeMessage>> fetchFolder(
    EmailFolder folder, {
    int page = 1,
  }) async {
    final client = _requireClient();
    await client.selectMailboxByFlag(folder.mailboxFlag);
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
    await _requireClient().sendMessageBuilder(builder);
  }

  Future<File> downloadAttachment(MimeMessage message, ContentInfo info) async {
    final part = await _requireClient().fetchMessagePart(message, info.fetchId);
    final bytes = decodeAttachmentBytes(part);
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

  /// Loads CID referenced inline images. Large images are fetched separately
  /// because the message body is intentionally capped when it is opened.
  Future<Map<String, Uint8List>> fetchInlineImages(MimeMessage message) async {
    final infos = <ContentInfo>[
      ...message.findContentInfo(disposition: ContentDisposition.inline),
      ...message.findContentInfo(),
    ];
    final result = <String, Uint8List>{};
    final seen = <String>{};
    for (final info in infos) {
      final cid = _normalizeContentId(info.cid);
      if (cid == null || !seen.add(cid)) continue;

      MimePart? part;
      try {
        part = message.getPart(info.fetchId);
      } catch (_) {
        part = null;
      }
      var bytes = part == null ? null : decodeAttachmentBytes(part);
      if (bytes == null || bytes.isEmpty) {
        try {
          part = await _requireClient().fetchMessagePart(message, info.fetchId);
          bytes = decodeAttachmentBytes(part);
        } catch (_) {
          bytes = null;
        }
      }
      if (bytes != null && bytes.isNotEmpty) result[cid] = bytes;
    }
    return result;
  }

  static String? _normalizeContentId(String? value) {
    if (value == null) return null;
    var normalized = value.trim().toLowerCase();
    if (normalized.startsWith('cid:')) normalized = normalized.substring(4);
    if (normalized.startsWith('<') && normalized.endsWith('>')) {
      normalized = normalized.substring(1, normalized.length - 1);
    }
    return normalized.isEmpty ? null : normalized;
  }

  /// Decodes an attachment without passing raw binary data through UTF-8.
  ///
  /// Coremail can store a sent attachment with the `binary` transfer
  /// encoding. enough_mail's binary MIME decoder converts that data to a
  /// string before decoding it, which changes bytes above 0x7f and produces
  /// an unreadable file. Keep the original body for 7bit/8bit/binary parts,
  /// and also recover the occasional double-base64 encoded sent copy.
  static Uint8List? decodeAttachmentBytes(MimePart part) {
    final transferEncoding = part
        .getHeaderValue('content-transfer-encoding')
        ?.trim()
        .toLowerCase();
    final rawBody = _rawMimeBody(part);
    if (rawBody != null &&
        (transferEncoding == '7bit' ||
            transferEncoding == '8bit' ||
            transferEncoding == 'binary')) {
      return _trimMimeLineEnding(rawBody);
    }

    final decoded = part.decodeContentBinary();
    if (decoded == null) return null;

    // Some sent copies contain base64 text after the MIME layer has already
    // been decoded. Decode it once more only when the result has a known file
    // signature, so ordinary text attachments are left untouched.
    final secondPass = _decodeBase64FileBytes(decoded);
    return secondPass ?? decoded;
  }

  static Uint8List? _rawMimeBody(MimePart part) {
    final data = part.mimeData;
    if (data is BinaryMimeData) {
      final bytes = data.data;
      final marker = const <int>[13, 10, 13, 10];
      for (var i = 0; i <= bytes.length - marker.length; i++) {
        var matches = true;
        for (var j = 0; j < marker.length; j++) {
          if (bytes[i + j] != marker[j]) {
            matches = false;
            break;
          }
        }
        if (matches) return Uint8List.sublistView(bytes, i + marker.length);
      }
      return bytes;
    }
    if (data is TextMimeData) {
      return Uint8List.fromList(utf8.encode(data.body));
    }
    return null;
  }

  static Uint8List _trimMimeLineEnding(Uint8List bytes) {
    if (bytes.length >= 2 &&
        bytes[bytes.length - 2] == 13 &&
        bytes[bytes.length - 1] == 10) {
      return Uint8List.sublistView(bytes, 0, bytes.length - 2);
    }
    return bytes;
  }

  static Uint8List? _decodeBase64FileBytes(Uint8List bytes) {
    if (bytes.length < 8) return null;
    final text = String.fromCharCodes(bytes);
    if (!RegExp(r'^[A-Za-z0-9+/=\r\n\t ]+$').hasMatch(text)) {
      return null;
    }
    final compact = text.replaceAll(RegExp(r'\s'), '');
    if (compact.length < 8 || compact.length % 4 != 0) return null;
    try {
      final decoded = Uint8List.fromList(base64.decode(compact));
      return _hasKnownFileSignature(decoded) ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static bool _hasKnownFileSignature(Uint8List bytes) {
    bool startsWith(List<int> signature) {
      if (bytes.length < signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[i] != signature[i]) return false;
      }
      return true;
    }

    if (startsWith(const [0xff, 0xd8, 0xff]) ||
        startsWith(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]) ||
        startsWith(const [0x47, 0x49, 0x46, 0x38]) ||
        startsWith(const [0x25, 0x50, 0x44, 0x46]) ||
        startsWith(const [0x50, 0x4b, 0x03, 0x04])) {
      return true;
    }
    return bytes.length >= 12 &&
        startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
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
