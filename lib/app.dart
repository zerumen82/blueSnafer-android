// Aplicación principal minimalista
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/bluetooth_provider.dart';
import 'screens/welcome_screen.dart';

class BlueSnaferApp extends StatelessWidget {
  const BlueSnaferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BluetoothProvider(),
      child: MaterialApp(
        title: 'BlueSnafer Pro',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const WelcomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
