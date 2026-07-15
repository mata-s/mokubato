import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'record_page.dart';

enum _RecordAction { edit, delete }

enum _BoardFilter { all, mine, notifications }

class BattleBoardPage extends StatefulWidget {
  const BattleBoardPage({
    super.key,
    required this.battleId,
    required this.title,
    required this.unit,
    required this.recordType,
    required this.createdBy,
    required this.isForceEnded,
  });

  final String battleId;
  final String title;
  final String unit;
  final String recordType;
  final String createdBy;
  final bool isForceEnded;

  @override
  State<BattleBoardPage> createState() => _BattleBoardPageState();
}

class _BattleBoardPageState extends State<BattleBoardPage> {
  final ScrollController _scrollController = ScrollController();
  final List<_BoardRecord> _records = [];
  String? _currentUserId;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasSavedRecord = false;
  bool _showScrollTopButton = false;
  bool _isLoadingEndProposal = true;
  bool _isCreatingEndProposal = false;
  _EndProposal? _endProposal;
  _BoardFilter _filter = _BoardFilter.all;
  int _recordsRequestId = 0;
  int _notificationOffset = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _fetchRecords();
    _fetchEndProposal();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final shouldLoadMore = position.pixels >= position.maxScrollExtent - 300;
    final shouldShowScrollTopButton = position.pixels > 420;

    if (shouldShowScrollTopButton != _showScrollTopButton) {
      setState(() {
        _showScrollTopButton = shouldShowScrollTopButton;
      });
    }

