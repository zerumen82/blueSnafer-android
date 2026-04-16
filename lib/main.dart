import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'unified_attack_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const BlueSnaferApp());
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
