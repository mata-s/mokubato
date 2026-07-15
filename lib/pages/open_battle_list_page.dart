import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'invite_list_page.dart';

class OpenBattleListPage extends StatefulWidget {
  const OpenBattleListPage({super.key});

  @override
  State<OpenBattleListPage> createState() => _OpenBattleListPageState();
}

class _OpenBattleListPageState extends State<OpenBattleListPage> {
  List<Map<String, dynamic>> _openBattles = [];
  bool _isLoading = true;
  String? _message;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchOpenBattles();
  }

  Future<void> _fetchOpenBattles() async {
    try {
      final myUserId = Supabase.instance.client.auth.currentUser?.id;

      if (myUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final openRows = await Supabase.instance.client
          .from('battles')
          .select('id,title,description,rule,start_date,end_date,created_by')
          .eq('is_open', true)
          .order('created_at', ascending: false);

      final participantRows = await Supabase.instance.client
          .from('battle_participants')
          .select('battle_id,user_id,unit,target_value');

      final joinedBattleIds = <String>{};
      final participantCounts = <String, int>{};
      final unitMap = <String, String>{};
      final creatorTargetValueMap = <String, double?>{};

      for (final item in participantRows as List) {
        final map = item as Map<String, dynamic>;
        final battleId = map['battle_id'] as String;
        final userId = map['user_id'] as String;

        participantCounts[battleId] = (participantCounts[battleId] ?? 0) + 1;
        unitMap.putIfAbsent(battleId, () => map['unit'] as String? ?? '');

        if (creatorTargetValueMap[battleId] == null) {
          creatorTargetValueMap[battleId] =
            (map['target_value'] as num?)?.toDouble();
        }

        if (userId == myUserId) {
          joinedBattleIds.add(battleId);
        }
      }

      final creatorIds = (openRows as List)
          .map((item) => (item as Map<String, dynamic>)['created_by'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      final profiles = creatorIds.isEmpty
          ? <dynamic>[]
          : await Supabase.instance.client
              .from('profiles')
              .select('id,name')
              .inFilter('id', creatorIds);

      final creatorNames = <String, String>{};
      for (final profile in profiles) {
        final map = profile as Map<String, dynamic>;
        creatorNames[map['id'] as String] = map['name'] as String? ?? '名無し';
      }

      final battles = openRows.map((item) {
        final map = item;
        final battleId = map['id'] as String;
        final createdBy = map['created_by'] as String? ?? '';

        return {
          ...map,
          'participantCount': participantCounts[battleId] ?? 0,
          'unit': unitMap[battleId] ?? '',
          'creatorName': creatorNames[createdBy] ?? '名無し',
        };
      }).where((battle) {
        return !joinedBattleIds.contains(battle['id']);
      }).toList();

      if (!mounted) return;

      setState(() {
        _openBattles = battles;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _openBattles = [];
        _isLoading = false;
        _message = 'オープンバトルの取得に失敗しました。';
      });
    }
  }

  String _ruleTitle(String rule) {
    switch (rule) {
      case 'higher_is_better':
        return '多い人が勝ち';
      case 'lower_is_better':
        return '少ない人が勝ち';
      case 'above_my_target':
        return '目標より上が勝ち';
      case 'below_my_target':
        return '目標より下が勝ち';
      case 'closest_to_my_target':
        return '目標に近い人が勝ち';
      default:
        return rule;
    }
  }

  String _periodYearLabel(DateTime startDate, DateTime endDate) {
  if (startDate.year == endDate.year) {
    return '${startDate.year}年';
  }

  return '${startDate.year}年〜${endDate.year}年';
}

String _periodDateLabel(DateTime startDate, DateTime endDate) {
  return '${startDate.month}/${startDate.day}〜${endDate.month}/${endDate.day}';
}

  bool _isUpcomingBattle(Map<String, dynamic> battle) {
    final startDate = DateTime.parse(battle['start_date'] as String);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);

    return today.isBefore(start);
  }

  bool _isFinishedBattle(Map<String, dynamic> battle) {
    final endDate = DateTime.parse(battle['end_date'] as String);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    return today.isAfter(end);
  }

  Widget _buildBattleCards({
    required List<Map<String, dynamic>> battles,
  }) {
    if (battles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'このカテゴリのバトルはありません。',
          style: TextStyle(
            color: Color(0xFF7D6B5D),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...battles.map((battle) {
          final startDate = DateTime.parse(
            battle['start_date'] as String,
          );

          final endDate = DateTime.parse(
            battle['end_date'] as String,
          );

          final isUpcoming = _isUpcomingBattle(battle);
          final isFinished = _isFinishedBattle(battle);

          return _OpenBattleCard(
            title: battle['title'] as String? ?? 'バトル',
            description: battle['description'] as String? ?? '',
            ruleLabel: _ruleTitle(battle['rule'] as String? ?? ''),
            periodYearLabel: _periodYearLabel(startDate, endDate),
            periodDateLabel: _periodDateLabel(startDate, endDate),
            participantCount: battle['participantCount'] as int,
            creatorName: battle['creatorName'] as String,
            onJoin: () => _openJoinPage(battle),
            canJoin: !isFinished,
            isUpcoming: isUpcoming,
            isFinished: isFinished,
          );
        }),
      ],
    );
  }

  Future<void> _openJoinPage(Map<String, dynamic> battle) async {
    final joined = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => JoinBattlePage(
          invite: {
            'id': '',
            'battleId': battle['id'],
            'battleTitle': battle['title'] ?? 'バトル',
            'senderName': '公開バトル',
            'unit': battle['unit'] ?? '',
            'rule': battle['rule'] ?? '',
            'source': 'open',
            'creatorTargetValue': battle['creatorTargetValue'],
          }
        ),
      ),
    );

    if (joined == true) {
      _fetchOpenBattles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleBattles = _openBattles.where((battle) {
      return !_isFinishedBattle(battle);
    }).toList();

    final upcomingBattles = visibleBattles.where(_isUpcomingBattle).toList();

    final activeBattles = visibleBattles.where((battle) {
      return !_isUpcomingBattle(battle);
    }).toList();

    final selectedBattles =
        _selectedTabIndex == 0 ? activeBattles : upcomingBattles;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8EF),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'オープンバトル',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '参加できるバトル',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '気になるオープンバトルに参加して、自分の目標値を設定しましょう。',
                    style: TextStyle(
                      color: Color(0xFF7D6B5D),
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      style: const TextStyle(
                        color: Color(0xFF7D6B5D),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (!_isLoading && visibleBattles.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        '参加できるオープンバトルはありません。',
                        style: TextStyle(
                          color: Color(0xFF7D6B5D),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: _selectedTabIndex,
                        children: {
                          0: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('開催中 ${activeBattles.length}'),
                          ),
                          1: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('開催予定 ${upcomingBattles.length}'),
                          ),
                        },
                        onValueChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedTabIndex = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildBattleCards(battles: selectedBattles),
                  ],
                ],
              ),
            ),
          ),
          if (_isLoading)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpenBattleCard extends StatelessWidget {
  const _OpenBattleCard({
    required this.title,
    required this.description,
    required this.ruleLabel,
    required this.periodYearLabel,
    required this.periodDateLabel,
    required this.participantCount,
    required this.creatorName,
    required this.onJoin,
    required this.canJoin,
    required this.isUpcoming,
    required this.isFinished,
  });

  final String title;
  final String description;
  final String ruleLabel;
  final String periodYearLabel;
  final String periodDateLabel;
  final int participantCount;
  final String creatorName;
  final bool canJoin;
  final bool isUpcoming;
  final bool isFinished;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8EF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  periodYearLabel,
                  style: const TextStyle(
                    color: Color(0xFF7D6B5D),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  periodDateLabel,
                  style: const TextStyle(
                    color: Color(0xFF2B211A),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8EF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'オープン',
                  style: TextStyle(
                    color: Color(0xFF7D6B5D),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _OpenBattleDescriptionPreview(text: description),
          ],
          const SizedBox(height: 12),
          _OpenBattleChip(
            icon: Icons.emoji_events_outlined,
            label: ruleLabel,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OpenBattleChip(
                icon: Icons.group_outlined,
                label: '$participantCount人参加中',
              ),
              _OpenBattleChip(
                icon: Icons.person_outline,
                label: '主催者: $creatorName',
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: canJoin ? onJoin : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF5A623),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE4DDD3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isFinished
                    ? '終了'
                    : isUpcoming
                        ? '参加予約'
                        : '途中参加',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenBattleDescriptionPreview extends StatelessWidget {
  const _OpenBattleDescriptionPreview({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Color(0xFF7D6B5D),
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
            if (isOverflowing) ...[
              const SizedBox(height: 2),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) {
                      return Container(
                        padding: const EdgeInsets.fromLTRB(
                          24,
                          12,
                          24,
                          32,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF8EF),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Container(
                                    width: 42,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD8D1C7),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  '説明',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  text,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.7,
                                    color: Color(0xFF2B211A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                child: const Text(
                  '続きを読む',
                  style: TextStyle(
                    color: Color(0xFFE9A23B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _OpenBattleChip extends StatelessWidget {
  const _OpenBattleChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: const Color(0xFF7D6B5D),
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7D6B5D),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}