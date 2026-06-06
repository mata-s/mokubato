class GoalNote {
  const GoalNote({
    required this.title,
    this.completed = false,
  });

  final String title;
  final bool completed;
}