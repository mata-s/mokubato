import 'package:flutter/material.dart';
import 'package:mokubato/pages/archive_battle_page.dart';
import 'package:mokubato/pages/friend_page.dart';
import 'package:mokubato/pages/invite_list_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/battle.dart';
import '../models/goal_note.dart';
import '../services/profile_service.dart';
import 'goal_note_page.dart';
import 'goal_note_detail_page.dart';
import 'create_battle_page.dart';
import 'battle_detail_page.dart';
import 'open_battle_list_page.dart';
import 'block_list_page.dart';
import 'profile_page.dart';
import 'welcome_page.dart';
import '../widgets/battle_card.dart';
import '../widgets/goal_note_card.dart';
import 'goal_note_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<GoalNote> _goals = [];
  bool _isLoadingGoals = true;
  List<Battle> _battles = [];
  bool _isLoadingBattles = true;
  Map<String, bool> _hasMyRecordToday = {};
  Map<String, bool> _hasOtherPostToday = {};
  bool _hasLoadedBattleNotices = false;
  int _battleNoticeRequestId = 0;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<Battle> get _upcomingBattles {
    final today = _today;
    return _battles.where((battle) {
      if (battle.isForceEnded) return false;

      return _dateOnly(battle.startDate).isAfter(today);
    }).toList();
  }

  List<Battle> get _activeBattles {
    final today = _today;
    return _battles.where((battle) {
      if (battle.isForceEnded) return false;

      final startDate = _dateOnly(battle.startDate);
      final endDate = _dateOnly(battle.endDate);

      return !startDate.isAfter(today) && !endDate.isBefore(today);
    }).toList();
  }

  List<Battle> get _resultBattles {
    final today = _today;
    return _battles.where((battle) {
      if (battle.isForceEnded) {
        final endedDate = _dateOnly(battle.forceEndedAt!);
        final resultEndDate = endedDate.add(const Duration(days: 7));

        return !resultEndDate.isBefore(today);
      }

      final endDate = _dateOnly(battle.endDate);
      final resultEndDate = endDate.add(const Duration(days: 7));

      return endDate.isBefore(today) && !resultEndDate.isBefore(today);
    }).toList();
  }

  List<Battle> get _unrecordedActiveBattles {
    if (!_hasLoadedBattleNotices) return [];

    return _activeBattles
        .where((battle) => _hasMyRecordToday[battle.id] != true)
        .toList();
  }

  List<Battle> get _activeBattlesWithNewPosts {
    if (!_hasLoadedBattleNotices) return [];

    return _activeBattles
        .where((battle) => _hasOtherPostToday[battle.id] == true)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    ProfileService.ensureUserCode();
    _fetchGoalNotes();
    _fetchBattles();
  }

  Future<void> _fetchGoalNotes() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        setState(() {
          _goals = [];
          _isLoadingGoals = false;
        });
        return;
      }

      final response = await Supabase.instance.client
          .from('goal_notes')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _goals = (response as List)
            .map((item) => GoalNote.fromMap(item as Map<String, dynamic>))
            .toList();
        _isLoadingGoals = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _goals = [];
        _isLoadingGoals = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('アカウントを削除しますか？'),
          content: const Text('削除するとプロフィール、記録、コメントなどのデータを元に戻せません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD34A3A),
              ),
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.rpc('delete_own_account');
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (_) => false,
      );
    } catch (e) {
      debugPrint('delete account error=$e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('アカウント削除に失敗しました。')));
    }
  }

  Future<void> _fetchBattles() async {
    _battleNoticeRequestId++;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        setState(() {
          _battles = [];
          _hasMyRecordToday = {};
          _hasOtherPostToday = {};
          _hasLoadedBattleNotices = true;
          _isLoadingBattles = false;
        });
        return;
      }

      final participantRows = await Supabase.instance.client
          .from('battle_participants')
          .select('battle_id')
          .eq('user_id', userId);

      final battleIds = (participantRows as List)
          .map((item) => (item as Map<String, dynamic>)['battle_id'] as String)
          .toList();

      if (battleIds.isEmpty) {
        setState(() {
          _battles = [];
          _hasMyRecordToday = {};
          _hasOtherPostToday = {};
          _hasLoadedBattleNotices = true;
          _isLoadingBattles = false;
        });
        return;
      }

      final response = await Supabase.instance.client
          .from('battles')
          .select()
          .inFilter('id', battleIds)
          .order('created_at', ascending: false);

      final allParticipantRows = await Supabase.instance.client
          .from('battle_participants')
          .select('battle_id')
          .inFilter('battle_id', battleIds);

      final participantCounts = <String, int>{};

      for (final item in allParticipantRows as List) {
        final map = item as Map<String, dynamic>;
        final battleId = map['battle_id'] as String;
        participantCounts[battleId] = (participantCounts[battleId] ?? 0) + 1;
      }

      debugPrint('participantCounts=$participantCounts');

      final battles = (response as List).map((item) {
        final map = item as Map<String, dynamic>;
        final battleId = map['id'] as String;
        debugPrint('battle=$battleId count=${participantCounts[battleId]}');

        return Battle.fromMap({
          ...map,
          'participants': participantCounts[battleId] ?? 0,
        });
      }).toList();

      final today = _today;
      final activeBattleIds = battles
          .where((battle) {
            if (battle.isForceEnded) return false;

            final startDate = _dateOnly(battle.startDate);
            final endDate = _dateOnly(battle.endDate);

            return !startDate.isAfter(today) && !endDate.isBefore(today);
          })
          .map((battle) => battle.id)
          .toList();

      if (!mounted) return;

      setState(() {
        _battles = battles;
        _hasMyRecordToday = {};
        _hasOtherPostToday = {};
        _hasLoadedBattleNotices = false;
        _isLoadingBattles = false;
      });

      _fetchBattleNotices(battleIds: activeBattleIds, userId: userId);
    } catch (e) {
      debugPrint('fetchBattles error=$e');

      if (!mounted) return;

      setState(() {
        _battles = [];
        _hasMyRecordToday = {};
        _hasOtherPostToday = {};
        _hasLoadedBattleNotices = true;
        _isLoadingBattles = false;
      });
    }
  }

  Future<void> _fetchBattleNotices({
    required List<String> battleIds,
    required String userId,
  }) async {
    final requestId = ++_battleNoticeRequestId;

    final notices = await _fetchBattleNoticeState(
      battleIds: battleIds,
      userId: userId,
    );

    if (!mounted || requestId != _battleNoticeRequestId) return;

    setState(() {
      _hasMyRecordToday = notices.hasMyRecordToday;
      _hasOtherPostToday = notices.hasOtherPostToday;
      _hasLoadedBattleNotices = true;
    });
  }

  Future<_BattleNoticeState> _fetchBattleNoticeState({
    required List<String> battleIds,
    required String userId,
  }) async {
    if (battleIds.isEmpty) {
      return const _BattleNoticeState(
        hasMyRecordToday: {},
        hasOtherPostToday: {},
      );
    }

    final todayStart = _today;
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    try {
      final rows = await Supabase.instance.client
          .from('battle_records')
          .select('battle_id,user_id')
          .inFilter('battle_id', battleIds)
          .gte('created_at', todayStart.toUtc().toIso8601String())
          .lt('created_at', tomorrowStart.toUtc().toIso8601String());

      final hasMyRecordToday = {
        for (final battleId in battleIds) battleId: false,
      };
      final hasOtherPostToday = {
        for (final battleId in battleIds) battleId: false,
      };

      for (final item in rows as List) {
        final map = item as Map<String, dynamic>;
        final battleId = map['battle_id'] as String;
        final recordUserId = map['user_id'] as String;

        if (recordUserId == userId) {
          hasMyRecordToday[battleId] = true;
        } else {
          hasOtherPostToday[battleId] = true;
        }
      }

      return _BattleNoticeState(
        hasMyRecordToday: hasMyRecordToday,
        hasOtherPostToday: hasOtherPostToday,
      );
    } catch (e) {
      debugPrint('fetchBattleNoticeState error=$e');

      return _BattleNoticeState(
        hasMyRecordToday: {for (final battleId in battleIds) battleId: true},
        hasOtherPostToday: {for (final battleId in battleIds) battleId: false},
      );
    }
  }

  Future<void> _openBattleDetail(Battle battle) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BattleDetailPage(battle: battle)),
    );

    if (!mounted) return;

    setState(() {
      _isLoadingBattles = true;
    });

    _fetchBattles();
  }

  Widget _buildBattleSection({
    required String title,
    required List<Battle> battles,
  }) {
    if (battles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ...List.generate(
          battles.length,
          (index) => Padding(
            padding: EdgeInsets.only(
              bottom: index == battles.length - 1 ? 0 : 14,
            ),
            child: GestureDetector(
              onTap: () {
                _openBattleDetail(battles[index]);
              },
              child: BattleCard(data: battles[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeSection() {
    final unrecordedBattles = _unrecordedActiveBattles;
    final battlesWithNewPosts = _activeBattlesWithNewPosts;

    if (unrecordedBattles.isEmpty && battlesWithNewPosts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1D6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF4D39B)),
      ),
      child: Column(
        children: [
          if (unrecordedBattles.isNotEmpty)
            _NoticeRow(
              icon: Icons.edit_note_outlined,
              title: '今日の記録をしましょう',
              message: _noticeBattleMessage(unrecordedBattles),
              onTap: () => _openBattleDetail(unrecordedBattles.first),
            ),
          if (unrecordedBattles.isNotEmpty &&
              battlesWithNewPosts.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE9C98F)),
            const SizedBox(height: 10),
          ],
          if (battlesWithNewPosts.isNotEmpty)
            _NoticeRow(
              icon: Icons.forum_outlined,
              title: '新しい投稿があります',
              message: _noticeBattleMessage(battlesWithNewPosts),
              onTap: () => _openBattleDetail(battlesWithNewPosts.first),
            ),
        ],
      ),
    );
  }

  String _noticeBattleMessage(List<Battle> battles) {
    final firstTitle = battles.first.title;
    final remainingCount = battles.length - 1;

    if (remainingCount == 0) return firstTitle;

    return '$firstTitle ほか$remainingCount件';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: Color(0xFFFFF8EF)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'もくバト',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'プロフィール・フレンド',
                      style: TextStyle(color: Color(0xFF7D6B5D)),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('プロフィール'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.people_outline),
                title: Text('フレンド'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FriendPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('ブロックリスト'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BlockListPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.mail_outline),
                title: Text('招待'),
                onTap: () async {
                  Navigator.pop(context);

                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InviteListPage()),
                  );

                  if (!mounted) return;

                  setState(() {
                    _isLoadingBattles = true;
                  });

                  _fetchBattles();
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('アーカイブ'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ArchiveBattlePage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.settings_outlined),
                title: Text('設定'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('ログアウト'),
                onTap: () async {
                  Navigator.pop(context);
                  await Supabase.instance.client.auth.signOut();

                  if (!context.mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomePage()),
                    (_) => false,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_outlined,
                  color: Color(0xFFD34A3A),
                ),
                title: const Text(
                  'アカウント削除',
                  style: TextStyle(color: Color(0xFFD34A3A)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteAccount();
                },
              ),
            ],
          ),
        ),
      ),
      body: (_isLoadingGoals || _isLoadingBattles)
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Builder(
                          builder: (context) => GestureDetector(
                            onTap: () {
                              Scaffold.of(context).openDrawer();
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.menu),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'もくバト',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '今月の目標を、みんなで楽しく。',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF7D6B5D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildNoticeSection(),
                    if (_unrecordedActiveBattles.isNotEmpty ||
                        _activeBattlesWithNewPosts.isNotEmpty)
                      const SizedBox(height: 14),
                    GoalNoteCard(
                      goals: _goals,
                      onAddPressed: () async {
                        final saved = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GoalNotePage(),
                          ),
                        );

                        if (saved == true) {
                          _fetchGoalNotes();
                        }
                      },
                      onGoalTap: (goal) async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GoalNoteDetailPage(goal: goal),
                          ),
                        );

                        if (updated == true) {
                          _fetchGoalNotes();
                        }
                      },
                      onViewAllPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GoalNoteListPage(
                              goals: _goals,
                              onGoalTap: (goal) async {
                                final updated = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        GoalNoteDetailPage(goal: goal),
                                  ),
                                );

                                if (updated == true) {
                                  _fetchGoalNotes();
                                }
                              },
                              onAddPressed: () async {
                                final saved = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const GoalNotePage(),
                                  ),
                                );

                                if (saved == true) {
                                  _fetchGoalNotes();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '参加中のバトル',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const OpenBattleListPage(),
                              ),
                            );

                            if (!mounted) return;

                            setState(() {
                              _isLoadingBattles = true;
                            });

                            _fetchBattles();
                          },
                          child: const Text('公開バトルを探す'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_battles.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '参加中のバトルはまだありません。',
                          style: TextStyle(
                            color: Color(0xFF7D6B5D),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else ...[
                      _buildBattleSection(
                        title: '開催中',
                        battles: _activeBattles,
                      ),
                      if (_upcomingBattles.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _buildBattleSection(
                          title: 'まもなく開始',
                          battles: _upcomingBattles,
                        ),
                      ],
                      if (_resultBattles.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _buildBattleSection(
                          title: '結果発表中',
                          battles: _resultBattles,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateBattlePage()),
          );

          if (!mounted) return;

          setState(() {
            _isLoadingBattles = true;
          });

          await _fetchBattles();
        },
        backgroundColor: const Color(0xFFF5A623),
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add),
        label: const Text('作成'),
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFFD78300)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7D6B5D),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFFB98942)),
          ],
        ),
      ),
    );
  }
}

class _BattleNoticeState {
  const _BattleNoticeState({
    required this.hasMyRecordToday,
    required this.hasOtherPostToday,
  });

  final Map<String, bool> hasMyRecordToday;
  final Map<String, bool> hasOtherPostToday;
}
