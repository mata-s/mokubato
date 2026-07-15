import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/keyboard_done_bar.dart';

class FriendPage extends StatefulWidget {
  const FriendPage({super.key});

  @override
  State<FriendPage> createState() => _FriendPageState();
}

class _FriendPageState extends State<FriendPage> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();

  bool _isSending = false;
  String? _message;
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _receivedRequests = [];
  List<Map<String, dynamic>> _friends = [];
  bool _isLoadingLists = true;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _fetchFriendData();
  }

  Future<void> _fetchFriendData() async {
    try {
      final myUserId = Supabase.instance.client.auth.currentUser?.id;

      if (myUserId == null) {
        setState(() => _isLoadingLists = false);
        return;
      }

      final pendingRows = await Supabase.instance.client
          .from('friend_requests')
          .select('id,receiver_id,status,created_at')
          .eq('sender_id', myUserId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final receivedRows = await Supabase.instance.client
          .from('friend_requests')
          .select('id,sender_id,status,created_at')
          .eq('receiver_id', myUserId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final friendRows = await Supabase.instance.client
          .from('friends')
          .select('id,friend_user_id,created_at')
          .eq('user_id', myUserId)
          .order('created_at', ascending: false);

      final pendingReceiverIds = (pendingRows as List)
          .map((item) => (item as Map<String, dynamic>)['receiver_id'] as String)
          .toList();

      final receivedSenderIds = (receivedRows as List)
          .map((item) => (item as Map<String, dynamic>)['sender_id'] as String)
          .toList();

      final friendUserIds = (friendRows as List)
          .map((item) => (item as Map<String, dynamic>)['friend_user_id'] as String)
          .toList();

      final profileIds = {
        ...pendingReceiverIds,
        ...receivedSenderIds,
        ...friendUserIds,
      }.toList();

      final profiles = profileIds.isEmpty
          ? <dynamic>[]
          : await Supabase.instance.client
              .from('profiles')
              .select('id,name,user_code')
              .inFilter('id', profileIds);

      final profileMap = <String, Map<String, dynamic>>{};
      for (final profile in profiles) {
        final map = profile as Map<String, dynamic>;
        profileMap[map['id'] as String] = map;
      }

      final pendingRequests = pendingRows.map((item) {
        final map = item;
        final receiverId = map['receiver_id'] as String;
        final profile = profileMap[receiverId];

        return {
          'id': map['id'],
          'userId': receiverId,
          'name': profile?['name'] ?? '名無し',
          'userCode': profile?['user_code'] ?? '',
        };
      }).toList();

      final receivedRequests = receivedRows.map((item) {
        final map = item;
        final senderId = map['sender_id'] as String;
        final profile = profileMap[senderId];

        return {
          'id': map['id'],
          'userId': senderId,
          'name': profile?['name'] ?? '名無し',
          'userCode': profile?['user_code'] ?? '',
        };
      }).toList();

      final friends = friendRows.map((item) {
        final map = item;
        final friendUserId = map['friend_user_id'] as String;
        final profile = profileMap[friendUserId];

        return {
          'id': map['id'],
          'userId': friendUserId,
          'name': profile?['name'] ?? '名無し',
          'userCode': profile?['user_code'] ?? '',
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _pendingRequests = pendingRequests;
        _receivedRequests = receivedRequests;
        _friends = friends;
        _isLoadingLists = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pendingRequests = [];
        _receivedRequests = [];
        _friends = [];
        _isLoadingLists = false;
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendFriendRequest() async {
    final code = _codeController.text.trim().toUpperCase();
    final myUserId = Supabase.instance.client.auth.currentUser?.id;

    if (code.isEmpty) {
      setState(() {
        _message = '友達コードを入力してください。';
      });
      return;
    }

    if (myUserId == null) {
      setState(() {
        _message = 'ログイン情報を確認できませんでした。';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _message = null;
    });

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id,name,user_code')
          .eq('user_code', code)
          .maybeSingle();

      if (profile == null) {
        setState(() {
          _message = 'このコードのユーザーが見つかりませんでした。';
        });
        return;
      }

      final receiverId = profile['id'] as String;
      final receiverName = profile['name'] as String? ?? '相手';

      if (receiverId == myUserId) {
        setState(() {
          _message = '自分自身には申請できません。';
        });
        return;
      }

      final blockedRows = await Supabase.instance.client
          .from('blocked_users')
          .select('id')
          .or(
            'and(blocker_id.eq.$myUserId,blocked_user_id.eq.$receiverId),and(blocker_id.eq.$receiverId,blocked_user_id.eq.$myUserId)',
          );

      if ((blockedRows as List).isNotEmpty) {
        setState(() {
          _message = 'このユーザーにはフレンド申請できません。';
        });
        return;
      }

      final existingFriendRows = await Supabase.instance.client
          .from('friends')
          .select('id')
          .or(
            'and(user_id.eq.$myUserId,friend_user_id.eq.$receiverId),and(user_id.eq.$receiverId,friend_user_id.eq.$myUserId)',
          );

      if ((existingFriendRows as List).isNotEmpty) {
        setState(() {
          _message = '$receiverNameさんはすでにフレンドです。';
        });
        return;
      }

      final existingRequestRows = await Supabase.instance.client
          .from('friend_requests')
          .select('id,status')
          .or(
            'and(sender_id.eq.$myUserId,receiver_id.eq.$receiverId,status.eq.pending),and(sender_id.eq.$receiverId,receiver_id.eq.$myUserId,status.eq.pending)',
          );

      if ((existingRequestRows as List).isNotEmpty) {
        setState(() {
          _message = 'すでにフレンド申請中です。';
        });
        return;
      }

      await Supabase.instance.client.from('friend_requests').insert({
        'sender_id': myUserId,
        'receiver_id': receiverId,
        'status': 'pending',
      });

      if (!mounted) return;

      _codeController.clear();
      FocusScope.of(context).unfocus();

      setState(() {
        _message = '$receiverNameさんにフレンド申請を送りました。';
      });
      _fetchFriendData();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'フレンド申請に失敗しました。もう一度お試しください。';
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _cancelFriendRequest(String requestId) async {
    final previousRequests = List<Map<String, dynamic>>.from(_pendingRequests);

    setState(() {
      _isProcessingAction = true;
      _pendingRequests = _pendingRequests
          .where((request) => request['id'] != requestId)
          .toList();
      _message = null;
    });
    try {
      final myUserId = Supabase.instance.client.auth.currentUser?.id;
      if (myUserId == null) return;

      await Supabase.instance.client
          .from('friend_requests')
          .delete()
          .eq('id', requestId)
          .eq('sender_id', myUserId)
          .eq('status', 'pending');

      if (!mounted) return;

      setState(() {
        _message = 'フレンド申請を取り下げました。';
      });

      _fetchFriendData();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pendingRequests = previousRequests;
        _message = '申請の取り下げに失敗しました。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _acceptFriendRequest({
    required String requestId,
    required String senderId,
    required String senderName,
    required String senderUserCode,
  }) async {
    setState(() {
      _isProcessingAction = true;
    });
    try {
      final myUserId = Supabase.instance.client.auth.currentUser?.id;
      if (myUserId == null) return;

      await Supabase.instance.client.rpc(
        'accept_friend_request',
        params: {
          'request_id': requestId,
        },
      );

      if (!mounted) return;

      setState(() {
        _receivedRequests = _receivedRequests
            .where((request) => request['id'] != requestId)
            .toList();

        final alreadyExists = _friends.any(
          (friend) => friend['userId'] == senderId,
        );

        if (!alreadyExists) {
          _friends = [
            {
              'id': senderId,
              'userId': senderId,
              'name': senderName,
              'userCode': senderUserCode,
            },
            ..._friends,
          ];
        }

        _message = 'フレンド申請を承認しました。';
      });

      await _fetchFriendData();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = '承認に失敗しました。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    setState(() {
      _isProcessingAction = true;
    });
    try {
      await Supabase.instance.client
          .from('friend_requests')
          .update({'status': 'rejected'})
          .eq('id', requestId);

      if (!mounted) return;

      setState(() {
        _message = 'フレンド申請を却下しました。';
      });

      _fetchFriendData();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = '却下に失敗しました。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _deleteFriend({
    required String friendUserId,
    required String friendName,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('フレンドを削除しますか？'),
          content: Text('$friendNameさんをフレンド一覧から削除します。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;
    
    setState(() {
      _isProcessingAction = true;
    });

    try {
      final myUserId = Supabase.instance.client.auth.currentUser?.id;
      if (myUserId == null) return;

      await Supabase.instance.client
          .from('friends')
          .delete()
          .eq('user_id', myUserId)
          .eq('friend_user_id', friendUserId);

      await Supabase.instance.client
          .from('friends')
          .delete()
          .eq('user_id', friendUserId)
          .eq('friend_user_id', myUserId);

      if (!mounted) return;

      setState(() {
        _message = '$friendNameさんをフレンドから削除しました。';
      });

      _fetchFriendData();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'フレンド削除に失敗しました。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _blockUser({
    required String userId,
    required String userName,
  }) async {
    final shouldBlock = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ブロックしますか？'),
        content: Text('$userNameさんをブロックします。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ブロック'),
          ),
        ],
      ),
    );

    if (shouldBlock != true) return;

    try {
      final myUserId = Supabase.instance.client.auth.currentUser?.id;
      if (myUserId == null) return;

      setState(() {
        _isProcessingAction = true;
      });

      await Supabase.instance.client.from('blocked_users').upsert({
        'blocker_id': myUserId,
        'blocked_user_id': userId,
      });

      await Supabase.instance.client
          .from('friends')
          .delete()
          .eq('user_id', myUserId)
          .eq('friend_user_id', userId);

      await Supabase.instance.client
          .from('friends')
          .delete()
          .eq('user_id', userId)
          .eq('friend_user_id', myUserId);

      if (!mounted) return;

      setState(() {
        _message = '$userNameさんをブロックしました。';
      });

      _fetchFriendData();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _reportUser({
    required String userId,
    required String userName,
  }) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('通報'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '通報理由を入力',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('送信'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    try {
      final myUserId = Supabase.instance.client.auth.currentUser?.id;
      if (myUserId == null) return;

      setState(() {
        _isProcessingAction = true;
      });

      await Supabase.instance.client.from('user_reports').insert({
        'reporter_id': myUserId,
        'reported_user_id': userId,
        'reason': reason,
      });

      if (!mounted) return;

      setState(() {
        _message = '$userNameさんを通報しました。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
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
          'フレンド',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      bottomSheet: KeyboardDoneBar(
        focusNodes: [
          _codeFocusNode,
        ],
      ),
      body: Stack(
        children: [
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '友達コードで申請',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '相手のプロフィールに表示されているコードを入力してください。',
                      style: TextStyle(
                        color: Color(0xFF7D6B5D),
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeController,
                      focusNode: _codeFocusNode,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: '例：MBT-7F3A9K',
                        hintStyle: const TextStyle(
                          color: Color(0xFFB8AEA5),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFFF8EF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _message!,
                        style: const TextStyle(
                          color: Color(0xFF7D6B5D),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isSending ? null : _sendFriendRequest,
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.person_add_alt_1_outlined),
                        label: Text(_isSending ? '送信中' : '申請する'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF5A623),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingLists || _isProcessingAction) ...[
                const SizedBox(height: 24),
                const Center(
                  child: CircularProgressIndicator(),
                ),
              ],
              if (!_isLoadingLists && _receivedRequests.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionTitle(title: '届いた申請'),
                const SizedBox(height: 10),

                  ..._receivedRequests.map(
                    (request) => _FriendListCard(
                      name: request['name'] as String,
                      userCode: request['userCode'] as String,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              _rejectFriendRequest(request['id'] as String);
                            },
                            child: const Text('却下'),
                          ),
                          FilledButton(
                            onPressed: () {
                              _acceptFriendRequest(
                                requestId: request['id'] as String,
                                senderId: request['userId'] as String,
                                senderName: request['name'] as String,
                                senderUserCode: request['userCode'] as String,
                              );
                            },
                            child: const Text('承認'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (!_isLoadingLists && _pendingRequests.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionTitle(title: '申請中'),
                const SizedBox(height: 10),
                ..._pendingRequests.map(
                  (request) => _FriendListCard(
                    name: request['name'] as String,
                    userCode: request['userCode'] as String,
                    trailing: TextButton(
                      onPressed: () {
                        _cancelFriendRequest(request['id'] as String);
                      },
                      child: const Text('取り下げ'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const _SectionTitle(title: 'フレンド一覧'),
              const SizedBox(height: 10),
              if (_isLoadingLists)
                const SizedBox.shrink()
              else if (_friends.isEmpty)
                const _EmptyListText(text: 'フレンドはまだいません。')
              else
                ..._friends.map(
                  (friend) => _FriendListCard(
                    name: friend['name'] as String,
                    userCode: friend['userCode'] as String,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteFriend(
                            friendUserId: friend['userId'] as String,
                            friendName: friend['name'] as String,
                          );
                        }
                        if (value == 'block') {
                          _blockUser(
                            userId: friend['userId'] as String,
                            userName: friend['name'] as String,
                          );
                        }

                        if (value == 'report') {
                          _reportUser(
                            userId: friend['userId'] as String,
                            userName: friend['name'] as String,
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('削除'),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: Text('ブロック'),
                        ),
                        PopupMenuItem(
                          value: 'report',
                          child: Text('通報'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      // Loading overlay removed
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
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _EmptyListText extends StatelessWidget {
  const _EmptyListText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7D6B5D),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FriendListCard extends StatelessWidget {
  const _FriendListCard({
    required this.name,
    required this.userCode,
    this.trailing,
  });

  final String name;
  final String userCode;
  final Widget? trailing;

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
              Icons.person_outline,
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
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}