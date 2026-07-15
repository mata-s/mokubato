import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_page.dart';
import 'signUp_page.dart';
import 'name_setup_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _isLoading = false;

  Future<void> _startAnonymously() async {
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInAnonymously();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const NameSetupPage(),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ログインに失敗しました。もう一度お試しください。'),
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
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F6B4F),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'もくバト',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '自分に合った目標で、\n友達とゆるく競える目標バトルアプリ。',
                style: TextStyle(
                  color: Color(0xFF7D6B5D),
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WelcomeFeature(
                      icon: Icons.flag_outlined,
                      text: '自分だけの目標値を設定',
                    ),
                    SizedBox(height: 14),
                    _WelcomeFeature(
                      icon: Icons.groups_outlined,
                      text: '招待コードで友達と参加',
                    ),
                    SizedBox(height: 14),
                    _WelcomeFeature(
                      icon: Icons.visibility_off_outlined,
                      text: '最後の1週間は非表示でドキドキ',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isLoading ? null : _startAnonymously,
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
                          'はじめる',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginPage(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2F6B4F),
                    side: const BorderSide(color: Color(0xFF2F6B4F)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'ログイン',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SignUpPage(),
                      ),
                    );
                  },
                  child: const Text('メールアドレスで新規作成'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2F6B4F), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
