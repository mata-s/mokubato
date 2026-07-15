import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteFriendPage extends StatefulWidget {
  const InviteFriendPage({
    super.key,
    required this.battleId,
    required this.battleTitle,
    required this.inviteCode,
  });

  final String battleId;
  final String battleTitle;
  final String inviteCode;

  @override
  State<InviteFriendPage> createState() => _InviteFriendPageState();
}

class _InviteFriendPageState extends State<InviteFriendPage> {
  List<Map<String, dynamic>> _friends = [];
  final Set<String> _selectedUserIds = {};

  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    try {
      final myUserId = Supabase.instance.client.auth.currentUser?.id;

      if (myUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final friendRows = await Supabase.instance.client
          .from('friends')
          .select('friend_user_id')
          .eq('user_id', myUserId);

      final friendIds = (friendRows as List)
          .map((e) => (e as Map<String, dynamic>)['friend_user_id'] as String)
          .toList();

      if (friendIds.isEmpty) {
        setState(() {
          _friends = [];
          _isLoading = false;
        });
        return;
      }

      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id,name,user_code')
          .inFilter('id', friendIds);

      setState(() {
        _friends = (profiles as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendInvites() async {
    final myUserId = Supabase.instance.client.auth.currentUser?.id;

    if (myUserId == null || _selectedUserIds.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final rows = _selectedUserIds
          .map(
            (userId) => {
              'battle_id': widget.battleId,
              'sender_id': myUserId,
              'receiver_id': userId,
              'status': 'pending',
            },
          )
          .toList();

      await Supabase.instance.client
          .from('battle_invites')
          .insert(rows);

      if (!mounted) return;

      Navigator.pop(context, true);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _shareInviteCode() async {
    final inviteCode = widget.inviteCode;

    if (inviteCode.isEmpty) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = renderBox == null
      ? const Rect.fromLTWH(0, 0, 1, 1)
      : renderBox.localToGlobal(Offset.zero) & renderBox.size;

     await Share.share(
      'もくバトで「${widget.battleTitle}」に招待されたよ！\n招待コード：$inviteCode',
       sharePositionOrigin: sharePositionOrigin,
     );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('友達を招待'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
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
                      const Text(
                        '招待コードを共有',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.inviteCode.isEmpty
                            ? '招待コードがありません。'
                            : '招待コード：${widget.inviteCode}',
                        style: const TextStyle(
                          color: Color(0xFF7D6B5D),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: widget.inviteCode.isEmpty
                              ? null
                              : _shareInviteCode,
                          icon: const Icon(Icons.ios_share_outlined),
                          label: const Text('LINEなどで共有'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'フレンド',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      final friend = _friends[index];
                      final userId = friend['id'] as String;
                      final isSelected = _selectedUserIds.contains(userId);

                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(
                          friend['name'] as String? ?? '名無し',
                        ),
                        subtitle: Text(
                          friend['user_code'] as String? ?? '',
                        ),
                        onChanged: (_) {
                          setState(() {
                            if (isSelected) {
                              _selectedUserIds.remove(userId);
                            } else {
                              _selectedUserIds.add(userId);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSending ? null : _sendInvites,
                      child: _isSending
                          ? const CircularProgressIndicator()
                          : const Text('招待を送る'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
