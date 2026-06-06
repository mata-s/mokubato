import 'package:flutter/material.dart';
import 'battle_detail_page.dart';

enum BattleRule {
  closestToMyTarget,
  higherIsBetter,
  lowerIsBetter,
}

enum BattleRecordType {
  increment,
  current,
}

class CreateBattlePage extends StatefulWidget {
  const CreateBattlePage({super.key});

  @override
  State<CreateBattlePage> createState() => _CreateBattlePageState();
}

class _CreateBattlePageState extends State<CreateBattlePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _targetValueController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();

  bool _isOpen = false;
  bool _hideLastWeek = true;
  BattleRule _selectedRule = BattleRule.closestToMyTarget;
  BattleRecordType _selectedRecordType = BattleRecordType.increment;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month + 1, now.day);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetValueController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate.add(const Duration(days: 30));
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  String _ruleDescription(BattleRule rule) {
    switch (rule) {
      case BattleRule.closestToMyTarget:
        return 'それぞれが自分に合った目標値を決めて、無理なく競えます。';
      case BattleRule.higherIsBetter:
        return '記録した合計が多い人ほど上位になります。';
      case BattleRule.lowerIsBetter:
        return '記録した合計が少ない人ほど上位になります。';
    }
  }

  String _ruleLabel(BattleRule rule) {
    switch (rule) {
      case BattleRule.closestToMyTarget:
        return '自分の目標に近い人が勝ち';
      case BattleRule.higherIsBetter:
        return '多い人が勝ち';
      case BattleRule.lowerIsBetter:
        return '少ない人が勝ち';
    }
  }

  String _recordTypeDescription(BattleRecordType recordType) {
    switch (recordType) {
      case BattleRecordType.increment:
        return '食費・歩数・勉強時間など、毎回の記録を合計していきます。';
      case BattleRecordType.current:
        return '体重・体脂肪率など、最新の数値を記録します。';
    }
  }

  String _recordTypeLabel(BattleRecordType recordType) {
    switch (recordType) {
      case BattleRecordType.increment:
        return '毎回の記録を足していく';
      case BattleRecordType.current:
        return '最新の数値で見る';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8EF),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'バトル作成',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '友達だけで遊ぶ招待制か、誰でも参加できるオープンバトルを作れます。',
                style: TextStyle(
                  color: Color(0xFF7D6B5D),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _InputCard(
                title: 'バトル名',
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: '例：今月の食費バトル',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _InputCard(
                title: '説明',
                child: TextField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: '例：1ヶ月の食費を目標に近づけるバトル',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ChoiceCard(
                title: '勝敗ルール',
                description: _ruleDescription(_selectedRule),
                child: Column(
                  children: [
                    _RuleButton(
                      title: '自分の目標に近い人が勝ち',
                      subtitle: '参加者ごとに目標値を決めて、結果との差で競います。',
                      selected: _selectedRule == BattleRule.closestToMyTarget,
                      onTap: () {
                        setState(() {
                          _selectedRule = BattleRule.closestToMyTarget;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _RuleButton(
                      title: '多い人が勝ち',
                      subtitle: '歩数・勉強時間・回数など、積み上げる目標向けです。',
                      selected: _selectedRule == BattleRule.higherIsBetter,
                      onTap: () {
                        setState(() {
                          _selectedRule = BattleRule.higherIsBetter;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _RuleButton(
                      title: '少ない人が勝ち',
                      subtitle: '食費・スマホ時間・間食など、減らしたい目標向けです。',
                      selected: _selectedRule == BattleRule.lowerIsBetter,
                      onTap: () {
                        setState(() {
                          _selectedRule = BattleRule.lowerIsBetter;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ChoiceCard(
                title: '記録方法',
                description: _recordTypeDescription(_selectedRecordType),
                child: Column(
                  children: [
                    _RuleButton(
                      title: '毎回の記録を足していく',
                      subtitle: '今日使った金額、今日歩いた歩数などを積み上げます。',
                      selected: _selectedRecordType == BattleRecordType.increment,
                      onTap: () {
                        setState(() {
                          _selectedRecordType = BattleRecordType.increment;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _RuleButton(
                      title: '最新の数値で見る',
                      subtitle: '体重や体脂肪率のように、今の数値を更新していきます。',
                      selected: _selectedRecordType == BattleRecordType.current,
                      onTap: () {
                        setState(() {
                          _selectedRecordType = BattleRecordType.current;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ChoiceCard(
                title: '期間',
                description: '開始日と終了日を決めます。まずは1ヶ月がおすすめです。',
                child: Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: '開始日',
                        dateText: _formatDate(_startDate),
                        onTap: _pickStartDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateButton(
                        label: '終了日',
                        dateText: _formatDate(_endDate),
                        onTap: _pickEndDate,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ChoiceCard(
                title: '参加方法',
                description: _isOpen
                    ? '誰でも見つけて参加できます。'
                    : '招待コードを知っている人だけ参加できます。',
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        label: '招待制',
                        selected: !_isOpen,
                        onTap: () => setState(() => _isOpen = false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ModeButton(
                        label: 'オープン',
                        selected: _isOpen,
                        onTap: () => setState(() => _isOpen = true),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SwitchCard(
                title: '最後の1週間を非表示',
                description: '終盤の記録を隠して、月末までドキドキ感を残します。',
                value: _hideLastWeek,
                onChanged: (value) {
                  setState(() => _hideLastWeek = value);
                },
              ),
              const SizedBox(height: 16),
              _ChoiceCard(
                title: 'あなたの目標',
                description: 'まずは作成者であるあなたの目標を設定します。',
                child: Column(
                  children: [
                    TextField(
                      controller: _targetValueController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '例：30000',
                        filled: true,
                        fillColor: Color(0xFFF4EFE8),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.all(
                            Radius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        hintText: '例：円、歩、時間',
                        filled: true,
                        fillColor: Color(0xFFF4EFE8),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.all(
                            Radius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    final title = _titleController.text.trim().isEmpty
                        ? '新しいバトル'
                        : _titleController.text.trim();
                    final ruleLabel = _ruleLabel(_selectedRule);
                    final recordTypeLabel = _recordTypeLabel(_selectedRecordType);
                    final periodLabel =
                        '${_formatDate(_startDate)}〜${_formatDate(_endDate)}';

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BattleDetailPage(
                          title: title,
                          ruleLabel: ruleLabel,
                          periodLabel: periodLabel,
                          recordTypeLabel: recordTypeLabel,
                        ),
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
                  child: const Text(
                    '作成する',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF7D6B5D),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF7D6B5D),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2F6B4F) : const Color(0xFFF4EFE8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF7D6B5D),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.dateText,
    required this.onTap,
  });

  final String label;
  final String dateText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4EFE8),
          borderRadius: BorderRadius.circular(14),
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
              dateText,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF7D6B5D),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF2F6B4F),
            onChanged: onChanged,
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

class _RuleButton extends StatelessWidget {
  const _RuleButton({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE9F5EE) : const Color(0xFFF4EFE8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF2F6B4F) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? const Color(0xFF2F6B4F) : const Color(0xFFB8B8B8),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? const Color(0xFF2F6B4F) : Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7D6B5D),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}