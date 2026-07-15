import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlockListPage extends StatefulWidget {
  const BlockListPage({super.key});

  @override
  State<BlockListPage> createState() => _BlockListPageState();
}

class _BlockListPageState extends State<BlockListPage> {
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    try {
      final myUserId = Supabase.instance.client.auth.currentUser?.id;

      if (myUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final blockedRows = await Supabase.instance.client
          .from('blocked_users')
          .select('blocked_user_id')
          .eq('blocker_id', myUserId)
          .order('created_at', ascending: false);

      final blockedUserIds = (blockedRows as List)
          .map((item) => (item as Map<String, dynamic>)['blocked_user_id'] as String)
          .toList();

      if (blockedUserIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _blockedUsers = [];
          _isLoading = false;
        });
        return;
      }
      
      final profiles = await Supabase.instance.client
      .from('profiles')
      .select('id,name,user_code')
      .inFilter('id', blockedUserIds);

      if (!mounted) return;

      setState(() {
        _blockedUsers = (profiles as List)
            .map((item) => item as Map<String, dynamic>)
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _blockedUsers = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser({
    required String userId,
    required String userName,
  }) async {
    final shouldUnblock = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ブロックを解除しますか？'),
          content: Text('$userNameさんのブロックを解除します。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('解除'),
            ),
          ],
        );
      },
    );

    if (shouldUnblock != true) return;

    setState(() {
      _isProcessing = true;
      _message = null;
    });

    try {
      final myUserId = Supabase.instance.client.auth.currentUser?.id;
      if (myUserId == null) return;

      await Supabase.instance.client
          .from('blocked_users')
          .delete()
          .eq('blocker_id', myUserId)
          .eq('blocked_user_id', userId);

      if (!mounted) return;

      setState(() {
        _message = '$userNameさんのブロックを解除しました。';
      });

      _fetchBlockedUsers();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'ブロック解除に失敗しました。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _unblockAndRequest({
    required String userId,
    required String userName,
  }) async {
    final myUserId = Supabase.instance.client.auth.currentUser?.id;
    if (myUserId == null) return;

    setState(() {
      _isProcessing = true;
      _message = null;
    });

    try {
      await Supabase.instance.client
          .from('blocked_users')
          .delete()
          .eq('blocker_id', myUserId)
          .eq('blocked_user_id', userId);

      await Supabase.instance.client.from('friend_requests').insert({
        'sender_id': myUserId,
        'receiver_id': userId,
        'status': 'pending',
      });

      if (!mounted) return;

      setState(() {
        _message = '$userNameさんへフレンド申請を送りました。';
      });

      _fetchBlockedUsers();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = '申請に失敗しました。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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
          'ブロックリスト',
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
                    'ブロック中のユーザー',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ブロックしたユーザーからの申請や招待は制限されます。',
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
                  if (!_isLoading && _blockedUsers.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'ブロック中のユーザーはいません。',
                        style: TextStyle(
                          color: Color(0xFF7D6B5D),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    ..._blockedUsers.map(
                      (user) {
                        final userId = user['id'] as String;
                        final userName = user['name'] as String? ?? '名無し';
                        final userCode = user['user_code'] as String? ?? '';

                        return _BlockedUserCard(
                          name: userName,
                          userCode: userCode,
                          onUnblock: () {
                            _unblockUser(
                              userId: userId,
                              userName: userName,
                            );
                          },
                          onUnblockAndRequest: () {
                            _unblockAndRequest(
                              userId: userId,
                              userName: userName,
                            );
                          },
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

class _BlockedUserCard extends StatelessWidget {
  const _BlockedUserCard({
    required this.name,
    required this.userCode,
    required this.onUnblock,
    required this.onUnblockAndRequest,
  });

  final String name;
  final String userCode;
  final VoidCallback onUnblock;
  final VoidCallback onUnblockAndRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFFFF8EF),
            child: Icon(
              Icons.block,
              color: Color(0xFF7D6B5D),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userCode,
                  style: const TextStyle(
                    color: Color(0xFF7D6B5D),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'unblock') {
                onUnblock();
              }
              if (value == 'request') {
                onUnblockAndRequest();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'unblock',
                child: Text('解除'),
              ),
              PopupMenuItem(
                value: 'request',
                child: Text('解除して申請'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}