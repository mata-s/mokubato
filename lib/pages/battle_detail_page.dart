import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/battle.dart';
import 'record_page.dart';
import 'battle_board_page.dart';
import 'invite_friend_page.dart';
import '../models/ranking_entry.dart';
import '../services/ranking_service.dart';

class BattleDetailPage extends StatefulWidget {
  const BattleDetailPage({super.key, required this.battle});

  final Battle battle;

  @override
  State<BattleDetailPage> createState() => _BattleDetailPageState();
}

class _BattleDetailPageState extends State<BattleDetailPage> {
  Battle get battle => widget.battle;

  double? _targetValue;
  double? _currentValue;
  String? _unit;
  bool _isLoadingParticipant = true;

  List<RankingEntry> _rankingEntries = [];
  bool _isLoadingRanking = true;
  String? _hostName;
  bool _isLoadingHost = true;
  int _participantCount = 0;

  List<_RecordItem> _records = [];
  bool _isLoadingRecords = true;
  bool _showAllRanking = false;

  RecordType get _recordType {
    return battle.recordType == 'current'
        ? RecordType.current
        : RecordType.increment;
  }

  void _refreshAfterRecord() {
    setState(() {
      _isLoadingParticipant = true;
      _isLoadingRanking = true;
      _isLoadingRecords = true;
    });

    _fetchMyParticipant();
    _fetchRanking();
    _fetchRecords();
  }

