class EmailAccount {
  const EmailAccount({
    required this.address,
    required this.password,
    required this.imapHost,
    required this.imapPort,
    required this.smtpHost,
    required this.smtpPort,
  });

  final String address;
  final String password;
  final String imapHost;
  final int imapPort;
  final String smtpHost;
  final int smtpPort;

  // Both encrypted mail ports present a valid certificate for this host.
  static const defaultHost = 'uni-edu.icoremail.net';
  static const studentDomain = 'stu.scu.edu.cn';

  static String addressForUsername(String username) =>
      '${username.trim()}@$studentDomain';

  static String usernameFromAddress(String address) {
    const suffix = '@$studentDomain';
    return address.toLowerCase().endsWith(suffix)
        ? address.substring(0, address.length - suffix.length)
        : address;
  }

  Map<String, Object> toJson() => {
    'address': address,
    'password': password,
    'imapHost': imapHost,
    'imapPort': imapPort,
    'smtpHost': smtpHost,
    'smtpPort': smtpPort,
  };

  factory EmailAccount.fromJson(Map<String, dynamic> json) => EmailAccount(
    address: json['address'] as String,
    password: json['password'] as String,
    imapHost: json['imapHost'] as String,
    imapPort: json['imapPort'] as int,
    smtpHost: json['smtpHost'] as String,
    smtpPort: json['smtpPort'] as int,
  );
}
