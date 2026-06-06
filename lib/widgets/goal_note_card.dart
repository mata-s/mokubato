import 'package:flutter/material.dart';

import '../models/goal_note.dart';

class GoalNoteCard extends StatelessWidget {
  const GoalNoteCard({
    super.key,
    required this.goals,
    required this.onAddPressed,
  });

  final List<GoalNote> goals;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
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
                '今月の目標',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('追加'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...goals.map(
            (goal) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                        color: goal.completed
                            ? const Color(0xFF8A8A8A)
                            : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}