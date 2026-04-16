import 'package:flutter/material.dart';

/// Pantalla de análisis multi-dispositivo
class MultiDeviceAnalysisScreen extends StatelessWidget {
  const MultiDeviceAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis Multi-Dispositivo'),
        backgroundColor: const Color(0xFF1D1E33),
      ),
      body: const Center(
        child: Text(
          'Pantalla de Análisis Multi-Dispositivo - Próximamente',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
