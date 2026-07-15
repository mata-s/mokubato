import 'package:flutter/material.dart';

import '../models/goal_note.dart';

class GoalNoteCard extends StatelessWidget {
  const GoalNoteCard({
    super.key,
    required this.goals,
    required this.onAddPressed,
    required this.onGoalTap,
    required this.onViewAllPressed,
  });

  final List<GoalNote> goals;
  final VoidCallback onAddPressed;
  final ValueChanged<GoalNote> onGoalTap;
  final VoidCallback onViewAllPressed;

  @override
  Widget build(BuildContext context) {
    final activeGoals = goals.where((goal) => !goal.completed).toList();
    final completedGoals = goals.where((goal) => goal.completed).toList();

    final displayGoals = [
      ...activeGoals,
      ...completedGoals,
    ];

    final visibleGoals = displayGoals.take(3).toList();
    final hiddenCount =
        displayGoals.length > 3 ? displayGoals.length - 3 : 0;
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '目標ノート',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: onViewAllPressed,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '見る',
                  style: TextStyle(
                    color: Color(0xFFE9A23B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...visibleGoals.map(
            (goal) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onGoalTap(goal),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        goal.completed
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: goal.completed
                            ? const Color(0xFF2F6B4F)
                            : const Color(0xFFB8B8B8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          goal.title,
                          style: TextStyle(
                            fontSize: 15,
                            decoration: goal.completed
                                ? TextDecoration.lineThrough
                                : null,
                            decorationThickness: 2,
                            color: goal.completed
                                ? const Color(0xFF9E9E9E)
                                : Colors.black,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFFB8AEA5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hiddenCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'あと$hiddenCount件を見る',
                style: const TextStyle(
                  color: Color(0xFF7D6B5D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text('新しい目標を追加'),
            ),
          ),
        ],
      ),
    );
  }
}