// Pantalla de conexión de dispositivos Bluetooth separada
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/real_exploit_screen.dart';
import 'utils/device_utils.dart' as device_utils;

class DeviceConnectionScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const DeviceConnectionScreen({
    super.key,
    required this.device,
  });

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> {
  static const platform = MethodChannel('bluetooth_scanner');
  
  bool _isConnected = false;
  bool _isConnecting = false;
  String _statusMessage = 'Listo para conectar';
  String _deviceInfo = '';

  @override
  void initState() {
    super.initState();
    _initializeDeviceInfo();
  }

  void _initializeDeviceInfo() {
    final device = widget.device;
    final name = device_utils.getDeviceDisplayName(device);
    final address = device['address']?.toString() ?? '';
    final rssi = device['rssi']?.toString() ?? '';
    
    setState(() {
      _deviceInfo = 'Nombre: $name\nDirección: $address\nSeñal: $rssi dBm';
    });
  }

  Future<void> _connectToDevice() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Conectando...';
    });

    try {
      final bool result = await platform.invokeMethod('connectToDevice', widget.device);
      
      setState(() {
        _isConnected = result;
        _isConnecting = false;
        _statusMessage = result 
            ? '¡Conectado exitosamente!'
            : 'Error en la conexión';
      });

      if (result) {
        // Navegar a la pantalla de análisis o control del dispositivo
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _disconnectDevice() async {
    setState(() {
      _statusMessage = 'Desconectando...';
    });

    try {
      await platform.invokeMethod('disconnectDevice');
      setState(() {
        _isConnected = false;
        _statusMessage = 'Desconectado';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error desconectando: $e';
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '¡Conexión Exitosa!',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Conectado a ${device_utils.getDeviceDisplayName(widget.device)}',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cerrar',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navegar a pantalla de análisis
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RealExploitScreen(device: widget.device),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Analizar Dispositivo',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F2027), // Dark blue-green
              Color(0xFF203A43), // Medium blue-green
              Color(0xFF2C5364), // Light blue-green
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Conexión de Dispositivo',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            device_utils.getDeviceDisplayName(widget.device),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Información del dispositivo
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2196F3), Color(0xFF21CBF3)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.bluetooth,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device_utils.getDeviceDisplayName(widget.device),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        widget.device['address'] ?? '',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _deviceInfo,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Estado de conexión
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _isConnected 
                              ? Colors.green.withOpacity(0.1)
                              : _isConnecting
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isConnected 
                                ? Colors.green.withOpacity(0.3)
                                : _isConnecting
                                    ? Colors.orange.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _isConnected 
                                  ? Icons.check_circle
                                  : _isConnecting
                                      ? Icons.sync
                                      : Icons.bluetooth_disabled,
                              color: _isConnected 
                                  ? Colors.green
                                  : _isConnecting
                                      ? Colors.orange
                                      : Colors.grey,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _statusMessage,
                              style: TextStyle(
                                color: _isConnected 
                                    ? Colors.green
                                    : _isConnecting
                                        ? Colors.orange
                                        : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Botón de acción
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isConnected 
                              ? _disconnectDevice
                              : _isConnecting 
                                  ? null 
                                  : _connectToDevice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isConnected 
                                ? Colors.red
                                : _isConnecting
                                    ? Colors.grey
                                    : const Color(0xFF667eea),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: _isConnected || _isConnecting ? 0 : 8,
                            shadowColor: _isConnected || _isConnecting 
                                ? Colors.transparent
                                : const Color(0xFF667eea).withOpacity(0.3),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isConnecting) ...[
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ] else if (_isConnected) ...[
                                const Icon(Icons.link_off, color: Colors.white),
                                const SizedBox(width: 12),
                              ] else ...[
                                const Icon(Icons.link, color: Colors.white),
                                const SizedBox(width: 12),
                              ],
                              Text(
                                _isConnected 
                                    ? 'DESCONECTAR'
                                    : _isConnecting
                                        ? 'CONECTANDO...'
                                        : 'CONECTAR',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Información adicional
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info,
                                    color: Color(0xFF667eea),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Información de Seguridad',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Expanded(
                                child: Text(
                                  '• Este dispositivo será analizado para vulnerabilidades de seguridad\n'
                                  '• La conexión se realiza de forma segura\n'
                                  '• Toda la información será encriptada\n'
                                  '• Los logs se eliminarán automáticamente',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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


