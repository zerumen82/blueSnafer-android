import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/device_utils.dart' as device_utils;

/// Pantalla integrada de pruebas con dispositivos reales
class RealDeviceTestingScreen extends StatefulWidget {
  @override
  State<RealDeviceTestingScreen> createState() =>
      _RealDeviceTestingScreenState();
}

class _RealDeviceTestingScreenState extends State<RealDeviceTestingScreen> {
  static const platform = MethodChannel('com.bluesnafer_pro/bluetooth');

  bool _isTesting = false;
  String _currentStatus = 'Listo para pruebas';
  List<String> _testLogs = [];
  Map<String, dynamic>? _testResults;

  // Dispositivos de prueba disponibles (se obtienen desde la plataforma nativa si están habilitados)
  List<Map<String, String>> _availableDevices = [];

  // Configuraciones de prueba disponibles
  final List<Map<String, String>> _testConfigurations = [
    {'name': 'Análisis Básico', 'type': 'complete_analysis'},
    {'name': 'Ataque Xiaomi', 'type': 'precision_attack'},
    {'name': 'Monitoreo Continuo', 'type': 'continuous_monitoring'},
    {'name': 'Análisis Multi-Dispositivo', 'type': 'multi_device'},
  ];

  Future<void> _startRealDeviceTesting() async {
    setState(() {
      _isTesting = true;
      _currentStatus = 'Ejecutando pruebas con dispositivos reales...';
      _testLogs.clear();
      _testResults = null;
    });

    try {
      // Obtener dispositivos seleccionados
      final selectedDevices =
          _availableDevices.map((d) => d['address']!).toList();

      // Ejecutar pruebas con dispositivos reales
      final result = await platform.invokeMethod('executeRealDeviceTesting', {
        'deviceAddresses': selectedDevices,
        'testConfigurations':
            _testConfigurations.map((c) => c['type']).toList(),
      });

      setState(() {
        _testResults = Map<String, dynamic>.from(result);
        _currentStatus = 'Pruebas completadas exitosamente';
        _testLogs.add('✅ Pruebas ejecutadas exitosamente');
        _testLogs.add('📊 Resultados disponibles en reporte');
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _currentStatus = 'Error en pruebas: $e';
        _testLogs.add('❌ Error: $e');
        _isTesting = false;
      });
    }
  }

  Future<void> _executeTemplateTest() async {
    setState(() {
      _isTesting = true;
      _currentStatus = 'Ejecutando plantilla de prueba...';
      _testLogs.clear();
    });

    try {
      // Ejecutar plantilla específica
      if (_availableDevices.isEmpty)
        throw Exception(
            'No hay dispositivos disponibles para ejecutar la plantilla');

      final result = await platform.invokeMethod('executeTemplateTest', {
        'templateName': 'comprehensive_security_audit',
        'deviceAddress': _availableDevices[0]['address'],
      });

      setState(() {
        _testResults = Map<String, dynamic>.from(result);
        _currentStatus = 'Plantilla ejecutada exitosamente';
        _testLogs.add('✅ Plantilla ejecutada exitosamente');
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _currentStatus = 'Error ejecutando plantilla: $e';
        _testLogs.add('❌ Error: $e');
        _isTesting = false;
      });
    }
  }

  Future<void> _analyzeParameterTuning() async {
    setState(() {
      _isTesting = true;
      _currentStatus = 'Analizando ajuste de parámetros...';
      _testLogs.clear();
    });

    try {
      // Obtener análisis de tendencias de efectividad
      final result = await platform.invokeMethod('analyzeEffectivenessTrends');

      setState(() {
        _testResults = Map<String, dynamic>.from(result);
        _currentStatus = 'Análisis de tendencias completado';
        _testLogs.add('✅ Análisis de efectividad completado');
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _currentStatus = 'Error analizando parámetros: $e';
        _testLogs.add('❌ Error: $e');
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pruebas con Dispositivos Reales'),
        backgroundColor: Colors.orange,
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
                  border: Border.all(color: Colors.orange.withValues(alpha: 0x33)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isTesting ? Icons.sync : Icons.check_circle,
                          color: _isTesting ? Colors.orange : Colors.green,
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
                    if (_isTesting) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(
                        color: Colors.orange,
                        backgroundColor: Colors.white24,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Dispositivos disponibles (solo en debug)
              if (_availableDevices.isNotEmpty) ...[
                _buildDevicesSection(),
                const SizedBox(height: 16),
              ],

              // Configuraciones de prueba
              _buildConfigurationsSection(),

              const SizedBox(height: 16),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isTesting ? null : _startRealDeviceTesting,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow),
                      label: const Text('PRUEBAS COMPLETAS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
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
                      onPressed: _isTesting ? null : _executeTemplateTest,
                      icon: const Icon(Icons.assignment),
                      label: const Text('PLANTILLA'),
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
                      onPressed: _isTesting ? null : _analyzeParameterTuning,
                      icon: const Icon(Icons.analytics),
                      label: const Text('ANÁLISIS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Logs de prueba
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0x33),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0x11)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0x22),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.terminal,
                                color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'LOGS DE PRUEBA',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _testLogs.length,
                          itemBuilder: (context, index) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withValues(alpha: 0x11),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                _testLogs[index],
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

              // Resultados de prueba
              if (_testResults != null) ...[
                _buildTestResultsCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchAvailableDevicesFromPlatform();
  }

  Future<void> _fetchAvailableDevicesFromPlatform() async {
    try {
      final result = await platform.invokeMethod('getKnownTestDevices');
      if (result is List) {
        final devices = result
            .map((d) {
              final map = Map<String, dynamic>.from(d as Map);
              return <String, String>{
                'name': (map['name'] ?? '') as String,
                'address': (map['address'] ?? '') as String,
              };
            })
            .where((d) => d['address']!.isNotEmpty)
            .toList();

        setState(() {
          _availableDevices = devices;
        });
      }
    } catch (e) {
      // Si falla la llamada, dejamos la lista vacía
      setState(() {
        _availableDevices = [];
      });
    }
  }

  Widget _buildDevicesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0x11)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.devices, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'DISPOSITIVOS DISPONIBLES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._availableDevices.map((device) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0x11),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0x33)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bluetooth, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device_utils.getDeviceDisplayName(device),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            device['address'] ?? 'Unknown',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0x77),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'DISPONIBLE',
                        style: TextStyle(
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

  Widget _buildConfigurationsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0x11)),
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
                  color: Colors.green.withValues(alpha: 0x11),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0x33)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      config['name']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      config['type']!.toUpperCase(),
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTestResultsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withValues(alpha: 0x33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              const Text(
                'RESULTADOS DE PRUEBA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_testResults!['session_id'] != null) ...[
            Text(
              'Sesión: ${_testResults!['session_id']}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          if (_testResults!['total_tests'] != null) ...[
            Text(
              'Pruebas ejecutadas: ${_testResults!['total_tests']}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          if (_testResults!['success_rate'] != null) ...[
            Text(
              'Tasa de éxito: ${(_testResults!['success_rate'] * 100).toInt()}%',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
