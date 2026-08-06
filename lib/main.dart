import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/push_notification_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Firebase FCM is mobile-only: web platform has no FCM token support here.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(onFirebaseBackgroundMessage);
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
    }
  }

  await ApiClient.loadSavedToken();
  // Протухшая сессия должна уводить на экран входа, а не показывать
  // «Unauthorized» посреди формы: роутер слушает authService и сам сделает
  // редирект, как только токен пропадёт.
  ApiClient.onUnauthorized = () => authService.logout();
  await initializeDateFormatting('ru_RU');
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const AutoterraApp());
}
