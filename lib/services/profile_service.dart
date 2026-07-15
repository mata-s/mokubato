import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  const ProfileService._();

  static Future<void> ensureUserCode() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('user_code')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) return;

    if (profile['user_code'] != null) return;

    final code = _generateUserCode();

    await Supabase.instance.client
        .from('profiles')
        .update({
          'user_code': code,
        })
        .eq('id', userId);
  }

  static String _generateUserCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    final random = Random.secure();

    final suffix = List.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join();

    return 'MBT-$suffix';
  }
}