  Future<void> _openBoard() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BattleBoardPage(
          battleId: battle.id,
          title: battle.title,
          unit: _unit ?? '',
          recordType: battle.recordType,
          createdBy: battle.createdBy,
          isForceEnded: battle.isForceEnded,
        ),
      ),
    );

    if (updated == true && mounted) {
      _refreshAfterRecord();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchMyParticipant();
    _fetchRanking();
    _fetchHost();
    _fetchRecords();
  }

  Future<void> _fetchMyParticipant() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        setState(() => _isLoadingParticipant = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('battle_participants')
          .select('target_value,current_value,unit')
          .eq('battle_id', battle.id)
          .eq('user_id', userId)
          .maybeSingle();

      if (!mounted) return;

      if (response == null) {
        setState(() => _isLoadingParticipant = false);
        return;
      }

      setState(() {
        _targetValue = (response['target_value'] as num?)?.toDouble();
        _currentValue = ((response['current_value'] as num?) ?? 0).toDouble();
        _unit = response['unit'] as String? ?? '';
        _isLoadingParticipant = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingParticipant = false);
    }
  }

  Future<void> _fetchHost() async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('name')
          .eq('id', battle.createdBy)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _hostName = profile?['name'] as String?;
        _isLoadingHost = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingHost = false;
      });
    }
  }

  Future<void> _fetchRanking() async {
    try {
      final participants = await Supabase.instance.client
          .from('battle_participants')
          .select('user_id,target_value,current_value,unit')
          .eq('battle_id', battle.id);

      final participantList = participants as List;

      final userIds = participantList
          .map((item) => (item as Map<String, dynamic>)['user_id'] as String)
          .toList();

      final profiles = userIds.isEmpty
          ? <dynamic>[]
          : await Supabase.instance.client
                .from('profiles')
                .select('id,name')
                .inFilter('id', userIds);

      final profileNames = <String, String>{};

      for (final profile in profiles) {
        final map = profile as Map<String, dynamic>;
        profileNames[map['id'] as String] = map['name'] as String;
      }

      final entries = participantList.map((item) {
        final map = item as Map<String, dynamic>;
        final userId = map['user_id'] as String;
        final targetValue = ((map['target_value'] as num?) ?? 0).toDouble();
        final currentValue = ((map['current_value'] as num?) ?? 0).toDouble();
        final unit = map['unit'] as String? ?? '';

        final score = RankingService.calculateScore(
          targetValue: targetValue,
          currentValue: currentValue,
          rule: battle.rule,
        );

        return RankingEntry(
          userId: userId,
          displayName: profileNames[userId] ?? '名無し',
          targetValue: targetValue,
          currentValue: currentValue,
          unit: unit,
          score: score,
          rank: 0,
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _rankingEntries = RankingService.buildRanking(entries: entries);
        _participantCount = entries.length;
        _showAllRanking = false;
        _isLoadingRanking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rankingEntries = [];
        _participantCount = 0;
        _showAllRanking = false;
        _isLoadingRanking = false;
      });
    }
  }

  Future<void> _fetchRecords() async {
    try {
      final response = await Supabase.instance.client
          .from('battle_records')
          .select('user_id,value,memo,created_at')
          .eq('battle_id', battle.id)
          .order('created_at', ascending: false)
          .limit(5);

      final recordRows = response as List;

      final userIds = recordRows
          .map((item) => (item as Map<String, dynamic>)['user_id'] as String)
          .toSet()
          .toList();

      final profiles = userIds.isEmpty
          ? <dynamic>[]
          : await Supabase.instance.client
                .from('profiles')
                .select('id,name')
                .inFilter('id', userIds);

      final profileNames = <String, String>{};

      for (final profile in profiles) {
        final map = profile as Map<String, dynamic>;
        profileNames[map['id'] as String] = map['name'] as String? ?? '名無し';
      }

      final records = recordRows.map((item) {
        final map = item as Map<String, dynamic>;
        final userId = map['user_id'] as String;

        return _RecordItem(
          userName: profileNames[userId] ?? '名無し',
          value: ((map['value'] as num?) ?? 0).toDouble(),
          memo: map['memo'] as String? ?? '',
          createdAt: DateTime.parse(map['created_at'] as String),
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _records = records;
        _isLoadingRecords = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _records = [];
        _isLoadingRecords = false;
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
        return 'ルール: $rule';
    }
  }

  bool _usesTargetRate(String rule) {
    return rule == 'above_my_target' ||
        rule == 'below_my_target' ||
        rule == 'closest_to_my_target';
  }

  String _formatNumber(double value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  String? _achievementRateLabel(RankingEntry entry) {
    if (!_usesTargetRate(battle.rule)) return null;
    if (entry.targetValue == 0) return null;

    double rate;

    switch (battle.rule) {
      case 'above_my_target':
        rate =
            100 +
            ((entry.currentValue - entry.targetValue) /
                    entry.targetValue.abs()) *
                100;
        break;
      case 'below_my_target':
        final remainingRate =
            ((entry.targetValue - entry.currentValue) / entry.targetValue) *
            100;
        rate = remainingRate.clamp(0, 100);

        break;
      case 'closest_to_my_target':
        rate =
            (1 -
                ((entry.currentValue - entry.targetValue).abs() /
                    entry.targetValue.abs())) *
            100;
        break;
      default:
        return null;
    }

    if (rate.isNaN || rate.isInfinite) return null;

    if (battle.rule == 'below_my_target') {
      return '余裕率 ${rate.clamp(0, 999).toStringAsFixed(0)}%';
    }

    if (battle.rule == 'closest_to_my_target') {
      return '近さ ${rate.clamp(0, 999).toStringAsFixed(0)}%';
    }

    return '達成率 ${rate.clamp(0, 999).toStringAsFixed(0)}%';
  }

  String? _targetLevelLabel(RankingEntry entry) {
    if (!_usesTargetRate(battle.rule)) return null;

    final targets =
        _rankingEntries
            .map((e) => e.targetValue.abs())
            .where((e) => e > 0)
            .toList()
          ..sort();

    if (targets.isEmpty) return null;

    final median = targets[targets.length ~/ 2];

    final targetMagnitude = entry.targetValue.abs();

    if (targetMagnitude < median * 0.8) {
      return '🌱 マイペース';
    }

    if (targetMagnitude > median * 1.2) {
      return '🔥 チャレンジ目標';
    }

    return '🎯 標準目標';
  }

  String _periodYearLabel() {
    if (battle.startDate.year == battle.endDate.year) {
      return '${battle.startDate.year}年';
    }

    return '${battle.startDate.year}年〜${battle.endDate.year}年';
  }

  String _periodDateLabel() {
    return '${battle.startDate.month}/${battle.startDate.day}〜${battle.endDate.month}/${battle.endDate.day}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final canInvite = currentUserId == battle.createdBy && !battle.isForceEnded;
    final canRecord = !battle.isForceEnded;
    final myRank = currentUserId == null
        ? null
        : _rankingEntries
              .where((entry) => entry.userId == currentUserId)
              .firstOrNull
              ?.rank;
    final visibleRankingEntries = _showAllRanking
        ? _rankingEntries
        : _rankingEntries.take(10).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8EF),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'バトル詳細',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF2F6B4F),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2F6B4F).withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _periodYearLabel(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFE7F1E9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _periodDateLabel(),
                                style: const TextStyle(
                                  color: Color(0xFFE7F1E9),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            battle.isOpen ? 'オープン' : '招待制',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      battle.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if ((battle.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _DescriptionPreview(text: battle.description ?? ''),
                    ],
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events_outlined,
                            color: Colors.white,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _ruleTitle(battle.rule),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: Colors.white.withOpacity(0.12),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 18,
                      runSpacing: 10,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.group_outlined,
                              color: Color(0xFFE7F1E9),
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isLoadingRanking
                                  ? '参加者読込中'
                                  : '${_participantCount}人参加中',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person_outline,
                              color: Color(0xFFE7F1E9),
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isLoadingHost
                                  ? '主催者読込中'
                                  : '主催者: ${_hostName ?? '不明'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _ProgressSummaryCard(
                recordTypeLabel: battle.recordType,
                periodLabel: battle.periodLabel,
                targetValue: _targetValue,
                currentValue: _currentValue,
                unit: _unit,
                isLoading: _isLoadingParticipant,
                rule: battle.rule,
                rankLabel: _isLoadingRanking
                    ? '読み込み中'
                    : myRank == null
                    ? null
                    : '$myRank位',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _openBoard,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2F6B4F),
                    side: const BorderSide(color: Color(0xFF2F6B4F)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text(
                    '掲示板を見る',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionTitle(title: '現在の順位'),
              const SizedBox(height: 10),
              if (_isLoadingRanking)
                const Center(child: CircularProgressIndicator())
              else if (_rankingEntries.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration(),
                  child: const Text(
                    'まだ参加者がいません。',
                    style: TextStyle(
                      color: Color(0xFF7D6B5D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                ...visibleRankingEntries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RankingCard(
                      rank: entry.rank,
                      name: entry.displayName,
                      value:
                          '${_formatNumber(entry.currentValue)}${entry.unit}',
                      achievementLabel: _achievementRateLabel(entry),
                      targetLabel: _targetLevelLabel(entry),
                    ),
                  ),
                ),
              if (_rankingEntries.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _showAllRanking = !_showAllRanking;
                        });
                      },
                      child: Text(
                        _showAllRanking
                            ? '閉じる'
                            : 'もっと見る（あと${_rankingEntries.length - 10}人）',
                        style: const TextStyle(
                          color: Color(0xFFE9A23B),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const _SectionTitle(title: '最近の記録'),
              const SizedBox(height: 10),
              if (_isLoadingRecords)
                const Center(child: CircularProgressIndicator())
              else if (_records.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration(),
                  child: const Text(
                    'まだ記録がありません。',
                    style: TextStyle(
                      color: Color(0xFF7D6B5D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                ..._records.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecordCard(
                      name: record.userName,
                      date:
                          '${record.createdAt.year}/${record.createdAt.month.toString().padLeft(2, '0')}/${record.createdAt.day.toString().padLeft(2, '0')}',
                      value: '${_formatNumber(record.value)}${_unit ?? ''}',
                      memo: record.memo,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canInvite)
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final invited = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InviteFriendPage(
                            battleId: battle.id,
                            battleTitle: battle.title,
                            inviteCode: battle.inviteCode,
                          ),
                        ),
                      );

                      if (invited == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('招待を送りました')),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2F6B4F),
                      side: const BorderSide(color: Color(0xFF2F6B4F)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text(
                      '友達を招待',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (canInvite) const SizedBox(height: 10),
              SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    if (!canRecord) return;

                    final saved = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecordPage(
                          battleId: battle.id,
                          recordType: _recordType,
                        ),
                      ),
                    );

                    if (saved == true && mounted) {
                      _refreshAfterRecord();
                      await _openBoard();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF5A623),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(
                    canRecord ? '記録する' : '終了しました',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordItem {
  const _RecordItem({
    required this.userName,
    required this.value,
    required this.memo,
    required this.createdAt,
  });

  final String userName;
  final double value;
  final String memo;
  final DateTime createdAt;
}

class _DescriptionPreview extends StatelessWidget {
  const _DescriptionPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Color(0xFFE7F1E9),
      fontSize: 16,
      height: 1.5,
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
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
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
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Container(
                                    width: 42,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD8D1C7),
                                      borderRadius: BorderRadius.circular(999),
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
                    fontWeight: FontWeight.w800,
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

class _ProgressSummaryCard extends StatelessWidget {
  const _ProgressSummaryCard({
    required this.recordTypeLabel,
    required this.periodLabel,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.isLoading,
    required this.rule,
    this.rankLabel,
  });

  final String recordTypeLabel;
  final String periodLabel;
  final double? targetValue;
  final double? currentValue;
  final String? unit;
  final bool isLoading;
  final String rule;
  final String? rankLabel;

  String _formatNumber(double value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }

  String? _achievementMessage() {
    if (currentValue == null) return null;

    if (rule == 'higher_is_better') {
      final current = currentValue!.abs();

      if (current >= 200) return '👑 かなり積み上がっています';
      if (current >= 100) return '🔥 いいペースで積み上がっています';
      if (current > 0) return '🎉 記録が積み上がっています';

      return null;
    }

    if (rule != 'above_my_target') return null;
    if (targetValue == null || targetValue == 0) return null;

    final target = targetValue!.abs();
    final current = currentValue!.abs();
    final rate = current / target * 100;

    if (rate >= 200) return '👑 目標を2倍以上達成しています';
    if (rate >= 120) return '🔥 目標を20%以上上回っています';
    if (rate >= 100) return '🎉 目標達成！';

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final target = targetValue ?? 0;
    final current = currentValue ?? 0;
    final displayUnit = unit ?? '';
    final hasTarget = targetValue != null && targetValue != 0;
    final shouldShowMessageWithoutTarget =
        !hasTarget && rule == 'higher_is_better';
    final remaining = (target - current).abs();
    final isBelowRule = rule == 'below_my_target';
    final isClosestRule = rule == 'closest_to_my_target';
    final isOverTargetForBelow =
        isBelowRule &&
        ((target >= 0 && current > target) || (target < 0 && current < target));
    final belowMessageAmount = (current - target).abs();
    final progress = target == 0
        ? 0.0
        : isClosestRule
        ? (1 - ((current - target).abs() / target.abs())).clamp(0.0, 1.0)
        : isBelowRule
        ? ((target - current) / target).clamp(0.0, 1.0)
        : (current.abs() / target.abs()).clamp(0.0, 1.0);
    final achievementMessage = _achievementMessage();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '自分の状況',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F5EE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  periodLabel,
                  style: TextStyle(
                    color: Color(0xFF2F6B4F),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (hasTarget) ...[
                Expanded(
                  child: _ProgressValueItem(
                    label: '目標',
                    value: isLoading
                        ? '読み込み中'
                        : '${_formatNumber(target)}$displayUnit',
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _ProgressValueItem(
                  label: '現在',
                  value: isLoading
                      ? '読み込み中'
                      : '${_formatNumber(current)}$displayUnit',
                ),
              ),
              if (rankLabel != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _ProgressValueItem(label: '順位', value: rankLabel!),
                ),
              ],
            ],
          ),
          if (hasTarget) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Color(0xFFF4EFE8),
                valueColor: AlwaysStoppedAnimation<Color>(
                  achievementMessage == null
                      ? const Color(0xFF2F6B4F)
                      : achievementMessage.startsWith('👑')
                      ? const Color(0xFFE67E22)
                      : const Color(0xFFE9A23B),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLoading
                  ? '読み込み中です'
                  : achievementMessage ??
                        (isClosestRule
                            ? current > target
                                  ? '目標を${_formatNumber(current - target)}$displayUnit超えています'
                                  : current < target
                                  ? '目標まであと${_formatNumber(target - current)}$displayUnit'
                                  : '目標ぴったりです'
                            : isBelowRule
                            ? isOverTargetForBelow
                                  ? target < 0
                                        ? '目標を${_formatNumber(belowMessageAmount)}$displayUnit下回っています'
                                        : '目標を${_formatNumber(belowMessageAmount)}$displayUnit超えています'
                                  : 'あと${_formatNumber(remaining)}$displayUnitまで余裕があります'
                            : '目標まであと${_formatNumber(remaining)}$displayUnit'),
              style: TextStyle(
                color: achievementMessage == null
                    ? const Color(0xFF7D6B5D)
                    : const Color(0xFFE9A23B),
                fontSize: 13,
                fontWeight: achievementMessage == null
                    ? FontWeight.w700
                    : FontWeight.w800,
              ),
            ),
          ],
          if (shouldShowMessageWithoutTarget && achievementMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              achievementMessage,
              style: const TextStyle(
                color: Color(0xFFE9A23B),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressValueItem extends StatelessWidget {
  const _ProgressValueItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EFE8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7D6B5D),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.rank,
    required this.name,
    required this.value,
    this.achievementLabel,
    this.targetLabel,
  });

  final int rank;
  final String name;
  final String value;
  final String? achievementLabel;
  final String? targetLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1D6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Color(0xFF9A6500),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (achievementLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    achievementLabel!,
                    style: const TextStyle(
                      color: Color(0xFF2F6B4F),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (targetLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    targetLabel!,
                    style: const TextStyle(
                      color: Color(0xFF7D6B5D),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF7D6B5D),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.name,
    required this.date,
    required this.value,
    required this.memo,
  });

  final String name;
  final String date;
  final String value;
  final String memo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: const TextStyle(
                        color: Color(0xFF7D6B5D),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F5EE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF2F6B4F),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (memo.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4EFE8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                memo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF7D6B5D),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
