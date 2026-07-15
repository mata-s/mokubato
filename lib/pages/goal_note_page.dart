import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/keyboard_done_bar.dart';
import '../models/goal_note.dart';

class GoalNotePage extends StatefulWidget {
  const GoalNotePage({
    super.key,
    this.goal,
  });

  final GoalNote? goal;

  @override
  State<GoalNotePage> createState() => _GoalNotePageState();
}

class _GoalNotePageState extends State<GoalNotePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _memoFocusNode = FocusNode();
  bool _isLoading = false;

  bool get _isEditMode => widget.goal != null;

  Future<void> _saveGoalNote() async {
    final title = _titleController.text.trim();
    final memo = _memoController.text.trim();
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目標を入力してください。')),
      );
      return;
    }

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログイン情報を確認できませんでした。')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isEditMode) {
        await Supabase.instance.client.from('goal_notes').update({
          'title': title,
          'memo': memo.isEmpty ? null : memo,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.goal!.id).eq('user_id', userId);
      } else {
        await Supabase.instance.client.from('goal_notes').insert({
          'user_id': userId,
          'title': title,
          'memo': memo.isEmpty ? null : memo,
        });
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存に失敗しました。もう一度お試しください。')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    if (goal != null) {
      _titleController.text = goal.title;
      _memoController.text = goal.memo ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    _titleFocusNode.dispose();
    _memoFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8EF),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isEditMode ? '目標を編集' : '目標を書く',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      bottomSheet: KeyboardDoneBar(
        focusNodes: [
          _titleFocusNode,
          _memoFocusNode,
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditMode
                    ? '目標の内容を編集できます。'
                    : 'やりたいことや達成したいことを、まずは気軽に書いてみよう。',
                style: const TextStyle(
                  color: Color(0xFF7D6B5D),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _InputCard(
                title: '目標',
                child: TextField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  decoration: const InputDecoration(
                    hintText: '目標を入力',
                    hintStyle: TextStyle(
                      color: Color(0xFFB8AEA5),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _InputCard(
                title: 'メモ（任意）',
                child: TextField(
                  controller: _memoController,
                  focusNode: _memoFocusNode,
                  minLines: 8,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: 'なぜ達成したいか、どう進めるかを書いておく',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isLoading ? null : _saveGoalNote,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF5A623),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditMode ? '更新する' : '保存する',
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

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
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
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF7D6B5D),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          child,
        ],
      ),
    );
  }
}