class Battle {
  const Battle({
    required this.id,
    required this.title,
    this.description,
    required this.rule,
    required this.recordType,
    required this.participants,
    required this.startDate,
    required this.endDate,
    required this.isOpen,
    required this.inviteCode,
    required this.createdBy,
    this.forceEndedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String rule;
  final String recordType;
  final int participants;
  final DateTime startDate;
  final DateTime endDate;
  final bool isOpen;
  final String inviteCode;
  final String createdBy;
  final DateTime? forceEndedAt;

  factory Battle.fromMap(Map<String, dynamic> map, {int? participants}) {
    return Battle(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      rule: map['rule'] as String,
      recordType: map['record_type'] as String,
      participants: participants ?? (map['participants'] as int? ?? 1),
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      isOpen: map['is_open'] as bool,
      inviteCode: map['invite_code'] as String? ?? '',
      createdBy: map['created_by'] as String? ?? '',
      forceEndedAt: map['force_ended_at'] == null
          ? null
          : DateTime.parse(map['force_ended_at'] as String),
    );
  }

  bool get isForceEnded => forceEndedAt != null;

  int get daysLeft {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final end = DateTime(endDate.year, endDate.month, endDate.day);

    final diff = end.difference(today).inDays + 1;

    return diff < 0 ? 0 : diff;
  }

  String get periodLabel {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final start = DateTime(startDate.year, startDate.month, startDate.day);

    final end = DateTime(endDate.year, endDate.month, endDate.day);

    if (today.isBefore(start)) {
      return '${startDate.month}/${startDate.day}開始';
    }

    if (isForceEnded || today.isAfter(end)) {
      return '終了';
    }

    return '残り$daysLeft日';
  }

  String get subtitle => rule;
}
