import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../utils/device_utils.dart' as device_utils;

/// Pantalla mejorada de selección de dispositivos Bluetooth
class DeviceSelectionScreen extends StatefulWidget {
  @override
  State<DeviceSelectionScreen> createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends State<DeviceSelectionScreen> {
  static const platform = MethodChannel('com.bluesnafer_pro/bluetooth');

  bool _isScanning = false;
  bool _isBluetoothEnabled = false;
  String _scanStatus = 'Listo para escanear';
  List<Map<String, dynamic>> _foundDevices = [];
  Map<String, dynamic>? _bluetoothStatus;

  @override
  void initState() {
    super.initState();
    _checkBluetoothStatus();
  }

  Future<void> _checkBluetoothStatus() async {
    try {
      final status = await platform.invokeMethod('getBluetoothStatus');
      setState(() {
        _bluetoothStatus = Map<String, dynamic>.from(status);
        _isBluetoothEnabled = _bluetoothStatus?['can_scan'] ?? false;
      });
    } catch (e) {
      setState(() {
        _scanStatus = 'Error verificando Bluetooth: $e';
      });
    }
  }

  Future<void> _scanForDevices() async {
    if (!_isBluetoothEnabled) {
      setState(() {
        _scanStatus = 'Bluetooth no disponible. Actívalo primero.';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _scanStatus = '🔍 Escaneando dispositivos Bluetooth...';
      _foundDevices.clear();
    });

    try {
      // Timeout de seguridad para evitar que se quede colgado
      final scanFuture = platform.invokeMethod('scanDevices');

      // Configurar timeout
      final timeoutFuture = Future.delayed(Duration(seconds: 10), () {
        throw TimeoutException('Escaneo excedió el tiempo límite');
      });

      final result = await Future.any([scanFuture, timeoutFuture]);

      if (result is List) {
        setState(() {
          _foundDevices = List<Map<String, dynamic>>.from(result);
          _isScanning = false;
          _scanStatus = _foundDevices.isNotEmpty
              ? '✅ ${_foundDevices.length} dispositivos encontrados'
              : '⚠️ No se encontraron dispositivos';
        });
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _scanStatus = '❌ Error durante escaneo: $e';
      });

      // Si fue timeout, mostrar mensaje específico
      if (e is TimeoutException) {
        setState(() {
          _scanStatus = '⏰ Escaneo cancelado por timeout. Intenta nuevamente.';
        });
      }
    }
  }

  Future<void> _enableBluetooth() async {
    try {
      final enabled = await platform.invokeMethod('enableBluetooth');
      if (enabled == true) {
        await _checkBluetoothStatus();
        if (_isBluetoothEnabled) {
          _scanForDevices();
        }
      } else {
        setState(() {
          _scanStatus = '❌ No se pudo activar Bluetooth';
        });
      }
    } catch (e) {
      setState(() {
        _scanStatus = 'Error activando Bluetooth: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Dispositivo Bluetooth'),
        backgroundColor: Colors.blue,
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
              // Estado del Bluetooth
              _buildBluetoothStatusCard(),

              const SizedBox(height: 16),

              // Estado del escaneo
              _buildScanStatusCard(),

              const SizedBox(height: 16),

              // Botón de escaneo
              _buildScanButton(),

              const SizedBox(height: 16),

              // Lista de dispositivos encontrados
              Expanded(
                child: _buildDeviceList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBluetoothStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isBluetoothEnabled
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isBluetoothEnabled ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _isBluetoothEnabled
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: _isBluetoothEnabled ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isBluetoothEnabled
                      ? 'Bluetooth Activado'
                      : 'Bluetooth Desactivado',
                  style: TextStyle(
                    color: _isBluetoothEnabled ? Colors.green : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isBluetoothEnabled)
                ElevatedButton(
                  onPressed: _enableBluetooth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Activar', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          if (_bluetoothStatus != null) ...[
            const SizedBox(height: 8),
            Text(
              'Estado: ${_bluetoothStatus!['bluetooth_supported'] == true ? 'Soportado' : 'No soportado'}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScanStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _isScanning ? Icons.sync : Icons.info,
                color: _isScanning ? Colors.orange : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _scanStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (_isScanning) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              color: Colors.orange,
              backgroundColor: Colors.white24,
            ),
            const SizedBox(height: 8),
            Text(
              'Escaneando... Esto puede tomar hasta 10 segundos',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isScanning ? null : _scanForDevices,
        icon: _isScanning
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.search),
        label: Text(_isScanning ? 'ESCANEANDO...' : '🔍 ESCANEAR DISPOSITIVOS'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_foundDevices.isEmpty && !_isScanning) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bluetooth_searching, color: Colors.grey, size: 48),
              SizedBox(height: 16),
              Text(
                'No hay dispositivos encontrados',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Pulsa "Escanear" para buscar dispositivos cercanos',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
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
              color: Colors.blue.withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.devices, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'DISPOSITIVOS ENCONTRADOS (${_foundDevices.length})',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _foundDevices.length,
              itemBuilder: (context, index) {
                final device = _foundDevices[index];
                return _buildDeviceItem(device);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(Map<String, dynamic> device) {
    final name = device_utils.getDeviceDisplayName(device);
    final address = device['address'] ?? '';
    final rssi = device['rssi'] ?? 0;
    final type = device['type'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Icon(
          type == 1 ? Icons.watch : Icons.bluetooth,
          color: Colors.blue,
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              address,
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
            Text(
              'Señal: ${rssi} dBm',
              style: TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (device['bonded'] == true) ? Colors.green : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            (device['bonded'] == true) ? 'EMP' : 'NUEVO',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _selectDevice(device),
      ),
    );
  }

  void _selectDevice(Map<String, dynamic> device) {
    Navigator.pop(context, device);
  }
}


