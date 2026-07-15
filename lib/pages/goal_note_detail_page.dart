import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/goal_note.dart';
import 'goal_note_page.dart';
import 'create_battle_page.dart';

class GoalNoteDetailPage extends StatelessWidget {
  const GoalNoteDetailPage({
    super.key,
    required this.goal,
  });

  final GoalNote goal;

  @override
  Widget build(BuildContext context) {
    final hasMemo = goal.memo != null && goal.memo!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8EF),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '目標ノート',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                      'タイトル',
                      style: TextStyle(
                        color: Color(0xFF7D6B5D),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      goal.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'メモ',
                      style: TextStyle(
                        color: Color(0xFF7D6B5D),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasMemo ? goal.memo!.trim() : 'メモはありません。',
                      style: TextStyle(
                        color: hasMemo ? Colors.black : const Color(0xFFB8AEA5),
                        fontSize: 15,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GoalNotePage(goal: goal),
                          ),
                        );

                        if (updated == true && context.mounted) {
                          Navigator.pop(context, true);
                        }
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('編集'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final shouldDelete = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('目標を削除しますか？'),
                              content: const Text(
                                'この操作は取り消せません。',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context, false);
                                  },
                                  child: const Text('キャンセル'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.pop(context, true);
                                  },
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

                        final userId = Supabase.instance.client.auth.currentUser?.id;

                        if (userId == null) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ログイン情報を確認できませんでした。'),
                            ),
                          );
                          return;
                        }

                        try {
                          await Supabase.instance.client
                              .from('goal_notes')
                              .delete()
                              .eq('id', goal.id)
                              .eq('user_id', userId);

                          if (!context.mounted) return;
                          Navigator.pop(context, true);
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('削除に失敗しました。もう一度お試しください。'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('削除'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () async {
                    final userId = Supabase.instance.client.auth.currentUser?.id;

                    if (userId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ログイン情報を確認できませんでした。'),
                        ),
                      );
                      return;
                    }

                    try {
                      await Supabase.instance.client
                          .from('goal_notes')
                          .update({
                            'is_completed': !goal.completed,
                            'updated_at': DateTime.now().toIso8601String(),
                          })
                          .eq('id', goal.id)
                          .eq('user_id', userId);

                      if (!context.mounted) return;
                      Navigator.pop(context, true);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('更新に失敗しました。もう一度お試しください。'),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    goal.completed
                        ? Icons.radio_button_unchecked
                        : Icons.check_circle_outline,
                  ),
                  label: Text(goal.completed ? '未達成に戻す' : '達成'),
                  style: FilledButton.styleFrom(
                    backgroundColor: goal.completed
                        ? const Color(0xFF7D6B5D)
                        : const Color(0xFF2F6B4F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              if (!goal.completed) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateBattlePage(
                          initialTitle: goal.title,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.sports_score_outlined),
                  label: const Text('この目標でバトルを作る'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2F6B4F),
                    side: const BorderSide(color: Color(0xFF2F6B4F)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              ],
            ],
          ),

        ),
      ),
    );
  }
}