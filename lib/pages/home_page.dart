import 'package:flutter/material.dart';
import '../models/battle.dart';
import '../models/goal_note.dart';
import 'goal_note_page.dart';
import 'create_battle_page.dart';
import 'battle_detail_page.dart';
import '../widgets/battle_card.dart';
import '../widgets/goal_note_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final battles = [
      const Battle(
        title: '今月の食費バトル',
        subtitle: '目標に一番近い人が勝ち',
        participants: 5,
        daysLeft: 12,
        isOpen: false,
      ),
      const Battle(
        title: '毎日1万歩チャレンジ',
        subtitle: '歩数を記録して競う',
        participants: 8,
        daysLeft: 7,
        isOpen: true,
      ),
    ];

    final goals = [
      const GoalNote(title: 'Flutterを毎日触る'),
      const GoalNote(title: '食費3万円以内'),
      const GoalNote(title: '週3回散歩', completed: true),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'もくバト',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '今月の目標を、みんなで楽しく。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7D6B5D),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_outline),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GoalNoteCard(
                goals: goals,
                onAddPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GoalNotePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '参加中のバトル',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('オープンを見る'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: battles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BattleDetailPage(),
                          ),
                        );
                      },
                      child: BattleCard(data: battles[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateBattlePage(),
            ),
          );
        },
        backgroundColor: const Color(0xFFF5A623),
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add),
        label: const Text('作成'),
      ),
    );
  }
}