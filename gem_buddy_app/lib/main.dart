import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    debugPrint("Firebase initialized successfully.");
  } catch (e) {
    debugPrint("Firebase initialization failed (Google Services config may be missing): $e");
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    const ProviderScope(
      child: GemApp(),
    ),
  );
}

class GemApp extends StatelessWidget {
  const GemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GEM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: GemColors.bgPrimary,
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: 'monospace', // Gives a premium technical retro aesthetic
        colorScheme: const ColorScheme.light(
          primary: GemColors.accentBlue,
          secondary: GemColors.accentPurple,
          surface: GemColors.bgSecondary,
          error: GemColors.statusAlert,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: GemColors.accentBlue,
          thumbColor: GemColors.accentBlue,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
