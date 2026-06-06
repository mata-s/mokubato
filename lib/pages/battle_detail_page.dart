import 'package:flutter/material.dart';
import '../models/battle_record.dart';
import 'record_page.dart';

class BattleDetailPage extends StatelessWidget {
  const BattleDetailPage({
    super.key,
    this.title = '今月の食費バトル',
    this.ruleLabel = '自分の目標に近い人が勝ち',
    this.periodLabel = '6/6〜7/6',
    this.recordTypeLabel = '毎回の記録を足していく',
  });

  final String title;
  final String ruleLabel;
  final String periodLabel;
  final String recordTypeLabel;

  List<BattleRecord> get _records => [
        BattleRecord(
          value: 1000,
          memo: 'コンビニ',
          createdAt: DateTime(2026, 6, 8),
        ),
        BattleRecord(
          value: 2500,
          memo: 'ランチ',
          createdAt: DateTime(2026, 6, 7),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8EF),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'バトル詳細',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF2F6B4F),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ruleLabel,
                      style: const TextStyle(
                        color: Color(0xFFE7F1E9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _HeroMetaItem(
                          icon: Icons.calendar_today_outlined,
                          label: periodLabel,
                        ),
                        const SizedBox(width: 18),
                        const _HeroMetaItem(
                          icon: Icons.group_outlined,
                          label: '5人参加中',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _ProgressSummaryCard(recordTypeLabel: recordTypeLabel),
              const SizedBox(height: 18),
              const _SectionTitle(title: '現在の順位'),
              const SizedBox(height: 10),
              const _RankingCard(
                rank: 1,
                name: 'まはる',
                value: '誤差 500円',
              ),
              const SizedBox(height: 10),
              const _RankingCard(
                rank: 2,
                name: '友達A',
                value: '誤差 1,200円',
              ),
              const SizedBox(height: 10),
              const _RankingCard(
                rank: 3,
                name: '友達B',
                value: '誤差 2,000円',
              ),
              const SizedBox(height: 24),
              const _SectionTitle(title: '最近の記録'),
              const SizedBox(height: 10),
              ..._records.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RecordCard(
                    date: '${record.createdAt.month}/${record.createdAt.day}',
                    value: '${record.value.toStringAsFixed(0)}円',
                    memo: record.memo,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecordPage(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF5A623),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                '記録する',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroMetaItem extends StatelessWidget {
  const _HeroMetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}



class _ProgressSummaryCard extends StatelessWidget {
  const _ProgressSummaryCard({required this.recordTypeLabel});

  final String recordTypeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '自分の状況',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F5EE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '残り24日',
                  style: TextStyle(
                    color: Color(0xFF2F6B4F),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            recordTypeLabel,
            style: const TextStyle(
              color: Color(0xFF7D6B5D),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                child: _ProgressValueItem(
                  label: '目標',
                  value: '30,000円',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _ProgressValueItem(
                  label: '現在',
                  value: '12,000円',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 0.4,
              minHeight: 10,
              backgroundColor: Color(0xFFF4EFE8),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2F6B4F)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '目標まであと18,000円',
            style: TextStyle(
              color: Color(0xFF7D6B5D),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressValueItem extends StatelessWidget {
  const _ProgressValueItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EFE8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7D6B5D),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
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
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.rank,
    required this.name,
    required this.value,
  });

  final int rank;
  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1D6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Color(0xFF9A6500),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF7D6B5D),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.date,
    required this.value,
    required this.memo,
  });

  final String date;
  final String value;
  final String memo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: const TextStyle(
                  color: Color(0xFF7D6B5D),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            memo,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}