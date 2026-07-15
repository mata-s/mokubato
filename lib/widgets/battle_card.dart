import 'package:flutter/material.dart';

import '../models/battle.dart';

class BattleCard extends StatelessWidget {
  const BattleCard({super.key, required this.data});

  final Battle data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
            children: [
              Expanded(
                child: Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusChip(isOpen: data.isOpen),
            ],
          ),
          if ((data.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              data.description ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF7D6B5D),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              _MetaItem(
                icon: Icons.group_outlined,
                label: '参加者 ${data.participants}人',
              ),
              const SizedBox(width: 18),
              _MetaItem(
                icon: Icons.calendar_today_outlined,
                label: data.periodLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFE9F5EE) : const Color(0xFFFFF1D6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOpen ? 'オープン' : '招待制',
        style: TextStyle(
          color: isOpen ? const Color(0xFF2F6B4F) : const Color(0xFF9A6500),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF7D6B5D)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7D6B5D),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}