import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/battle.dart';
import '../widgets/battle_card.dart';
import 'battle_detail_page.dart';

class ArchiveBattlePage extends StatefulWidget {
  const ArchiveBattlePage({super.key});

  @override
  State<ArchiveBattlePage> createState() => _ArchiveBattlePageState();
}

class _ArchiveBattlePageState extends State<ArchiveBattlePage> {
  List<Battle> _battles = [];
  bool _isLoading = true;
  final Set<String> _expandedMonths = {};
  final Map<String, int?> _myRanks = {};
  final Map<String, String> _battleRules = {};
  final Map<String, double?> _myTargetValues = {};

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isArchived(Battle battle) {
    final endDate = _dateOnly(battle.endDate);
    final archiveDate = endDate.add(const Duration(days: 7));

    return archiveDate.isBefore(_today);
  }

  Map<String, List<Battle>> _groupedBattles() {
    final grouped = <String, List<Battle>>{};

    for (final battle in _battles) {
      final key = '${battle.endDate.year}年${battle.endDate.month}月';
      grouped.putIfAbsent(key, () => []).add(battle);
    }

    return grouped;
  }

  double _scoreForRule({
    required String rule,
    required double currentValue,
    required double? targetValue,
  }) {
    switch (rule) {
      case 'higher_is_better':
        return currentValue;
      case 'lower_is_better':
        return -currentValue;
      case 'above_my_target':
        return currentValue - (targetValue ?? 0);
      case 'below_my_target':
        return (targetValue ?? 0) - currentValue;
      case 'closest_to_my_target':
        return -((currentValue - (targetValue ?? 0)).abs());
      default:
        return currentValue;
    }
  }

  Future<void> _fetchMyRanks({
    required List<Battle> battles,
    required String userId,
  }) async {
    if (battles.isEmpty) return;

    final battleIds = battles.map((battle) => battle.id).toList();

    final response = await Supabase.instance.client
        .from('battle_records')
        .select('battle_id,user_id,value,created_at')
        .inFilter('battle_id', battleIds);

    final rows = response as List;
    final scoresByBattle = <String, Map<String, double>>{};

    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      final battleId = map['battle_id'] as String;
      final recordUserId = map['user_id'] as String;
      final value = ((map['value'] as num?) ?? 0).toDouble();

      scoresByBattle.putIfAbsent(battleId, () => {});
      scoresByBattle[battleId]![recordUserId] =
          (scoresByBattle[battleId]![recordUserId] ?? 0) + value;
    }

    final ranks = <String, int?>{};

    for (final battle in battles) {
      final scores = scoresByBattle[battle.id];

      if (scores == null || !scores.containsKey(userId)) {
        ranks[battle.id] = null;
        continue;
      }

      final rule = _battleRules[battle.id] ?? '';
      final targetValue = _myTargetValues[battle.id];
      final entries = scores.entries.toList();

      entries.sort((a, b) {
        final aScore = _scoreForRule(
          rule: rule,
          currentValue: a.value,
          targetValue: targetValue,
        );
        final bScore = _scoreForRule(
          rule: rule,
          currentValue: b.value,
          targetValue: targetValue,
        );

        return bScore.compareTo(aScore);
      });

      final index = entries.indexWhere((entry) => entry.key == userId);
      ranks[battle.id] = index == -1 ? null : index + 1;
    }

    _myRanks
      ..clear()
      ..addAll(ranks);
  }

  @override
  void initState() {
    super.initState();
    _fetchArchiveBattles();
  }

  Future<void> _fetchArchiveBattles() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('battle_participants')
          .select('target_value,battles(*)')
          .eq('user_id', userId);

      final rows = response as List;

      _battleRules.clear();
      _myTargetValues.clear();

      final battles = rows
          .map((row) {
            final map = row as Map<String, dynamic>;
            final battleMap = map['battles'] as Map<String, dynamic>?;

            if (battleMap == null) return null;

            final battle = Battle.fromMap(battleMap);
            _battleRules[battle.id] = battleMap['rule'] as String? ?? '';
            _myTargetValues[battle.id] =
                (map['target_value'] as num?)?.toDouble();

            return battle;
          })
          .whereType<Battle>()
          .where(_isArchived)
          .toList();

      battles.sort((a, b) => b.endDate.compareTo(a.endDate));

      await _fetchMyRanks(
        battles: battles,
        userId: userId,
      );

      if (!mounted) return;

      setState(() {
        _battles = battles;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('fetch archive battles error=$e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      appBar: AppBar(
        title: const Text('アーカイブ'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _battles.isEmpty
              ? const Center(
                  child: Text(
                    'アーカイブされたバトルはまだありません。',
                    style: TextStyle(
                      color: Color(0xFF7D6B5D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : Builder(
                  builder: (context) {
                    final grouped = _groupedBattles();
                    final months = grouped.keys.toList();

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: months.length,
                      itemBuilder: (context, index) {
                        final month = months[index];
                        final battles = grouped[month]!;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              initiallyExpanded: index == 0,
                              onExpansionChanged: (expanded) {
                                setState(() {
                                  if (expanded) {
                                    _expandedMonths.add(month);
                                  } else {
                                    _expandedMonths.remove(month);
                                  }
                                });
                              },
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      month,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4EFE8),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${battles.length}件',
                                      style: const TextStyle(
                                        color: Color(0xFF7D6B5D),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 2,
                              ),
                              childrenPadding: const EdgeInsets.only(bottom: 4),
                              children: battles.map((battle) {
                                final rank = _myRanks[battle.id];

                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    12,
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BattleDetailPage(
                                            battle: battle,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Stack(
                                      children: [
                                        BattleCard(data: battle),
                                        if (rank != null)
                                          Positioned(
                                            bottom: 12,
                                            right: 12,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 7,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE9F5EE),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.06),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                '結果 $rank位',
                                                style: const TextStyle(
                                                  color: Color(0xFF2F6B4F),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}