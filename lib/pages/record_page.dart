import 'package:flutter/material.dart';

enum RecordType {
  increment,
  current,
}

class RecordPage extends StatefulWidget {
  const RecordPage({
    super.key,
    this.recordType = RecordType.increment,
  });

  final RecordType recordType;

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  String get _titleText {
    switch (widget.recordType) {
      case RecordType.increment:
        return '今日の記録を追加しよう';
      case RecordType.current:
        return '現在の数値を記録しよう';
    }
  }

  String get _valueLabel {
    switch (widget.recordType) {
      case RecordType.increment:
        return '追加する数値';
      case RecordType.current:
        return '現在の数値';
    }
  }

  String get _hintText {
    switch (widget.recordType) {
      case RecordType.increment:
        return '例：1000';
      case RecordType.current:
        return '例：65.2';
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _memoController.dispose();
    super.dispose();
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
          '記録する',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleText,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              _InputCard(
                title: _valueLabel,
                child: TextField(
                  controller: _valueController,
                  keyboardType: TextInputType.number,
                  decoration:  InputDecoration(
                    hintText: _hintText,
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _InputCard(
                title: 'メモ（任意）',
                child: TextField(
                  controller: _memoController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: '今日はコンビニで使った',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.image_outlined, size: 32),
                    SizedBox(height: 8),
                    Text('証拠写真（後で実装）'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('保存する'),
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
  const _InputCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF7D6B5D),
              fontWeight: FontWeight.w700,
            ),
          ),
          child,
        ],
      ),
    );
  }
}