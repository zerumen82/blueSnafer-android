// Aplicación principal minimalista
import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';

class BlueSnaferApp extends StatelessWidget {
  const BlueSnaferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueSnafer Pro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
