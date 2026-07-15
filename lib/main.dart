import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/welcome_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/home_page.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zxtlvacvkenzbjxcpuio.supabase.co',
    anonKey: 'sb_publishable_ndZoPYw7YbEVfZ2jMl8N8w_IChu7b1a',
  );

  unawaited(PushNotificationService.instance.initialize());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'もくバト',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja')],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF8EF),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      return const HomePage();
    }

    return const WelcomePage();
  }
}
