import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';

class NameSetupPage extends StatefulWidget {
  const NameSetupPage({super.key});

  @override
  State<NameSetupPage> createState() => _NameSetupPageState();
}

class _NameSetupPageState extends State<NameSetupPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('名前を入力してください。'),
        ),
      );
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ログイン情報を確認できませんでした。'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'name': name,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('名前の保存に失敗しました。もう一度お試しください。'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text(
                '名前を決めよう',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'ランキングや記録に表示される名前です。あとから変更できます。',
                style: TextStyle(
                  color: Color(0xFF7D6B5D),
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nameController,
                maxLength: 12,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  FocusScope.of(context).unfocus();
                },
                decoration: InputDecoration(
                  labelText: '名前',
                  hintText: '',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF5A623),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'この名前で始める',
                          style: TextStyle(
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
    );
  }
}