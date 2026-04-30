import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'unified_attack_screen.dart';
import 'utils/advanced_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  runZonedGuarded(() async {
    await AdvancedLogger.initialize();
    runApp(const BlueSnaferApp());
  }, (error, stack) {
    try {
      final f = File('/storage/emulated/0/Download/bluesnafer_crash.txt');
      f.writeAsStringSync('${DateTime.now()}\n$error\n$stack');
    } catch (_) {}
  });
}

class BlueSnaferApp extends StatelessWidget {
  const BlueSnaferApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BlueSnafer Pro',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF020617),
      primaryColor: Colors.indigoAccent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF020617),
        elevation: 0,
        centerTitle: true,
      ),
      colorScheme: const ColorScheme.dark(
        primary: Colors.indigoAccent,
        secondary: Colors.cyanAccent,
        surface: Color(0xFF0F172A),
        onSurface: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: Colors.indigoAccent,
        labelColor: Colors.indigoAccent,
        unselectedLabelColor: Colors.white24,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigoAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
        bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
        titleLarge: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    ),
    home: const PermissionScreen(),
  );
}
