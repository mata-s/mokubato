import '../models/ranking_entry.dart';

class RankingService {
  const RankingService._();

  static double calculateScore({
    required double targetValue,
    required double currentValue,
    required String rule,
  }) {
    switch (rule) {
      case 'higher_is_better':
        return currentValue;

      case 'lower_is_better':
        return -currentValue;

      case 'above_my_target':
        if (targetValue == 0) return currentValue;
        return 100 + ((currentValue - targetValue) / targetValue.abs()) * 100;
        
      case 'below_my_target':
        if (targetValue == 0) return -currentValue.abs();
        return ((targetValue - currentValue) / targetValue)
        .clamp(0.0, 1.0) *
        100;

      case 'closest_to_my_target':
        if (targetValue == 0) return -currentValue.abs();
        return (1 - ((currentValue - targetValue).abs() / targetValue.abs())) *
            100;

      default:
        return currentValue;
    }
  }

  static List<RankingEntry> buildRanking({
    required List<RankingEntry> entries,
  }) {
    final sortedEntries = [...entries]
      ..sort((a, b) => b.score.compareTo(a.score));

    final rankedEntries = <RankingEntry>[];
    double? previousScore;
    var previousRank = 0;

    for (var i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final rank = previousScore == entry.score ? previousRank : i + 1;

      rankedEntries.add(entry.copyWith(rank: rank));

      previousScore = entry.score;
      previousRank = rank;
    }

    return rankedEntries;
  }
}
