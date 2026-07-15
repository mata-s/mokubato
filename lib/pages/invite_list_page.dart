import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteListPage extends StatefulWidget {
  const InviteListPage({super.key});

  @override
  State<InviteListPage> createState() => _InviteListPageState();
}

class _InviteListPageState extends State<InviteListPage> {
  List<Map<String, dynamic>> _invites = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _message;
  final TextEditingController _inviteCodeController =
    TextEditingController();


  @override
  void initState() {
    super.initState();
    _fetchInvites();
  }

  Future<void> _fetchInvites() async {
    try {
      final myUserId = Supabase.instance.client.auth.currentUser?.id;

      if (myUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final inviteRows = await Supabase.instance.client
          .from('battle_invites')
          .select('id,battle_id,sender_id,status,created_at')
          .eq('receiver_id', myUserId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final inviteList = inviteRows as List;

      if (inviteList.isEmpty) {
        if (!mounted) return;
        setState(() {
          _invites = [];
          _isLoading = false;
        });
        return;
      }

      final battleIds = inviteList
          .map((item) => (item as Map<String, dynamic>)['battle_id'] as String)
          .toList();

      final senderIds = inviteList
          .map((item) => (item as Map<String, dynamic>)['sender_id'] as String)
          .toList();

      final battles = await Supabase.instance.client
          .from('battles')
          .select('id,title,description,rule,record_type,start_date,end_date,is_open,created_by')
          .inFilter('id', battleIds);

      final battleMap = <String, Map<String, dynamic>>{};
      for (final battle in battles as List) {
        final map = battle as Map<String, dynamic>;
        battleMap[map['id'] as String] = map;
      }

      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id,name,user_code')
          .inFilter('id', senderIds);

      final profileMap = <String, Map<String, dynamic>>{};
      for (final profile in profiles as List) {
        final map = profile as Map<String, dynamic>;
        profileMap[map['id'] as String] = map;
      }

      final participantRows = await Supabase.instance.client
          .from('battle_participants')
          .select('battle_id,unit,target_value')
          .inFilter('battle_id', battleIds);

      final unitMap = <String, String>{};
      final creatorTargetValueMap = <String, double?>{};
      
      for (final participant in participantRows as List) {
        final map = participant as Map<String, dynamic>;
        final battleId = map['battle_id'] as String;
        unitMap.putIfAbsent(
          battleId,
          () => map['unit'] as String? ?? '',
        );
        
        if (creatorTargetValueMap[battleId] == null) {
          creatorTargetValueMap[battleId] =
          (map['target_value'] as num?)?.toDouble();
        }
      }

      final invites = inviteList.map((item) {
        final map = item as Map<String, dynamic>;
        final battleId = map['battle_id'] as String;
        final senderId = map['sender_id'] as String;
        final battle = battleMap[battleId];
        final sender = profileMap[senderId];

        return {
          'id': map['id'],
          'battleId': battleId,
          'senderId': senderId,
          'senderName': sender?['name'] ?? '名無し',
          'battleTitle': battle?['title'] ?? 'バトル',
          'battleDescription': battle?['description'] ?? '',
          'rule': battle?['rule'] ?? '',
          'recordType': battle?['record_type'] ?? '',
          'startDate': battle?['start_date'],
          'endDate': battle?['end_date'],
          'unit': unitMap[battleId] ?? '',
          'creatorTargetValue': creatorTargetValueMap[battleId],
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _invites = invites;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _invites = [];
        _isLoading = false;
      });
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

  Future<void> _joinWithInviteCode() async {
  final inviteCode = _inviteCodeController.text.trim();

  if (inviteCode.isEmpty) {
    setState(() {
      _message = '招待コードを入力してください。';
    });
    return;
  }

  try {
    final battleRows = await Supabase.instance.client
        .from('battles')
        .select('*')
        .eq('invite_code', inviteCode)
        .limit(1);

    if ((battleRows as List).isEmpty) {
      setState(() {
        _message = '招待コードが見つかりません。';
      });
      return;
    }

    final battle = battleRows.first;

    final participantRows = await Supabase.instance.client
        .from('battle_participants')
        .select('unit,target_value')
        .eq('battle_id', battle['id'])
        .limit(1);

    final unit = (participantRows as List).isEmpty
        ? ''
        : participantRows.first['unit'] as String? ?? '';

    final creatorTargetValue = (participantRows as List).isEmpty
      ? null
      : (participantRows.first['target_value'] as num?)?.toDouble();

    final invite = {
      'id': '',
      'battleId': battle['id'],
      'senderName': '招待コード',
      'battleTitle': battle['title'] ?? 'バトル',
      'unit': unit,
      'rule': battle['rule'] ?? '',
      'creatorTargetValue': creatorTargetValue,
    };

    final joined = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => JoinBattlePage(invite: invite),
      ),
    );

    if (joined == true) {
      _fetchInvites();
    }
  } catch (_) {
    setState(() {
      _message = '招待コードの確認に失敗しました。';
    });
  }
}

  Future<void> _rejectInvite(String inviteId) async {
    setState(() {
      _isProcessing = true;
      _message = null;
    });

    try {
      await Supabase.instance.client
          .from('battle_invites')
          .update({'status': 'rejected'})
          .eq('id', inviteId);

      if (!mounted) return;

      setState(() {
        _invites = _invites.where((invite) => invite['id'] != inviteId).toList();
        _message = '招待を辞退しました。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = '辞退に失敗しました。';
      });
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _openJoinPage(Map<String, dynamic> invite) async {
    final joined = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => JoinBattlePage(invite: invite),
      ),
    );

    if (joined == true) {
      _fetchInvites();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8EF),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '招待',
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
                    '招待コードで参加',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inviteCodeController,
                            decoration: InputDecoration(
                              hintText: 'MKB-XXXXXX',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _joinWithInviteCode,
                          child: const Text('確認'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  const Text(
                    '届いた招待',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '参加する場合は、自分の目標値を入力します。単位はバトル内で共通です。',
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
                  if (!_isLoading && _invites.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        '届いている招待はありません。',
                        style: TextStyle(
                          color: Color(0xFF7D6B5D),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    ..._invites.map(
                      (invite) {
                        final startDate = DateTime.parse(
                          invite['startDate'] as String,
                        );
                        final endDate = DateTime.parse(
                          invite['endDate'] as String,
                        );

                        return _InviteCard(
                          title: invite['battleTitle'] as String,
                          senderName: invite['senderName'] as String,
                          unit: invite['unit'] as String,
                          description:
                              invite['battleDescription'] as String? ?? '',
                          periodYearLabel: _periodYearLabel(startDate, endDate),
                          periodDateLabel: _periodDateLabel(startDate, endDate),
                          onJoin: () => _openJoinPage(invite),
                          onReject: () => _rejectInvite(invite['id'] as String),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          if (_isLoading || _isProcessing)
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

class JoinBattlePage extends StatefulWidget {
  const JoinBattlePage({
    super.key,
    required this.invite,
  });

  final Map<String, dynamic> invite;

  @override
  State<JoinBattlePage> createState() => _JoinBattlePageState();
}

class _JoinBattlePageState extends State<JoinBattlePage> {
  final TextEditingController _targetController = TextEditingController();
  final FocusNode _targetFocusNode = FocusNode();
  bool _isJoining = false;
  String? _message;

  @override
  void initState() {
    super.initState();

    if (_requiresNegativeTarget) {
      _targetController.text = '-';
    }
  }

  @override
  void dispose() {
    _targetController.dispose();
    _targetFocusNode.dispose();
    super.dispose();
  }

  String get _rule => widget.invite['rule'] as String? ?? '';

bool get _needsTarget {
  return _rule == 'above_my_target' ||
      _rule == 'below_my_target' ||
      _rule == 'closest_to_my_target';
}

  String get _unit => widget.invite['unit'] as String? ?? '';

  double? get _creatorTargetValue {
  final value = widget.invite['creatorTargetValue'];
  if (value is num) {
    return value.toDouble();
  }
  return null;
}
bool get _requiresNegativeTarget =>
    _needsTarget && (_creatorTargetValue ?? 0) < 0;
bool get _requiresPositiveTarget =>
    _needsTarget && (_creatorTargetValue ?? 0) > 0;

  Future<void> _joinBattle() async {
    final myUserId = Supabase.instance.client.auth.currentUser?.id;
    final targetText = _targetController.text.trim();
    final targetValue = double.tryParse(targetText);
    final inviteId = widget.invite['id'] as String?;
    final battleId = widget.invite['battleId'] as String;

    if (myUserId == null) return;

    if (_needsTarget && targetValue == null) {
      setState(() {
        _message = '目標値を入力してください。';
      });
      return;
    }

    if (_requiresNegativeTarget && targetValue != null && targetValue >= 0) {
      setState(() {
        _message = 'このバトルはマイナス値で入力してください。';
      });
      return;
    }

    if (_requiresPositiveTarget && targetValue != null && targetValue < 0) {
      setState(() {
        _message = 'このバトルは0より大きい数値で入力してください。';
      });
      return;
    }

    setState(() {
      _isJoining = true;
      _message = null;
    });

    try {
      await Supabase.instance.client.from('battle_participants').insert({
        'battle_id': battleId,
        'user_id': myUserId,
        'target_value': _needsTarget ? targetValue : null,
        'unit': _unit,
      });

      if (inviteId != null && inviteId.isNotEmpty) {
        await Supabase.instance.client
            .from('battle_invites')
            .update({'status': 'accepted'})
            .eq('id', inviteId);
      }
      
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = '参加に失敗しました。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.invite['battleTitle'] as String;
    final senderName = widget.invite['senderName'] as String;
    final source = widget.invite['source'] as String?;
    final isOpenJoin = source == 'open';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8EF),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'バトルに参加',
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isOpenJoin
                              ? '$titleに参加しますか？'
                              : '$senderNameさんから招待されています。',
                          style: const TextStyle(
                            color: Color(0xFF7D6B5D),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_needsTarget) ...[
                          const Text(
                            'あなたの目標値',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _targetController,
                                  focusNode: _targetFocusNode,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    signed: true,
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _requiresNegativeTarget ? '例：-5' : '例：5',
                                    filled: true,
                                    fillColor: const Color(0xFFFFF8EF),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _unit,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _requiresNegativeTarget
                                ? 'このバトルはマイナス値で目標を設定してください。'
                                : _requiresPositiveTarget
                                    ? 'このバトルは0より大きい数値で目標を設定してください。'
                                    : '目標値を入力してください。',
                            style: const TextStyle(
                              color: Color(0xFF7D6B5D),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8EF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'このバトルは目標値なしで参加できます。記録した数値でランキングが決まります。',
                              style: TextStyle(
                                color: Color(0xFF7D6B5D),
                                fontSize: 13,
                                height: 1.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (_message != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _message!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _isJoining ? null : _joinBattle,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF5A623),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        '参加する',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isJoining)
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

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.title,
    required this.senderName,
    required this.unit,
    required this.description,
    required this.periodYearLabel,
    required this.periodDateLabel,
    required this.onJoin,
    required this.onReject,

  });

  final String title;
  final String senderName;
  final String unit;
  final String description;
  final String periodYearLabel;
  final String periodDateLabel;
  final VoidCallback onJoin;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _InviteDescriptionPreview(text: description),
          ],
          const SizedBox(height: 8),
          Text(
            unit.isEmpty
                ? '$senderNameさんからの招待'
                : '$senderNameさんからの招待 ・ 単位：$unit',
            style: const TextStyle(
              color: Color(0xFF7D6B5D),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onReject,
                child: const Text('辞退'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onJoin,
                child: const Text('参加する'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteDescriptionPreview extends StatelessWidget {
  const _InviteDescriptionPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Color(0xFF7D6B5D),
      fontSize: 13,
      height: 1.4,
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