    if (shouldLoadMore && !_isLoadingMore && !_isLoading && _hasMore) {
      _fetchRecords(loadMore: true);
    }
  }

  Future<void> _fetchRecords({
    bool loadMore = false,
    bool showLoading = true,
  }) async {
    final requestId = ++_recordsRequestId;

    if (loadMore) {
      setState(() {
        _isLoadingMore = true;
      });
    } else {
      setState(() {
        if (showLoading) {
          _isLoading = true;
          _records.clear();
        }
        _isLoadingMore = false;
        _hasMore = true;
        _notificationOffset = 0;
      });
    }

    try {
      final currentUserId =
          _currentUserId ?? Supabase.instance.client.auth.currentUser?.id;

      _currentUserId = currentUserId;

      if (_filter == _BoardFilter.notifications) {
        await _fetchNotificationRecords(
          requestId: requestId,
          currentUserId: currentUserId,
          loadMore: loadMore,
        );
        return;
      }

      final from = loadMore ? _records.length : 0;
      final to = from + _pageSize - 1;

      var query = Supabase.instance.client
          .from('battle_records')
          .select(
            'id,user_id,value,memo,image_url,created_at,battle_record_likes(user_id),battle_record_comments(id)',
          )
          .eq('battle_id', widget.battleId);

      if (_filter == _BoardFilter.mine) {
        if (currentUserId == null) {
          if (!mounted || requestId != _recordsRequestId) return;

          setState(() {
            _records.clear();
            _hasMore = false;
            _isLoading = false;
            _isLoadingMore = false;
          });
          return;
        }

        query = query.eq('user_id', currentUserId);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(from, to);

      final recordRows = response as List;
      final newRecords = await _recordsFromRows(recordRows, currentUserId);

      if (!mounted || requestId != _recordsRequestId) return;

      setState(() {
        if (loadMore) {
          final existingIds = _records.map((record) => record.id).toSet();
          _records.addAll(
            newRecords.where((record) => !existingIds.contains(record.id)),
          );
        } else {
          _records
            ..clear()
            ..addAll(newRecords);
        }
        _hasMore = recordRows.length == _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('fetch board records error=$e');

      if (!mounted || requestId != _recordsRequestId) return;

      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _fetchEndProposal() async {
    try {
      final proposalRows = await Supabase.instance.client
          .from('battle_end_proposals')
          .select(
            'id,created_by,reason,status,threshold_ratio,created_at,resolved_at,battle_end_votes(user_id,vote)',
          )
          .eq('battle_id', widget.battleId)
          .order('created_at', ascending: false)
          .limit(1);

      final participantRows = await Supabase.instance.client
          .from('battle_participants')
          .select('user_id')
          .eq('battle_id', widget.battleId);

      final proposals = proposalRows as List;
      final participants = participantRows as List;

      _EndProposal? proposal;

      if (proposals.isNotEmpty) {
        final map = proposals.first as Map<String, dynamic>;
        final votes = (map['battle_end_votes'] as List?) ?? [];
        final currentUserId =
            _currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
        final myVote = currentUserId == null
            ? null
            : votes
                  .where((item) {
                    final voteMap = item as Map<String, dynamic>;
                    return voteMap['user_id'] == currentUserId;
                  })
                  .map(
                    (item) => (item as Map<String, dynamic>)['vote'] as String?,
                  )
                  .firstOrNull;

        proposal = _EndProposal(
          id: map['id'] as String,
          reason: map['reason'] as String?,
          status: map['status'] as String? ?? 'pending',
          thresholdRatio: ((map['threshold_ratio'] as num?) ?? 0.7).toDouble(),
          participantCount: participants.length,
          endCount: votes.where((item) {
            final voteMap = item as Map<String, dynamic>;
            return voteMap['vote'] == 'end';
          }).length,
          continueCount: votes.where((item) {
            final voteMap = item as Map<String, dynamic>;
            return voteMap['vote'] == 'continue';
          }).length,
          myVote: myVote,
        );
      }

      if (!mounted) return;

      setState(() {
        _endProposal = proposal;
        _isLoadingEndProposal = false;
      });
    } catch (e) {
      debugPrint('fetch end proposal error=$e');

      if (!mounted) return;

      setState(() {
        _endProposal = null;
        _isLoadingEndProposal = false;
      });
    }
  }

  Future<void> _createEndProposal() async {
    if (_isCreatingEndProposal) return;

    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('バトル終了を提案しますか？'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '理由を書く（任意）',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD34A3A),
              ),
              child: const Text('提案する'),
            ),
          ],
        );
      },
    );

    if (reason == null) return;

    setState(() {
      _isCreatingEndProposal = true;
    });

    try {
      await Supabase.instance.client.rpc(
        'create_battle_end_proposal',
        params: {'battle_id_arg': widget.battleId, 'reason_arg': reason},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('終了提案を投稿しました')));

      await _fetchEndProposal();
    } catch (e) {
      debugPrint('create end proposal error=$e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('終了提案に失敗しました。')));
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingEndProposal = false;
        });
      }
    }
  }

  Future<void> _voteEndProposal(String vote) async {
    final proposal = _endProposal;
    if (proposal == null || proposal.status != 'pending') return;

    try {
      await Supabase.instance.client.rpc(
        'vote_battle_end_proposal',
        params: {'proposal_id_arg': proposal.id, 'vote_arg': vote},
      );

      await _fetchEndProposal();

      if (!mounted) return;

      final updated = _endProposal;
      if (updated?.status == 'approved') {
        _hasSavedRecord = true;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('投票によりバトルを終了しました')));
      } else if (updated?.status == 'rejected') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('終了提案は否決されました')));
      }
    } catch (e) {
      debugPrint('vote end proposal error=$e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投票に失敗しました。')));
    }
  }

  Future<void> _fetchNotificationRecords({
    required int requestId,
    required String? currentUserId,
    required bool loadMore,
  }) async {
    if (currentUserId == null) {
      if (!mounted || requestId != _recordsRequestId) return;

      setState(() {
        _records.clear();
        _hasMore = false;
        _isLoading = false;
        _isLoadingMore = false;
        _notificationOffset = 0;
      });
      return;
    }

    final from = loadMore ? _notificationOffset : 0;
    final to = from + _pageSize - 1;

    final notificationRows =
        await Supabase.instance.client
                .from('notifications')
                .select('id,record_id,read_at,created_at')
                .eq('user_id', currentUserId)
                .eq('battle_id', widget.battleId)
                .order('created_at', ascending: false)
                .range(from, to)
            as List;

    final notificationIds = <String>[];
    final recordIds = <String>[];
    final seenRecordIds = <String>{};

    for (final item in notificationRows) {
      final map = item as Map<String, dynamic>;
      final notificationId = map['id'] as String?;
      final recordId = map['record_id'] as String?;

      if (notificationId != null && map['read_at'] == null) {
        notificationIds.add(notificationId);
      }

      if (recordId != null && seenRecordIds.add(recordId)) {
        recordIds.add(recordId);
      }
    }

    final newRecords = recordIds.isEmpty
        ? <_BoardRecord>[]
        : await _fetchRecordsByIds(recordIds, currentUserId);

    if (notificationIds.isNotEmpty) {
      await Supabase.instance.client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .inFilter('id', notificationIds);
    }

    if (!mounted || requestId != _recordsRequestId) return;

    setState(() {
      if (loadMore) {
        final existingIds = _records.map((record) => record.id).toSet();
        _records.addAll(
          newRecords.where((record) => !existingIds.contains(record.id)),
        );
      } else {
        _records
          ..clear()
          ..addAll(newRecords);
      }
      _hasMore = notificationRows.length == _pageSize;
      _notificationOffset = loadMore
          ? _notificationOffset + notificationRows.length
          : notificationRows.length;
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  Future<List<_BoardRecord>> _fetchRecordsByIds(
    List<String> recordIds,
    String? currentUserId,
  ) async {
    final response =
        await Supabase.instance.client
                .from('battle_records')
                .select(
                  'id,user_id,value,memo,image_url,created_at,battle_record_likes(user_id),battle_record_comments(id)',
                )
                .eq('battle_id', widget.battleId)
                .inFilter('id', recordIds)
            as List;

    final records = await _recordsFromRows(response, currentUserId);
    final order = <String, int>{};

    for (var i = 0; i < recordIds.length; i += 1) {
      order[recordIds[i]] = i;
    }

    records.sort(
      (a, b) => (order[a.id] ?? recordIds.length).compareTo(
        order[b.id] ?? recordIds.length,
      ),
    );

    return records;
  }

  Future<List<_BoardRecord>> _recordsFromRows(
    List recordRows,
    String? currentUserId,
  ) async {
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

    return recordRows.map((item) {
      final map = item as Map<String, dynamic>;
      final userId = map['user_id'] as String;

      final likes = (map['battle_record_likes'] as List?) ?? [];
      final isLikedByMe =
          currentUserId != null &&
          likes.any((like) {
            final likeMap = like as Map<String, dynamic>;
            return likeMap['user_id'] == currentUserId;
          });
      final comments = (map['battle_record_comments'] as List?) ?? [];

      return _BoardRecord(
        id: map['id'] as String,
        userId: userId,
        isMine: currentUserId != null && userId == currentUserId,
        userName: profileNames[userId] ?? '名無し',
        value: ((map['value'] as num?) ?? 0).toDouble(),
        memo: map['memo'] as String? ?? '',
        imageUrl: map['image_url'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        likeCount: likes.length,
        isLikedByMe: isLikedByMe,
        commentCount: comments.length,
      );
    }).toList();
  }

  String get _emptyMessage {
    switch (_filter) {
      case _BoardFilter.all:
        return 'まだ記録がありません。';
      case _BoardFilter.mine:
        return '自分の記録はまだありません。';
      case _BoardFilter.notifications:
        return '通知のある投稿はありません。';
    }
  }

  Future<void> _refreshRecords() async {
    await Future.wait([_fetchRecords(showLoading: false), _fetchEndProposal()]);
  }

  void _changeFilter(_BoardFilter filter) {
    if (_filter == filter) return;

    setState(() {
      _filter = filter;
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _showScrollTopButton = false;
      _notificationOffset = 0;
      _records.clear();
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    _fetchRecords();
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;

    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _toggleLike(_BoardRecord record) async {
    final userId =
        _currentUserId ?? Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) return;

    final index = _records.indexWhere((item) => item.id == record.id);
    if (index == -1) return;

    final wasLiked = record.isLikedByMe;

    setState(() {
      _records[index] = record.copyWith(
        isLikedByMe: !wasLiked,
        likeCount: wasLiked
            ? (record.likeCount - 1).clamp(0, 999999)
            : record.likeCount + 1,
      );
    });

    try {
      if (wasLiked) {
        await Supabase.instance.client
            .from('battle_record_likes')
            .delete()
            .eq('record_id', record.id)
            .eq('user_id', userId);
      } else {
        await Supabase.instance.client.from('battle_record_likes').insert({
          'record_id': record.id,
          'user_id': userId,
        });
      }
    } catch (e) {
      debugPrint('toggle like error=$e');

      if (!mounted) return;

      setState(() {
        _records[index] = record;
      });
    }
  }

  Future<void> _openComments(_BoardRecord record) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _CommentsSheet(record: record);
      },
    );

    if (added != true || !mounted) return;

    final index = _records.indexWhere((item) => item.id == record.id);
    if (index == -1) return;

    setState(() {
      _records[index] = _records[index].copyWith(
        commentCount: _records[index].commentCount + 1,
      );
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  RecordType get _recordType {
    return widget.recordType == 'current'
        ? RecordType.current
        : RecordType.increment;
  }

  Future<void> _openRecordPage() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RecordPage(battleId: widget.battleId, recordType: _recordType),
      ),
    );

    if (saved != true || !mounted) return;

    setState(() {
      _hasSavedRecord = true;
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _notificationOffset = 0;
      _records.clear();
    });

    _fetchRecords();
  }

  Future<void> _editRecord(_BoardRecord record) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordPage(
          battleId: widget.battleId,
          recordType: _recordType,
          recordId: record.id,
          initialValue: record.value,
          initialMemo: record.memo,
          initialImageUrl: record.imageUrl,
        ),
      ),
    );

    if (saved != true || !mounted) return;

    setState(() {
      _hasSavedRecord = true;
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _notificationOffset = 0;
      _records.clear();
    });

    _fetchRecords();
  }

  Future<void> _deleteRecord(_BoardRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('記録を削除しますか？'),
          content: const Text('削除すると、この記録のいいねとコメントも消えます。'),
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
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final userId =
        _currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ログイン情報を取得できませんでした')));
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'delete_battle_record',
        params: {'record_id_arg': record.id},
      );

      if (!mounted) return;

      setState(() {
        _hasSavedRecord = true;
        _isLoading = true;
        _isLoadingMore = false;
        _hasMore = true;
        _notificationOffset = 0;
        _records.clear();
      });

      _fetchRecords();
    } catch (e) {
      debugPrint('delete board record error=$e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('削除に失敗しました。権限設定を確認してください。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        Navigator.pop(context, _hasSavedRecord);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8EF),
        appBar: AppBar(
          title: Text(widget.title),
          leading: BackButton(
            onPressed: () => Navigator.pop(context, _hasSavedRecord),
          ),
          actions: [
            if (_isHost &&
                !_isLoadingEndProposal &&
                !widget.isForceEnded &&
                _endProposal?.status != 'pending')
              IconButton(
                tooltip: '終了を提案',
                onPressed: _isCreatingEndProposal ? null : _createEndProposal,
                icon: const Icon(Icons.flag_outlined),
              ),
            IconButton(
              tooltip: '記録する',
              onPressed: widget.isForceEnded ? null : _openRecordPage,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refreshRecords,
          color: const Color(0xFF2F6B4F),
          child: _buildRecordList(),
        ),
        floatingActionButton: _showScrollTopButton
            ? FloatingActionButton.small(
                heroTag: 'scrollToTop',
                onPressed: _scrollToTop,
                backgroundColor: const Color(0xFF2F6B4F),
                foregroundColor: Colors.white,
                child: const Icon(Icons.keyboard_arrow_up),
              )
            : null,
      ),
    );
  }

  Widget _buildRecordList() {
    final headerCount = 1 + (_shouldShowEndProposalCard ? 1 : 0);

    if (_isLoading) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_shouldShowEndProposalCard) ...[
            _EndProposalCard(
              proposal: _endProposal,
              isLoading: _isLoadingEndProposal,
              onContinue: () => _voteEndProposal('continue'),
              onEnd: () => _voteEndProposal('end'),
            ),
            const SizedBox(height: 12),
          ],
          _BoardFilterTabs(selected: _filter, onChanged: _changeFilter),
          const SizedBox(height: 12),
          const SizedBox(
            height: 420,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_records.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_shouldShowEndProposalCard) ...[
            _EndProposalCard(
              proposal: _endProposal,
              isLoading: _isLoadingEndProposal,
              onContinue: () => _voteEndProposal('continue'),
              onEnd: () => _voteEndProposal('end'),
            ),
            const SizedBox(height: 12),
          ],
          _BoardFilterTabs(selected: _filter, onChanged: _changeFilter),
          const SizedBox(height: 180),
          Center(
            child: Text(
              _emptyMessage,
              style: const TextStyle(
                color: Color(0xFF7D6B5D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _records.length + headerCount + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (_shouldShowEndProposalCard && index == 0) {
          return _EndProposalCard(
            proposal: _endProposal,
            isLoading: _isLoadingEndProposal,
            onContinue: () => _voteEndProposal('continue'),
            onEnd: () => _voteEndProposal('end'),
          );
        }

        if (index == headerCount - 1) {
          return _BoardFilterTabs(selected: _filter, onChanged: _changeFilter);
        }

        final recordIndex = index - headerCount;

        if (recordIndex >= _records.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final record = _records[recordIndex];

        return _BoardRecordCard(
          record: record,
          date: _formatDate(record.createdAt),
          unit: widget.unit,
          isMine: record.isMine,
          onLike: () => _toggleLike(record),
          onComment: () => _openComments(record),
          onEdit: () => _editRecord(record),
          onDelete: () => _deleteRecord(record),
        );
      },
    );
  }

  bool get _isHost =>
      _currentUserId != null && _currentUserId == widget.createdBy;

  bool get _shouldShowEndProposalCard {
    return _isLoadingEndProposal || _endProposal != null;
  }
}

class _BoardRecord {
  const _BoardRecord({
    required this.id,
    required this.userId,
    required this.isMine,
    required this.userName,
    required this.value,
    required this.memo,
    required this.imageUrl,
    required this.createdAt,
    required this.likeCount,
    required this.isLikedByMe,
    required this.commentCount,
  });

  final String id;
  final String userId;
  final bool isMine;
  final String userName;
  final double value;
  final String memo;
  final String? imageUrl;
  final DateTime createdAt;
  final int likeCount;
  final bool isLikedByMe;
  final int commentCount;

  _BoardRecord copyWith({
    int? likeCount,
    bool? isLikedByMe,
    int? commentCount,
  }) {
    return _BoardRecord(
      id: id,
      userId: userId,
      isMine: isMine,
      userName: userName,
      value: value,
      memo: memo,
      imageUrl: imageUrl,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      commentCount: commentCount ?? this.commentCount,
    );
  }
}

class _EndProposal {
  const _EndProposal({
    required this.id,
    required this.reason,
    required this.status,
    required this.thresholdRatio,
    required this.participantCount,
    required this.endCount,
    required this.continueCount,
    required this.myVote,
  });

  final String id;
  final String? reason;
  final String status;
  final double thresholdRatio;
  final int participantCount;
  final int endCount;
  final int continueCount;
  final String? myVote;

  int get requiredCount {
    if (participantCount <= 0) return 0;
    return (participantCount * thresholdRatio).ceil();
  }

  bool get isPending => status == 'pending';

  String get statusLabel {
    switch (status) {
      case 'approved':
        return '終了が決定しました';
      case 'rejected':
        return '継続が決定しました';
      default:
        return '終了提案中';
    }
  }
}

class _EndProposalCard extends StatelessWidget {
  const _EndProposalCard({
    required this.proposal,
    required this.isLoading,
    required this.onContinue,
    required this.onEnd,
  });

  final _EndProposal? proposal;
  final bool isLoading;
  final VoidCallback onContinue;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final proposal = this.proposal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9D8C6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: isLoading || proposal == null
          ? const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: Color(0xFFD34A3A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        proposal.statusLabel,
                        style: const TextStyle(
                          color: Color(0xFF2B211A),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((proposal.reason ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    proposal.reason!,
                    style: const TextStyle(
                      color: Color(0xFF5B4A3F),
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '終了 ${proposal.endCount}/${proposal.requiredCount} ・ 継続 ${proposal.continueCount}/${proposal.requiredCount}',
                  style: const TextStyle(
                    color: Color(0xFF7D6B5D),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: proposal.requiredCount == 0
                        ? 0
                        : (proposal.endCount / proposal.requiredCount).clamp(
                            0,
                            1,
                          ),
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF4EFE8),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFD34A3A),
                    ),
                  ),
                ),
                if (proposal.isPending) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onContinue,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2F6B4F),
                            side: const BorderSide(color: Color(0xFF2F6B4F)),
                          ),
                          child: Text(
                            proposal.myVote == 'continue' ? '継続に投票中' : '継続',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: onEnd,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD34A3A),
                          ),
                          child: Text(
                            proposal.myVote == 'end' ? '終了に投票中' : '終了',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _BoardFilterTabs extends StatelessWidget {
  const _BoardFilterTabs({required this.selected, required this.onChanged});

  final _BoardFilter selected;
  final ValueChanged<_BoardFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EFE8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _BoardFilterTab(
            label: 'すべて',
            selected: selected == _BoardFilter.all,
            onTap: () => onChanged(_BoardFilter.all),
          ),
          _BoardFilterTab(
            label: '自分',
            selected: selected == _BoardFilter.mine,
            onTap: () => onChanged(_BoardFilter.mine),
          ),
          _BoardFilterTab(
            label: '通知',
            selected: selected == _BoardFilter.notifications,
            onTap: () => onChanged(_BoardFilter.notifications),
          ),
        ],
      ),
    );
  }
}

