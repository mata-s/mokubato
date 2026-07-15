import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/keyboard_done_bar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _name;
  String? _userCode;
  String? _email;
  bool _isAnonymous = false;
  bool _isLoading = true;
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    final email = user?.email;
    if (userId == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('name,user_code')
        .eq('id', userId)
        .maybeSingle();

    if (!mounted) return;

    setState(() {
      _name = profile?['name'] as String?;
      _userCode = profile?['user_code'] as String?;
      _email = email;
      _isAnonymous = user?.isAnonymous ?? email == null;
      _isLoading = false;
    });
  }

  Future<void> _copyCode() async {
    final code = _userCode;
    if (code == null) return;

    await Clipboard.setData(ClipboardData(text: code));

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('コピーしました')));
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _name ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('表示名を変更'),
          content: TextField(
            controller: controller,
            focusNode: _nameFocusNode,
            autofocus: true,
            decoration: const InputDecoration(hintText: '表示名を入力'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client
        .from('profiles')
        .update({'name': result})
        .eq('id', userId);

    if (!mounted) return;

    setState(() {
      _name = result;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('表示名を更新しました')));
  }

  Future<void> _editEmail() async {
    final controller = TextEditingController(text: _email ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('メールアドレスを変更'),
          content: TextField(
            controller: controller,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'メールアドレスを入力'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty || result == _email) return;

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: result),
      );

      if (!mounted) return;

      setState(() {
        _email = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('確認メールを送信しました。メール内のリンクを確認してください。')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メールアドレスの変更に失敗しました。')));
    }
  }

  Future<void> _registerAccount() async {
    final emailController = TextEditingController(text: _email ?? '');
    final passwordController = TextEditingController();
    var obscurePassword = true;

    final result = await showDialog<({String email, String password})>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('アカウント登録'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'メールアドレスとパスワードを設定すると、機種変更や再ログインでもデータを引き継げます。',
                    style: TextStyle(
                      color: Color(0xFF7D6B5D),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    focusNode: _emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'メールアドレス',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      helperText: '6文字以上で入力してください',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, (
                      email: emailController.text.trim(),
                      password: passwordController.text,
                    ));
                  },
                  child: const Text('登録'),
                ),
              ],
            );
          },
        );
      },
    );

    final email = result?.email ?? '';
    final password = result?.password ?? '';

    if (result == null) return;

    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メールアドレスとパスワードを入力してください。')));
      return;
    }

    if (password.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('パスワードは6文字以上で入力してください。')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: email, password: password),
      );

      final user = response.user;

      if (!mounted) return;

      setState(() {
        _email = user?.email ?? email;
        _isAnonymous = user?.isAnonymous ?? false;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登録しました。')),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('アカウント登録に失敗しました。入力内容を確認してください。')),
      );
    }
  }

  Future<void> _editPassword() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('パスワードを変更'),
          content: TextField(
            controller: controller,
            focusNode: _passwordFocusNode,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: '新しいパスワード',
              helperText: '6文字以上で入力してください',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;

    if (result.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('パスワードは6文字以上で入力してください。')));
      return;
    }

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: result),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('パスワードを更新しました')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('パスワードの変更に失敗しました。')));
    }
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
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
          'プロフィール',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      bottomSheet: KeyboardDoneBar(
        focusNodes: [_nameFocusNode, _emailFocusNode, _passwordFocusNode],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileCard(
                    title: '表示名',
                    value: _name ?? '未設定',
                    icon: Icons.person_outline,
                    onTap: _editName,
                  ),
                  const SizedBox(height: 16),
                  if (_isAnonymous) ...[
                    _AccountRegistrationCard(onTap: _registerAccount),
                  ] else ...[
                    _ProfileCard(
                      title: 'メールアドレス',
                      value: _email ?? '未設定',
                      icon: Icons.email_outlined,
                      onTap: _editEmail,
                    ),
                    const SizedBox(height: 16),
                    _ProfileCard(
                      title: 'パスワード',
                      value: 'セキュリティのため表示できません',
                      icon: Icons.lock_outline,
                      onTap: _editPassword,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.qr_code_2_outlined),
                            SizedBox(width: 8),
                            Text(
                              'あなたのコード',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _userCode ?? '未発行',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _copyCode,
                            icon: const Icon(Icons.copy),
                            label: const Text('コピー'),
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

class _AccountRegistrationCard extends StatelessWidget {
  const _AccountRegistrationCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2F6B4F),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'アカウント登録',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'メールアドレスとパスワードを設定して、今のデータを引き継げるようにします。',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2F6B4F),
              ),
              child: const Text('登録する'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
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
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
