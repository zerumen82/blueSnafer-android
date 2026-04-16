// Pantalla de escaneo Bluetooth minimalista
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bluetooth_service.dart';
import '../utils/device_utils.dart' as device_utils;
import 'stats_dashboard.dart';

class BluetoothScannerScreen extends StatefulWidget {
  const BluetoothScannerScreen({super.key});

  @override
  State<BluetoothScannerScreen> createState() => _BluetoothScannerScreenState();
}

class _BluetoothScannerScreenState extends State<BluetoothScannerScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  List<Map<String, dynamic>> _devices = [];
  bool _isScanning = false;
  String _statusMessage = 'Presiona ESCANEAR para comenzar';
  String _selectedAttackType = 'basic';
  String _selectedBtleJackCommand = 'scan';
  bool _isBluetoothEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBluetoothState();
  }

  Future<void> _checkBluetoothState() async {
    try {
      final result = await _bluetoothService.getConfig();
      setState(() {
        _isBluetoothEnabled = result['bluetoothEnabled'] ?? true;
      });
    } on PlatformException catch (e) {
      print('❌ Error verificando Bluetooth: ${e.message}');
      setState(() {
        _isBluetoothEnabled = true; // Asumir habilitado por defecto
      });
    }
  }

  Future<void> _scanDevices() async {
    if (!_isBluetoothEnabled) {
      setState(() {
        _statusMessage = '❌ Bluetooth está desactivado. Actívalo desde la configuración.';
      });
      _showBluetoothDialog();
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = '🔍 Buscando dispositivos...';
      _devices = [];
    });

    print('🔍 Iniciando escaneo Bluetooth...');

    try {
      final devices = await _bluetoothService.scanDevices();
      print('📱 Dispositivos encontrados: ${devices.length}');

      setState(() {
        _devices = devices;
        _isScanning = false;
        _statusMessage = _devices.isEmpty
            ? 'No se encontraron dispositivos.\n\nAsegúrate de:\n• Tener dispositivos BLE cercanos\n• Que estén en modo emparejamiento\n• Tener ubicación activada'
            : '✅ ${_devices.length} dispositivo${_devices.length != 1 ? 's' : ''} encontrado${_devices.length != 1 ? 's' : ''}';
      });
    } on PlatformException catch (e) {
      print('❌ PlatformException durante el escaneo: ${e.code} - ${e.message}');
      setState(() {
        _isScanning = false;
        _statusMessage = 'Error ${e.code}: ${e.message}';
      });
    } catch (e) {
      print('❌ Error durante el escaneo: $e');
      setState(() {
        _isScanning = false;
        _statusMessage = 'Error durante el escaneo: $e';
      });
    }
  }

  void _showBluetoothDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Bluetooth Desactivado'),
        content: const Text(
          'El Bluetooth está desactivado. Por favor actívalo desde la configuración de tu dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Abrir configuración de Bluetooth
            },
            child: const Text('Abrir Configuración'),
          ),
        ],
      ),
    );
  }

  Future<void> _startAnalysis(Map<String, dynamic> device) async {
    try {
      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Analizando dispositivo...'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Por favor espera mientras se analiza el dispositivo'),
            ],
          ),
        ),
      );

      // 1. Primero analizar firmware
      final firmwareResult = await _bluetoothService.analyzeFirmware(device['address']);

      // 2. Luego ejecutar análisis básico
      final attackResult = await _bluetoothService.executeAttack(
        device['address'],
        type: 'basic',
      );

      // 3. Finalmente ejecutar inyección AT (opcional)
      final atResult = await _bluetoothService.executeATInjection(device['address']);

      // 4. Intentar exfiltración de archivos (si es posible)
      final exfilResult = await _bluetoothService.exfiltrateFiles(device['address']);

      // 5. Ejecutar ataque DoS (opcional, solo si el dispositivo es vulnerable)
      final dosResult = await _bluetoothService.executeDoSAttack(device['address'], durationSeconds: 10);

      // 6. Ejecutar ataque de spoofing (opcional)
      final spoofResult = await _bluetoothService.executeSpoofingAttack(device['address']);

      // Cerrar diálogo de progreso
      Navigator.pop(context);

      // Mostrar resultados combinados
      _showAnalysisResults(device, firmwareResult, attackResult, atResult, exfilResult, dosResult, spoofResult);

    } catch (e) {
      Navigator.pop(context); // Cerrar diálogo de progreso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error durante el análisis: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAnalysisResults(
    Map<String, dynamic> device,
    Map<String, dynamic> firmwareResult,
    Map<String, dynamic> attackResult,
    Map<String, dynamic> atResult,
    Map<String, dynamic> exfilResult,
    Map<String, dynamic> dosResult,
    Map<String, dynamic> spoofResult,
  ) {
    final firmwareInfo = Map<String, dynamic>.from(firmwareResult['deviceInfo'] ?? {});
    final attackAnalysis = Map<String, dynamic>.from(attackResult['analysis'] ?? {});
    final atSummary = Map<String, dynamic>.from(atResult['summary'] ?? {});
    final filesExfiltrated = exfilResult['filesExfiltrated'] as int? ?? 0;
    final dosSummary = Map<String, dynamic>.from(dosResult['summary'] ?? {});
    final spoofSuccess = spoofResult['success'] as bool? ?? false;
    final spoofedDevice = spoofResult['spoofedDevice'] as String? ?? 'N/A';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resultado del Análisis Completo'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Resumen general
              Text('Dispositivo: ${device_utils.getDeviceDisplayName(device)}'),
              Text('Dirección: ${device['address']}'),
              const SizedBox(height: 16),

              // Estado general
              Text(
                'Estado General: ${firmwareInfo['isVulnerable'] == true || attackAnalysis['securityLevel'] == 'critical' ? 'VULNERABLE' : 'SEGURO'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: firmwareInfo['isVulnerable'] == true || attackAnalysis['securityLevel'] == 'critical' ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 16),

              // Información de firmware
              const Text(
                '📦 Información de Firmware:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Fabricante: ${firmwareInfo['manufacturer'] ?? 'Desconocido'}'),
              Text('Modelo: ${firmwareInfo['model'] ?? 'Desconocido'}'),
              Text('Versión: ${firmwareInfo['version'] ?? 'Desconocido'}'),
              Text('Estado: ${firmwareInfo['isVulnerable'] == true ? 'VULNERABLE' : 'SEGURO'}'),
              const SizedBox(height: 8),

              // Análisis de seguridad
              const Text(
                '🔒 Análisis de Seguridad:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Nivel de seguridad: ${attackAnalysis['securityLevel']}'),
              Text('Vulnerabilidades: ${attackAnalysis['vulnerabilities'].length}'),
              Text('CVE afectados: ${attackAnalysis['cveList'].length}'),
              const SizedBox(height: 8),

              // Inyección AT
              const Text(
                '🔍 Inyección AT:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Comandos ejecutados: ${atSummary['totalCommands']}'),
              Text('Vulnerabilidades encontradas: ${atSummary['vulnerabilitiesFound']}'),
              Text('Vulnerabilidades críticas: ${atSummary['criticalVulnerabilities']}'),
              const SizedBox(height: 8),

              // Exfiltración de archivos
              if (filesExfiltrated > 0) ...[
                const Text(
                  '📁 Exfiltración de Archivos:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Archivos obtenidos: $filesExfiltrated'),
                Text('Ubicación: /sdcard/Download/BlueSnafer_Files/'),
                const SizedBox(height: 8),
              ],

              // Ataques DoS
              const Text(
                '💥 Ataques DoS:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Ataques ejecutados: ${dosSummary['totalAttacks']}'),
              Text('Ataques exitosos: ${dosSummary['successfulAttacks']}'),
              Text('Paquetes promedio: ${dosSummary['averagePacketsPerAttack']}'),
              const SizedBox(height: 8),

              // Spoofing
              const Text(
                '👤 Spoofing:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Éxito: ${spoofSuccess ? 'Sí' : 'No'}'),
              Text('Dispositivo spoofed: $spoofedDevice'),
              const SizedBox(height: 8),

              // Recomendaciones
              if (firmwareResult['recommendations'].isNotEmpty) ...[
                const Text(
                  '📋 Recomendaciones:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...List<String>.from(firmwareResult['recommendations'])
                    .take(3)
                    .map((r) => Text('• $r'))
                    .toList(),
                if (firmwareResult['recommendations'].length > 3)
                  Text('• Y ${firmwareResult['recommendations'].length - 3} más...'),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navegar al dashboard de estadísticas
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatsDashboard()),
              );
            },
            child: const Text('Ver Estadísticas'),
          ),
        ],
      ),
    );
  }

  Widget _buildAttackChip(String value, String emoji, String label, Color color) {
    final isSelected = _selectedAttackType == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAttackType = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: isSelected ? null : Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
                color: isSelected ? color : Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  DropdownMenuItem<String> _buildDropdownItem(String value, String text, Color color) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escaneo Bluetooth'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Botón de escaneo
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isScanning ? null : _scanDevices,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _isScanning ? 'Escaneando...' : 'Escanear Dispositivos',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Estado
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),

            const SizedBox(height: 16),

            // Selector de tipo de ataque - Diseño Horizontal Mejorado
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.redAccent, Colors.orangeAccent],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.security,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TIPO DE ATAQUE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              'Selecciona el método de explotación',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Opciones en HORIZONTAL con diseño de chips
                    Row(
                      children: [
                        Expanded(
                          child: _buildAttackChip(
                            'basic',
                            '🔹',
                            'Básico',
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAttackChip(
                            'blueborne',
                            '🔴',
                            'BlueBorne',
                            Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAttackChip(
                            'btlejack',
                            '🟡',
                            'BtleJack',
                            Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    if (_selectedAttackType == 'blueborne')
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.withOpacity(0.2), Colors.red.withOpacity(0.1)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'BlueBorne',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'CVE-2017-0781 | Solo Android < 8.0 sin parches',
                                    style: TextStyle(
                                      color: Colors.red[300],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_selectedAttackType == 'btlejack')
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber.withOpacity(0.2), Colors.amber.withOpacity(0.1)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tune, color: Colors.amberAccent, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Comando BtleJack',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[200],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedBtleJackCommand,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF1A1A2E),
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  items: [
                                    _buildDropdownItem('scan', '🔍 Escaneo', Colors.blue),
                                    _buildDropdownItem('sniff', '📡 Captura', Colors.purple),
                                    _buildDropdownItem('hijack', '🎯 Hijacking', Colors.red),
                                    _buildDropdownItem('mitm', '👤 Man-in-the-Middle', Colors.orange),
                                    _buildDropdownItem('jam', '🚫 Jamming', Colors.grey),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedBtleJackCommand = value!;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Lista de dispositivos
            Expanded(
              child: _devices.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay dispositivos disponibles',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final isBonded = device['isBonded'] == true;
                        final rssi = device['rssi'] != null ? int.tryParse(device['rssi'].toString()) : null;
                        final signalIcon = rssi != null
                            ? (rssi >= -60 ? '📶' : rssi >= -75 ? '📵' : '📴')
                            : '';

                        return Card(
                          color: isBonded ? Colors.green[900]?.withOpacity(0.2) : null,
                          child: ListTile(
                            leading: Icon(
                              isBonded ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                              color: isBonded ? Colors.greenAccent : Colors.blueAccent,
                            ),
                            title: Row(
                              children: [
                                Text(
                                  device_utils.getDeviceDisplayName(device),
                                  style: const TextStyle(color: Colors.white),
                                ),
                                if (isBonded)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'EMPAREJADO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Row(
                              children: [
                                Text(device['address'], style: const TextStyle(color: Colors.grey)),
                                const SizedBox(width: 8),
                                Text(signalIcon, style: const TextStyle(fontSize: 12)),
                                if (rssi != null)
                                  Text('(${rssi} dBm)', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.security, color: Colors.red),
                              onPressed: () => _startAnalysis(device),
                              tooltip: 'Analizar dispositivo',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
