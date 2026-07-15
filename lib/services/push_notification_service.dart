import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase is disabled until the platform config files are added.
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _isFirebaseReady = false;
  bool _isInitialized = false;
  int _tokenSyncRetryCount = 0;
  Timer? _tokenSyncRetryTimer;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  static const int _maxTokenSyncRetries = 5;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isFirebaseReady = true;
    } catch (e) {
      debugPrint('firebase init skipped=$e');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
    await _syncCurrentToken();

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        'push foreground message title=${message.notification?.title} data=${message.data}',
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('push opened message data=${message.data}');
    });

    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) {
      _saveToken(token);
    });

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.initialSession ||
          data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.userUpdated ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        _syncCurrentToken();
      }
    });
  }

  Future<void> _requestPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('request push permission error=$e');
    }
  }

  Future<void> _syncCurrentToken() async {
    if (!_isFirebaseReady) return;
    if (Supabase.instance.client.auth.currentUser == null) return;

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null || apnsToken.isEmpty) {
          _scheduleTokenSyncRetry();
          return;
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('push token empty');
        return;
      }
      _tokenSyncRetryCount = 0;
      await _saveToken(token);
    } catch (e) {
      if (e.toString().contains('apns-token-not-set')) {
        _scheduleTokenSyncRetry();
        return;
      }

      debugPrint('sync push token error=$e');
    }
  }

  void _scheduleTokenSyncRetry() {
    if (_tokenSyncRetryTimer?.isActive ?? false) return;
    if (_tokenSyncRetryCount >= _maxTokenSyncRetries) return;

    _tokenSyncRetryCount += 1;

    if (_tokenSyncRetryCount == 1) {
      debugPrint('push token waiting for APNs token');
    }

    _tokenSyncRetryTimer = Timer(const Duration(seconds: 4), () {
      _syncCurrentToken();
    });
  }

  Future<void> _saveToken(String token) async {
    if (Supabase.instance.client.auth.currentUser == null) return;

    try {
      await Supabase.instance.client.rpc(
        'upsert_push_token',
        params: {'token_arg': token, 'platform_arg': _platformLabel},
      );
      debugPrint('push token saved platform=$_platformLabel');
    } catch (e) {
      debugPrint('save push token error=$e');
    }
  }

  String get _platformLabel {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<void> dispose() async {
    _tokenSyncRetryTimer?.cancel();
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }
}
