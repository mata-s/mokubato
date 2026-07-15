class RankingEntry {
  const RankingEntry({
    required this.userId,
    required this.displayName,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.score,
    required this.rank,
  });

  final String userId;
  final String displayName;
  final double targetValue;
  final double currentValue;
  final String unit;
  final double score;
  final int rank;

  RankingEntry copyWith({
    int? rank,
  }) {
    return RankingEntry(
      userId: userId,
      displayName: displayName,
      targetValue: targetValue,
      currentValue: currentValue,
      unit: unit,
      score: score,
      rank: rank ?? this.rank,
    );
  }
}