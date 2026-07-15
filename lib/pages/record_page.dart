import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/keyboard_done_bar.dart';

enum RecordType { increment, current }

class RecordPage extends StatefulWidget {
  const RecordPage({
    super.key,
    required this.battleId,
    this.recordType = RecordType.increment,
    this.recordId,
    this.initialValue,
    this.initialMemo,
    this.initialImageUrl,
  });

  final String battleId;
  final RecordType recordType;
  final String? recordId;
  final double? initialValue;
  final String? initialMemo;
  final String? initialImageUrl;

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final FocusNode _valueFocusNode = FocusNode();
  final FocusNode _memoFocusNode = FocusNode();
  File? _selectedImage;
  String? _existingImageUrl;
  String? _message;
  bool _isSaving = false;

  bool get _isEditMode => widget.recordId != null;

  @override
  void initState() {
    super.initState();

    final initialValue = widget.initialValue;
    if (initialValue != null) {
      _valueController.text = _formatInitialValue(initialValue);
    }

    _memoController.text = widget.initialMemo ?? '';
    _existingImageUrl = widget.initialImageUrl;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 1280,
    );

    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
    });
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _existingImageUrl = null;
    });
  }

  Future<void> _saveRecord() async {
    final valueText = _valueController.text.trim();
    final value = double.tryParse(valueText);
    final memo = _memoController.text.trim();

    if (value == null) {
      setState(() {
        _message = '数値を入力してください。';
      });
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      setState(() {
        _message = 'ログイン情報を取得できませんでした。';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      String? imageUrl;

      if (_selectedImage != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${widget.battleId}/$userId/$timestamp.jpg';

        await Supabase.instance.client.storage
            .from('battle-record-images')
            .upload(
              filePath,
              _selectedImage!,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );

        imageUrl = Supabase.instance.client.storage
            .from('battle-record-images')
            .getPublicUrl(filePath);
      }

      final savedImageUrl = imageUrl ?? _existingImageUrl;

      if (_isEditMode) {
        await Supabase.instance.client.rpc(
          'update_battle_record',
          params: {
            'record_id_arg': widget.recordId!,
            'value_arg': value,
            'memo_arg': memo.isEmpty ? null : memo,
            'image_url_arg': savedImageUrl,
          },
        );
      } else {
        await Supabase.instance.client.from('battle_records').insert({
          'battle_id': widget.battleId,
          'user_id': userId,
          'value': value,
          'memo': memo.isEmpty ? null : memo,
          'image_url': savedImageUrl,
        });
      }

      await _syncParticipantValue(userId);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('save record error=$e');

      if (!mounted) return;

      setState(() {
        _message = '保存に失敗しました。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _syncParticipantValue(String userId) async {
    final records = await Supabase.instance.client
        .from('battle_records')
        .select('value,created_at')
        .eq('battle_id', widget.battleId)
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final recordRows = records as List;
    final nextValue = widget.recordType == RecordType.increment
        ? recordRows.fold<double>(0, (sum, item) {
            final map = item as Map<String, dynamic>;
            return sum + (((map['value'] as num?) ?? 0).toDouble());
          })
        : recordRows.isEmpty
        ? 0.0
        : ((((recordRows.first as Map<String, dynamic>)['value'] as num?) ?? 0)
              .toDouble());

    await Supabase.instance.client
        .from('battle_participants')
        .update({'current_value': nextValue})
        .eq('battle_id', widget.battleId)
        .eq('user_id', userId);
  }

  String _formatInitialValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toString();
  }

  @override
  void dispose() {
    _valueController.dispose();
    _memoController.dispose();
    _valueFocusNode.dispose();
    _memoFocusNode.dispose();
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
        title: Text(
          _isEditMode ? '記録を編集' : '記録する',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F6B4F),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2F6B4F).withOpacity(0.16),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.edit_note_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _titleText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              height: 1.25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '数値を入力すると、バトルの現在値とランキングに反映されます。',
                            style: TextStyle(
                              color: Color(0xFFE7F1E9),
                              fontSize: 13,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _InputCard(
                      title: _valueLabel,
                      icon: Icons.numbers_outlined,
                      child: TextField(
                        controller: _valueController,
                        focusNode: _valueFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: _hintText,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InputCard(
                      title: 'メモ（任意）',
                      icon: Icons.chat_bubble_outline,
                      child: TextField(
                        controller: _memoController,
                        focusNode: _memoFocusNode,
                        minLines: 4,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          hintText: '例：今日はコンビニを我慢できた',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child:
                            _selectedImage == null && _existingImageUrl == null
                            ? Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF8EF),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.image_outlined,
                                      color: Color(0xFF7D6B5D),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '証拠写真（任意）',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'タップして写真を選択できます。',
                                          style: TextStyle(
                                            color: Color(0xFF7D6B5D),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: _selectedImage != null
                                        ? Image.file(
                                            _selectedImage!,
                                            width: double.infinity,
                                            height: 180,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.network(
                                            _existingImageUrl!,
                                            width: double.infinity,
                                            height: 180,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          '写真を選択中',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _removeImage,
                                        child: const Text('削除'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _saveRecord,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF5A623),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          _isSaving
                              ? '保存中...'
                              : _isEditMode
                              ? '更新する'
                              : '保存する',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            KeyboardDoneBar(focusNodes: [_valueFocusNode, _memoFocusNode]),
          ],
        ),
      ),
    );
  }

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
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF7D6B5D), size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF7D6B5D),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}
