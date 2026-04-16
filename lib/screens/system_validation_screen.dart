import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pantalla integrada de pruebas y validación del sistema
class SystemValidationScreen extends StatefulWidget {
  @override
  State<SystemValidationScreen> createState() => _SystemValidationScreenState();
}

class _SystemValidationScreenState extends State<SystemValidationScreen> {
  static const platform = MethodChannel('com.bluesnafer_pro/bluetooth');

  bool _isRunningTests = false;
  bool _isRunningQuickCheck = false;
  String _currentStatus = 'Sistema listo para pruebas';
  List<String> _validationLogs = [];
  Map<String, dynamic>? _validationResults;

  // Configuraciones de prueba disponibles
  final List<Map<String, String>> _testConfigurations = [
    {'name': 'Validación Básica', 'type': 'basic'},
    {'name': 'Validación Completa', 'type': 'full'},
    {'name': 'Pruebas de Rendimiento', 'type': 'performance'},
    {'name': 'Pruebas de Seguridad', 'type': 'security'},
    {'name': 'Pruebas de Dispositivos Reales', 'type': 'real_devices'},
  ];

  Future<void> _runSystemValidation(String testType) async {
    setState(() {
      _isRunningTests = true;
      _currentStatus = 'Ejecutando validación del sistema...';
      _validationLogs.clear();
      _validationResults = null;
    });

    try {
      final result = await platform.invokeMethod('runSystemValidation', {
        'testType': testType,
      });

      setState(() {
        _validationResults = Map<String, dynamic>.from(result);
        _currentStatus = 'Validación completada exitosamente';
        _validationLogs.add('✅ Validación ejecutada exitosamente');
        _isRunningTests = false;
      });

    } catch (e) {
      setState(() {
        _currentStatus = 'Error en validación: $e';
        _validationLogs.add('❌ Error: $e');
        _isRunningTests = false;
      });
    }
  }

  Future<void> _runQuickSystemCheck() async {
    setState(() {
      _isRunningQuickCheck = true;
      _currentStatus = 'Ejecutando chequeo rápido...';
      _validationLogs.clear();
    });

    try {
      final result = await platform.invokeMethod('runQuickSystemCheck');

      setState(() {
        _validationResults = Map<String, dynamic>.from(result);
        _currentStatus = 'Chequeo rápido completado';
        _validationLogs.add('✅ Chequeo rápido ejecutado exitosamente');
        _isRunningQuickCheck = false;
      });

    } catch (e) {
      setState(() {
        _currentStatus = 'Error en chequeo rápido: $e';
        _validationLogs.add('❌ Error: $e');
        _isRunningQuickCheck = false;
      });
    }
  }

  Future<void> _testDeviceNameSystem() async {
    setState(() {
      _isRunningTests = true;
      _currentStatus = 'Probando sistema de nombres mejorado...';
      _validationLogs.clear();
    });

    try {
      final result = await platform.invokeMethod('testDeviceNameSystem');

      setState(() {
        _validationResults = Map<String, dynamic>.from(result);
        _currentStatus = 'Pruebas de nombres completadas';
        _validationLogs.add('✅ Sistema de nombres probado exitosamente');
        _isRunningTests = false;
      });

    } catch (e) {
      setState(() {
        _currentStatus = 'Error en pruebas de nombres: $e';
        _validationLogs.add('❌ Error: $e');
        _isRunningTests = false;
      });
    }
  }

  Future<void> _generateSystemReport() async {
    setState(() {
      _isRunningTests = true;
      _currentStatus = 'Generando reporte del sistema...';
      _validationLogs.clear();
    });

    try {
      final result = await platform.invokeMethod('generateSystemStatusReport');

      setState(() {
        _validationResults = Map<String, dynamic>.from(result);
        _currentStatus = 'Reporte generado exitosamente';
        _validationLogs.add('✅ Reporte del sistema generado');
        _isRunningTests = false;
      });

    } catch (e) {
      setState(() {
        _currentStatus = 'Error generando reporte: $e';
        _validationLogs.add('❌ Error: $e');
        _isRunningTests = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validación y Pruebas del Sistema'),
        backgroundColor: Colors.deepPurple,
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
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isRunningTests || _isRunningQuickCheck ? Icons.sync : Icons.check_circle,
                          color: _isRunningTests || _isRunningQuickCheck ? Colors.orange : Colors.green,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentStatus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isRunningTests || _isRunningQuickCheck) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        color: _isRunningQuickCheck ? Colors.blue : Colors.deepPurple,
                        backgroundColor: Colors.white24,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Configuraciones de prueba
              _buildTestConfigurationsSection(),

              const SizedBox(height: 16),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRunningTests || _isRunningQuickCheck ? null : _runQuickSystemCheck,
                      icon: _isRunningQuickCheck
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.speed),
                      label: const Text('CHEQUEO RÁPIDO'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRunningTests || _isRunningQuickCheck ? null : () => _runSystemValidation('full'),
                      icon: _isRunningTests
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.analytics),
                      label: const Text('VALIDACIÓN COMPLETA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Botones adicionales
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRunningTests || _isRunningQuickCheck ? null : _testDeviceNameSystem,
                      icon: const Icon(Icons.text_fields),
                      label: const Text('PRUEBA NOMBRES'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRunningTests || _isRunningQuickCheck ? null : _generateSystemReport,
                      icon: const Icon(Icons.description),
                      label: const Text('REPORTE SISTEMA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Logs de validación
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.2),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.terminal, color: Colors.deepPurple, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'LOGS DE VALIDACIÓN',
                              style: TextStyle(
                                color: Colors.deepPurple,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _validationLogs.length,
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
                                _validationLogs[index],
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Resultados de validación
              if (_validationResults != null) ...[
                _buildValidationResultsCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestConfigurationsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'CONFIGURACIONES DE PRUEBA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._testConfigurations.map((config) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    config['name']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    config['type']!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildValidationResultsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'RESULTADOS DE VALIDACIÓN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_validationResults!['total_validation_time'] != null) ...[
            Text(
              'Tiempo total: ${_validationResults!['total_validation_time']}ms',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          if (_validationResults!['system_status'] != null) ...[
            Text(
              'Estado del sistema: ${_validationResults!['system_status']}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          if (_validationResults!['validation_timestamp'] != null) ...[
            Text(
              'Timestamp: ${_validationResults!['validation_timestamp']}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}


