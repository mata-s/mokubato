class GoalNote {
  const GoalNote({
    required this.id,
    required this.title,
    this.memo,
    this.completed = false,
  });

  final String id;
  final String title;
  final String? memo;
  final bool completed;

  factory GoalNote.fromMap(Map<String, dynamic> map) {
    return GoalNote(
      id: map['id'] as String,
      title: map['title'] as String,
      memo: map['memo'] as String?,
      completed: map['is_completed'] as bool? ?? false,
    );
  }
}