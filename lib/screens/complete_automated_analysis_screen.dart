import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pantalla para ejecutar análisis completo automatizado
class CompleteAutomatedAnalysisScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const CompleteAutomatedAnalysisScreen({super.key, required this.device});

  @override
  State<CompleteAutomatedAnalysisScreen> createState() => _CompleteAutomatedAnalysisScreenState();
}

class _CompleteAutomatedAnalysisScreenState extends State<CompleteAutomatedAnalysisScreen> {
  static const platform = MethodChannel('com.bluesnafer_pro/bluetooth');
  bool _isExecuting = false;
  String _statusMessage = 'Listo para ejecutar análisis completo';
  List<String> _executionLogs = [];

  Future<void> _executeCompleteAnalysis() async {
    setState(() {
      _isExecuting = true;
      _statusMessage = 'Ejecutando análisis completo automatizado...';
      _executionLogs.clear();
    });

    try {
      // Ejecutar análisis completo desde Kotlin
      final result = await platform.invokeMethod('executeCompleteAutomatedAnalysis', {
        'deviceAddress': widget.device['address'],
      });

      setState(() {
        _statusMessage = 'Análisis completado exitosamente';
        _executionLogs.add('✅ Análisis completo finalizado');
        _executionLogs.add('📊 Tasa de éxito: ${result['successRate']}%');
        _executionLogs.add('⏱️ Tiempo total: ${result['totalTime']}ms');
        _isExecuting = false;
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'Error en análisis: $e';
        _executionLogs.add('❌ Error: $e');
        _isExecuting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis Completo Automatizado'),
        backgroundColor: Colors.purple,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E21), Color(0xFF1D1E33)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Estado actual
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1E33),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isExecuting ? Icons.sync : Icons.check_circle,
                          color: _isExecuting ? Colors.orange : Colors.green,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isExecuting) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(
                        color: Colors.purple,
                        backgroundColor: Colors.white24,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Botón de ejecución
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isExecuting ? null : _executeCompleteAnalysis,
                  icon: _isExecuting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 20),
                  label: Text(_isExecuting ? 'EJECUTANDO...' : 'INICIAR ANÁLISIS COMPLETO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Logs de ejecución
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: ListView.builder(
                    itemCount: _executionLogs.length,
                    itemBuilder: (context, index) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          _executionLogs[index],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


