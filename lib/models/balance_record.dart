class BalanceRecord {
  final int? id;
  final String roomKey;
  final int balanceType;
  final DateTime timestamp;
  final double balance;
  final double price;

  const BalanceRecord({
    this.id,
    required this.roomKey,
    required this.balanceType,
    required this.timestamp,
    required this.balance,
    required this.price,
  });

  factory BalanceRecord.fromRow(Map<String, dynamic> row) {
    return BalanceRecord(
      id: row['id'] as int?,
      roomKey: row['room_key'] as String,
      balanceType: row['balance_type'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        row['timestamp'] as int,
        isUtc: true,
      ),
      balance: (row['balance'] as num).toDouble(),
      price: (row['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toRow() => {
    if (id != null) 'id': id,
    'room_key': roomKey,
    'balance_type': balanceType,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'balance': balance,
    'price': price,
  };

  BalanceRecord copyWith({
    int? id,
    String? roomKey,
    int? balanceType,
    DateTime? timestamp,
    double? balance,
    double? price,
  }) {
    return BalanceRecord(
      id: id ?? this.id,
      roomKey: roomKey ?? this.roomKey,
      balanceType: balanceType ?? this.balanceType,
      timestamp: timestamp ?? this.timestamp,
      balance: balance ?? this.balance,
      price: price ?? this.price,
    );
  }
}
