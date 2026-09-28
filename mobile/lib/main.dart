import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers/repository_providers.dart';
import 'core/services/fcm_service.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/settings/providers/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is optional. If not configured, the app continues without push.
  try {
    await Firebase.initializeApp();
    await FcmService.instance.init();
  } catch (_) {
    // Firebase not configured - push notifications disabled.
  }

  final container = ProviderContainer();
  await container.read(themeModeProvider.notifier).init();
  // Restore any stored session so splash can route correctly.
  await container.read(authControllerProvider.notifier).restoreSession();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const McqApp(),
    ),
  );

  // Register push token with the backend once session exists.
  final fcmToken = await FcmService.instance.getToken();
  if (fcmToken != null) {
    try {
      await container.read(notificationRepositoryProvider).registerToken(fcmToken);
    } catch (_) {}
  }
}
