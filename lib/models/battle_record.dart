class BattleRecord {
  const BattleRecord({
    required this.value,
    required this.memo,
    required this.createdAt,
    this.imageUrl,
  });

  final double value;
  final String memo;
  final DateTime createdAt;
  final String? imageUrl;
}