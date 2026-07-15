import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'name_setup_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'メールアドレスとパスワードを入力してください';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'パスワードは6文字以上で入力してください';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const NameSetupPage(),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'アカウント作成に失敗しました。入力内容を確認してください';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8EF),
        elevation: 0,
        title: const Text('新規作成'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'アカウント作成',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'パスワード',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _passwordController.text.length >= 6
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: _passwordController.text.length >= 6
                      ? Colors.green
                      : Colors.grey,
                ),
                const SizedBox(width: 6),
                const Text(
                  'パスワードは6文字以上',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7D6B5D),
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _isLoading ? null : _signUp,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('アカウントを作成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}