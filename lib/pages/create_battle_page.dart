import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/keyboard_done_bar.dart';
import 'battle_detail_page.dart';
import '../models/battle.dart';

enum BattleRule {
  higherIsBetter,
  lowerIsBetter,
  aboveMyTarget,
  belowMyTarget,
  closestToMyTarget,
}

enum BattleTargetMode {
  noTarget,
  useTarget,
}

enum BattleRecordType {
  increment,
  current,
}

class CreateBattlePage extends StatefulWidget {
  const CreateBattlePage({
  super.key,
  this.initialTitle,
});

final String? initialTitle;

  @override
  State<CreateBattlePage> createState() => _CreateBattlePageState();
}

class _CreateBattlePageState extends State<CreateBattlePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _targetValueController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  final FocusNode _targetValueFocusNode = FocusNode();
  final FocusNode _unitFocusNode = FocusNode();
  final FocusNode _dummyFocusNode = FocusNode();

  bool _isOpen = false;
  bool _hideLastWeek = true;
  BattleTargetMode _selectedTargetMode = BattleTargetMode.noTarget;
  BattleRule _selectedRule = BattleRule.higherIsBetter;
  BattleRecordType _selectedRecordType = BattleRecordType.increment;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month + 1, now.day);
    final initialTitle = widget.initialTitle;
    if (initialTitle != null && initialTitle.trim().isNotEmpty) {
      _titleController.text = initialTitle.trim();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetValueController.dispose();
    _unitController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _targetValueFocusNode.dispose();
    _unitFocusNode.dispose();
    _dummyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    FocusScope.of(context).requestFocus(_dummyFocusNode);
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
    FocusScope.of(context).requestFocus(_dummyFocusNode);
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
      case BattleRule.higherIsBetter:
        return '目標値なしで、記録した合計が多い人ほど上位になります。';
      case BattleRule.lowerIsBetter:
        return '目標値なしで、記録した合計が少ない人ほど上位になります。';
      case BattleRule.aboveMyTarget:
        return '参加者ごとに目標値を決めて、目標より上回った差で競います。';
      case BattleRule.belowMyTarget:
        return '参加者ごとに目標値を決めて、目標より下回った差で競います。';
      case BattleRule.closestToMyTarget:
        return '参加者ごとに目標値を決めて、結果との差が小さい人ほど上位になります。';
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

  String _ruleValue(BattleRule rule) {
    switch (rule) {
      case BattleRule.higherIsBetter:
        return 'higher_is_better';
      case BattleRule.lowerIsBetter:
        return 'lower_is_better';
      case BattleRule.aboveMyTarget:
        return 'above_my_target';
      case BattleRule.belowMyTarget:
        return 'below_my_target';
      case BattleRule.closestToMyTarget:
        return 'closest_to_my_target';
    }
  }

  String _recordTypeValue(BattleRecordType recordType) {
    switch (recordType) {
      case BattleRecordType.increment:
        return 'increment';
      case BattleRecordType.current:
        return 'current';
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final code = List.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join();

    return 'MKB-$code';
  }

  void _showError(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

  Future<void> _createBattle() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final targetValueText = _targetValueController.text.trim();
    final unit = _unitController.text.trim();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final inviteCode = _generateInviteCode();

if (title.isEmpty) {
  _showError('バトル名を入力してください');
  return;
}

final needsTarget = _selectedTargetMode == BattleTargetMode.useTarget;

if (needsTarget && targetValueText.isEmpty) {
  _showError('目標値を入力してください');
  return;
}

final targetValue = targetValueText.isEmpty
    ? null
    : double.tryParse(targetValueText);

if (targetValueText.isNotEmpty && targetValue == null) {
  _showError('目標値は数値で入力してください');
  return;
}

if (needsTarget && unit.isEmpty) {
  _showError('単位を入力してください');
  return;
}

if (userId == null) {
  _showError('ログイン情報を取得できませんでした');
  return;
}

    setState(() => _isSaving = true);

    try {
      final battle = await Supabase.instance.client
          .from('battles')
          .insert({
            'title': title,
            'description': description.isEmpty ? null : description,
            'rule': _ruleValue(_selectedRule),
            'record_type': _recordTypeValue(_selectedRecordType),
            'is_open': _isOpen,
            'start_date': _startDate.toIso8601String(),
            'end_date': _endDate.toIso8601String(),
            'hide_last_week': _hideLastWeek,
            'created_by': userId,
            'invite_code': inviteCode,
          })
          .select()
          .single();

      await Supabase.instance.client.from('battle_participants').insert({
        'battle_id': battle['id'],
        'user_id': userId,
        'target_value': targetValue,
        'unit': unit,
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BattleDetailPage(
            battle: Battle.fromMap(battle),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
      bottomSheet: KeyboardDoneBar(
        focusNodes: [
          _titleFocusNode,
          _descriptionFocusNode,
          _targetValueFocusNode,
          _unitFocusNode,
        ],
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
                requiredMark: true,
                child: TextField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  decoration: const InputDecoration(
                    hintText: '例：食費バトル',
                    hintStyle: TextStyle(
                      color: Color(0xFFB8AEA5),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
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
                  focusNode: _descriptionFocusNode,
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
                title: '勝敗ルール',
                description: _ruleDescription(_selectedRule),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ModeButton(
                            label: '目標値なし',
                            selected:
                                _selectedTargetMode == BattleTargetMode.noTarget,
                            onTap: () {
                              setState(() {
                                _selectedTargetMode = BattleTargetMode.noTarget;
                                _selectedRule = BattleRule.higherIsBetter;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ModeButton(
                            label: '目標値あり',
                            selected:
                                _selectedTargetMode == BattleTargetMode.useTarget,
                            onTap: () {
                              setState(() {
                                _selectedTargetMode = BattleTargetMode.useTarget;
                                _selectedRule = BattleRule.closestToMyTarget;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_selectedTargetMode == BattleTargetMode.noTarget) ...[
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
                    ] else ...[
                      _RuleButton(
                        title: '目標より上が勝ち',
                        subtitle: '目標をどれだけ上回ったかで競います。',
                        selected: _selectedRule == BattleRule.aboveMyTarget,
                        onTap: () {
                          setState(() {
                            _selectedRule = BattleRule.aboveMyTarget;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _RuleButton(
                        title: '目標より下が勝ち',
                        subtitle: '目標をどれだけ下回ったかで競います。',
                        selected: _selectedRule == BattleRule.belowMyTarget,
                        onTap: () {
                          setState(() {
                            _selectedRule = BattleRule.belowMyTarget;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _RuleButton(
                        title: '目標に近い人が勝ち',
                        subtitle: '結果と目標値の差が小さい人ほど上位になります。',
                        selected: _selectedRule == BattleRule.closestToMyTarget,
                        onTap: () {
                          setState(() {
                            _selectedRule = BattleRule.closestToMyTarget;
                          });
                        },
                      ),
                    ],
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
                title: _selectedTargetMode == BattleTargetMode.useTarget
                    ? 'あなたの目標・単位'
                    : '単位',
                description: _selectedTargetMode == BattleTargetMode.useTarget
                    ? '目標値ありのルールでは、参加者全員が目標値と単位を入力します。'
                    : '記録に使う単位を設定できます。未入力でも作成できます。',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedTargetMode == BattleTargetMode.useTarget) ...[
                      const _FieldLabel(
                        text: '目標値',
                        requiredMark: true,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _targetValueController,
                        focusNode: _targetValueFocusNode,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          hintText: '例：30000',
                          filled: true,
                          fillColor: Color(0xFFF4EFE8),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _FieldLabel(
                      text: '単位',
                      requiredMark:
                          _selectedTargetMode == BattleTargetMode.useTarget,
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _unitController,
                      focusNode: _unitFocusNode,
                      decoration: InputDecoration(
                        hintText: _selectedTargetMode == BattleTargetMode.useTarget
                            ? '例：円、歩、時間、kg'
                            : '任意：例 円、歩、時間、kg',
                        filled: true,
                        fillColor: const Color(0xFFF4EFE8),
                        border: const OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving ? null : _createBattle,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF5A623),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isSaving
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              '作成中...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : const Text(
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.text,
    this.requiredMark = false,
  });

  final String text;
  final bool requiredMark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF7D6B5D),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (requiredMark) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: Color(0xFFE16A3D),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.title,
    required this.child,
    this.requiredMark = false,
  });

  final String title;
  final Widget child;
  final bool requiredMark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(
            text: title,
            requiredMark: requiredMark,
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
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onTap();
      },
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
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
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
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: value
                        ? const Color(0xFFE9F5EE)
                        : const Color(0xFFF4EFE8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    value ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: value
                          ? const Color(0xFF2F6B4F)
                          : const Color(0xFF7D6B5D),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Switch(
                  value: value,
                  activeColor: const Color(0xFF2F6B4F),
                  onChanged: onChanged,
                ),
              ],
            ),
          ],
        ),
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