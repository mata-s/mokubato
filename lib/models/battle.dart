class Battle {
  const Battle({
    required this.title,
    required this.subtitle,
    required this.participants,
    required this.daysLeft,
    required this.isOpen,
  });

  final String title;
  final String subtitle;
  final int participants;
  final int daysLeft;
  final bool isOpen;
}
