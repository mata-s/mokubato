import 'package:flutter/material.dart';

import '../models/goal_note.dart';

class GoalNoteListPage extends StatelessWidget {
  const GoalNoteListPage({
    super.key,
    required this.goals,
    required this.onGoalTap,
    required this.onAddPressed,
  });

  final List<GoalNote> goals;
  final ValueChanged<GoalNote> onGoalTap;
  final VoidCallback onAddPressed;

  Widget _buildGoalCard(GoalNote goal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => onGoalTap(goal),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              if (goal.completed == true) ...[
                const Icon(
                  Icons.check,
                  size: 18,
                  color: Color(0xFF2F6B4F),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2B211A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if ((goal.memo ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        goal.memo ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF7D6B5D),
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFB4A89D),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeGoals = goals
        .where((goal) => goal.completed != true)
        .toList();

    final completedGoals = goals
        .where((goal) => goal.completed == true)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      appBar: AppBar(
        title: const Text('目標ノート'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFF5A623),
        foregroundColor: Colors.white,
        onPressed: () {
          onAddPressed();
        },
        icon: const Icon(Icons.add),
        label: const Text(
          '追加',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: goals.isEmpty
          ? const Center(
              child: Text(
                'まだ目標がありません。',
                style: TextStyle(
                  color: Color(0xFF7D6B5D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '進行中 (${activeGoals.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ...activeGoals.map(_buildGoalCard),
                const SizedBox(height: 28),
                Text(
                  '達成済み (${completedGoals.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ...completedGoals.map(_buildGoalCard),
              ],
            ),
    );
  }
}