class _BoardFilterTab extends StatelessWidget {
  const _BoardFilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF2F6B4F)
                  : const Color(0xFF7D6B5D),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardRecordCard extends StatelessWidget {
  const _BoardRecordCard({
    required this.record,
    required this.date,
    required this.unit,
    required this.isMine,
    required this.onLike,
    required this.onComment,
    required this.onEdit,
    required this.onDelete,
  });

  final _BoardRecord record;
  final String date;
  final String unit;
  final bool isMine;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasImage = (record.imageUrl ?? '').isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        record.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF2B211A),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      date,
                      style: const TextStyle(
                        color: Color(0xFF7D6B5D),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (isMine)
                PopupMenuButton<_RecordAction>(
                  tooltip: '記録メニュー',
                  icon: const Icon(Icons.more_horiz, color: Color(0xFF6F5F53)),
                  onSelected: (action) {
                    switch (action) {
                      case _RecordAction.edit:
                        onEdit();
                        break;
                      case _RecordAction.delete:
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _RecordAction.edit,
                      child: Text('編集'),
                    ),
                    PopupMenuItem(
                      value: _RecordAction.delete,
                      child: Text(
                        '削除',
                        style: TextStyle(color: Color(0xFFD34A3A)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record.value.toStringAsFixed(0)}$unit',
                      style: const TextStyle(
                        color: Color(0xFF2F6B4F),
                        fontSize: 29,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (record.memo.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        record.memo,
                        maxLines: hasImage ? 3 : null,
                        overflow: hasImage
                            ? TextOverflow.ellipsis
                            : TextOverflow.visible,
                        style: const TextStyle(
                          color: Color(0xFF2B211A),
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black.withOpacity(0.88),
                      builder: (_) {
                        return Dialog(
                          insetPadding: const EdgeInsets.all(14),
                          backgroundColor: Colors.transparent,
                          child: Stack(
                            children: [
                              Center(
                                child: InteractiveViewer(
                                  minScale: 1,
                                  maxScale: 4,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      record.imageUrl!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton.filled(
                                  onPressed: () => Navigator.pop(context),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black.withOpacity(
                                      0.48,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 132,
                      height: 108,
                      child: Image.network(record.imageUrl!, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onLike,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        record.isLikedByMe
                            ? Icons.thumb_up_alt
                            : Icons.thumb_up_alt_outlined,
                        color: record.isLikedByMe
                            ? const Color(0xFF2F6B4F)
                            : const Color(0xFF6F5F53),
                        size: 22,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${record.likeCount}',
                        style: TextStyle(
                          color: record.isLikedByMe
                              ? const Color(0xFF2F6B4F)
                              : const Color(0xFF6F5F53),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onComment,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        color: Color(0xFF6F5F53),
                        size: 22,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${record.commentCount}',
                        style: const TextStyle(
                          color: Color(0xFF6F5F53),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BoardComment {
  const _BoardComment({
    required this.id,
    required this.userName,
    required this.comment,
    required this.createdAt,
    required this.parentCommentId,
  });

  final String id;
  final String userName;
  final String comment;
  final DateTime createdAt;
  final String? parentCommentId;
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.record});

  final _BoardRecord record;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<_BoardComment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _hasAddedComment = false;
  _BoardComment? _replyTarget;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      final response = await Supabase.instance.client
          .from('battle_record_comments')
          .select('id,user_id,comment,created_at,parent_comment_id')
          .eq('record_id', widget.record.id)
          .order('created_at', ascending: true);

      final rows = response as List;
      final userIds = rows
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

      final comments = rows.map((item) {
        final map = item as Map<String, dynamic>;
        final userId = map['user_id'] as String;

        return _BoardComment(
          id: map['id'] as String,
          userName: profileNames[userId] ?? '名無し',
          comment: map['comment'] as String? ?? '',
          createdAt: DateTime.parse(map['created_at'] as String),
          parentCommentId: map['parent_comment_id'] as String?,
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _comments
          ..clear()
          ..addAll(comments);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('fetch comments error=$e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final inserted = await Supabase.instance.client
          .from('battle_record_comments')
          .insert({
            'record_id': widget.record.id,
            'user_id': userId,
            'comment': text,
            'parent_comment_id': _replyTarget?.id,
          })
          .select('id,user_id,comment,created_at,parent_comment_id')
          .single();

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('name')
          .eq('id', userId)
          .maybeSingle();

      final userName = profile?['name'] as String? ?? '名無し';

      if (!mounted) return;

      setState(() {
        _comments.add(
          _BoardComment(
            id: inserted['id'] as String,
            userName: userName,
            comment: inserted['comment'] as String? ?? text,
            createdAt: DateTime.parse(inserted['created_at'] as String),
            parentCommentId: inserted['parent_comment_id'] as String?,
          ),
        );
        _controller.clear();
        _replyTarget = null;
        _focusNode.unfocus();
        _hasAddedComment = true;
        _isSending = false;
      });
    } catch (e) {
      debugPrint('send comment error=$e');

      if (!mounted) return;

      setState(() {
        _isSending = false;
      });
    }
  }

  String _formatTime(DateTime date) {
    return '${date.month}/${date.day}';
  }

  List<_BoardComment> _rootComments() {
    return _comments
        .where((comment) => comment.parentCommentId == null)
        .toList();
  }

  List<_BoardComment> _repliesFor(String commentId) {
    return _comments.where((comment) {
      if (comment.parentCommentId == null) return false;
      return _rootCommentIdFor(comment) == commentId;
    }).toList();
  }

  String? _rootCommentIdFor(_BoardComment comment) {
    var parentId = comment.parentCommentId;

    while (parentId != null) {
      final parent = _comments.where((item) => item.id == parentId).firstOrNull;
      if (parent == null) return parentId;
      if (parent.parentCommentId == null) return parent.id;
      parentId = parent.parentCommentId;
    }

    return null;
  }

  void _replyToComment(_BoardComment comment) {
    final mention = '@${comment.userName} ';

    setState(() {
      _replyTarget = comment;
    });

    _controller.text = mention;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  void _cancelReply() {
    setState(() {
      _replyTarget = null;
    });

    final text = _controller.text;
    if (text.startsWith('@')) {
      final firstSpaceIndex = text.indexOf(' ');
      if (firstSpaceIndex != -1) {
        _controller.text = text.substring(firstSpaceIndex + 1);
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasAddedComment);
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8EF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8D1C7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'コメント',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              Navigator.pop(context, _hasAddedComment),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _comments.isEmpty
                        ? const Center(
                            child: Text(
                              'まだコメントはありません。',
                              style: TextStyle(
                                color: Color(0xFF7D6B5D),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                            itemCount: _rootComments().length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final comment = _rootComments()[index];
                              final replies = _repliesFor(comment.id);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _CommentRow(
                                    comment: comment,
                                    formattedDate: _formatTime(
                                      comment.createdAt,
                                    ),
                                    onReply: () => _replyToComment(comment),
                                  ),
                                  if (replies.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 22),
                                      child: Column(
                                        children: replies
                                            .map(
                                              (reply) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 10,
                                                ),
                                                child: _CommentRow(
                                                  comment: reply,
                                                  formattedDate: _formatTime(
                                                    reply.createdAt,
                                                  ),
                                                  onReply: () =>
                                                      _replyToComment(reply),
                                                  isReply: true,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: EdgeInsets.only(
                      left: 14,
                      right: 14,
                      top: 10,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 28,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF8EF),
                      border: Border(top: BorderSide(color: Color(0xFFE6DDD2))),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyTarget != null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_replyTarget!.userName}に返信中',
                                  style: const TextStyle(
                                    color: Color(0xFF7D6B5D),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _cancelReply,
                                child: const Text(
                                  'キャンセル',
                                  style: TextStyle(
                                    color: Color(0xFFE9A23B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                minLines: 1,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: 'コメントを追加...',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _isSending ? null : _sendComment,
                              child: Text(
                                _isSending ? '送信中' : '投稿',
                                style: const TextStyle(
                                  color: Color(0xFFE9A23B),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.formattedDate,
    required this.onReply,
    this.isReply = false,
  });

  final _BoardComment comment;
  final String formattedDate;
  final VoidCallback onReply;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onReply,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReply) ...[
            Container(
              width: 14,
              height: 1,
              margin: const EdgeInsets.only(top: 10, right: 8),
              color: const Color(0xFFD8D1C7),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        color: Color(0xFF2B211A),
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Color(0xFF2B211A),
                          fontSize: 14,
                          height: 1.45,
                        ),
                        children: comment.comment.startsWith('@')
                            ? [
                                TextSpan(
                                  text: comment.comment.split(' ').first,
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: comment.comment.substring(
                                    comment.comment.split(' ').first.length,
                                  ),
                                ),
                              ]
                            : [TextSpan(text: comment.comment)],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '返信',
                  style: TextStyle(
                    color: Color(0xFF7D6B5D),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formattedDate,
            style: const TextStyle(
              color: Color(0xFF7D6B5D),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
