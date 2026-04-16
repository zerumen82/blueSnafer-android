import 'package:flutter/material.dart';
import '../attacks/timing_attack.dart';
import '../attacks/protocol_downgrade.dart';

/// Pantalla para ejecutar pruebas de seguridad
class SecurityTestScreen extends StatefulWidget {
  const SecurityTestScreen({super.key});

  @override
  State<SecurityTestScreen> createState() => _SecurityTestScreenState();
}

class _SecurityTestScreenState extends State<SecurityTestScreen> {
  final _timingAttack = BluetoothTimingAttack();
  final _downgradeAttack = ProtocolDowngradeAttack();

  bool _isRunningTest = false;
  String _testResult = '';
  String _selectedDevice = 'AA:BB:CC:DD:EE:FF'; // Dirección de ejemplo

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pruebas de Seguridad'),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Selector de dispositivo
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.devices, color: Colors.white70),
                    SizedBox(width: 12),
                    Text(
                      'Dispositivo: $_selectedDevice',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white70),
                      onPressed: () {
                        // Implementar selección de dispositivo
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Botón de prueba de timing
              Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isRunningTest ? null : _runTimingAttack,
                  icon: Icon(Icons.timer),
                  label: Text('EJECUTAR TIMING ATTACK'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Botón de prueba de downgrade
              Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isRunningTest ? null : _runDowngradeAttack,
                  icon: Icon(Icons.arrow_downward),
                  label: Text('EJECUTAR DOWNGRADE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Resultados
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resultados:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          _testResult.isEmpty
                              ? 'Ejecuta una prueba para ver resultados'
                              : _testResult,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Botón de regreso
              Container(
                width: double.infinity,
                height: 45,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back),
                  label: Text('VOLVER'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white70, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runTimingAttack() async {
    setState(() {
      _isRunningTest = true;
      _testResult = 'Ejecutando Timing Attack...\n';
    });

    try {
      final result = await _timingAttack.executeTimingAttack(_selectedDevice);

      setState(() {
        _testResult = 'Timing Attack Completado:\n\n' +
            'Éxito: ${result.success}\n' +
            'Mensaje: ${result.message}\n' +
            (result.analysis != null ? 'Análisis:\n${result.analysis!}' : '');
      });
    } catch (e) {
      setState(() {
        _testResult = 'Error en Timing Attack: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isRunningTest = false;
      });
    }
  }

  Future<void> _runDowngradeAttack() async {
    setState(() {
      _isRunningTest = true;
      _testResult = 'Ejecutando Downgrade Attack...\n';
    });

    try {
      final result = await _downgradeAttack.attemptDowngrade(_selectedDevice);

      setState(() {
        _testResult = 'Downgrade Attack Completado:\n\n' +
            'Éxito: ${result.success}\n' +
            'Mensaje: ${result.message}' +
            (result.fromVersion != null && result.toVersion != null
                ? '\nDe: ${result.fromVersion} a ${result.toVersion}'
                : '');
      });
    } catch (e) {
      setState(() {
        _testResult = 'Error en Downgrade Attack: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isRunningTest = false;
      });
    }
  }
}


