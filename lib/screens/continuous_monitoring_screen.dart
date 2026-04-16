import 'package:flutter/material.dart';

/// Pantalla de monitoreo continuo
class ContinuousMonitoringScreen extends StatelessWidget {
  final Map<String, dynamic> device;

  const ContinuousMonitoringScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoreo Continuo'),
        backgroundColor: const Color(0xFF1D1E33),
      ),
      body: const Center(
        child: Text(
          'Pantalla de Monitoreo Continuo - Próximamente',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
