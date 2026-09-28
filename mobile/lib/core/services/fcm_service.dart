import 'package:firebase_messaging/firebase_messaging.dart';

/// Firebase Cloud Messaging wrapper.
///
/// Initialization is fully guarded so the app runs even when Firebase is not
/// configured (no google-services.json). When configured, this registers the
/// push token with the backend and routes foreground messages to the in-app
/// notification inbox via a callback.
class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();
  bool _initialized = false;
  void Function(Map<String, dynamic>)? onMessage;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      _initialized = true;

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final data = {
          ...message.data,
          if (message.notification?.title != null) 'title': message.notification!.title,
          if (message.notification?.body != null) 'body': message.notification!.body,
        };
        onMessage?.call(data);
      });
    } catch (_) {
      _initialized = false;
    }
  }

  Future<String?> getToken() async {
    if (!_initialized) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }
}
