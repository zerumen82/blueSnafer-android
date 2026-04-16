// Servicio unificado para manejo de Bluetooth - Refactorización de integración Dart-Android
import 'package:flutter/services.dart';
import '../utils/device_utils.dart' as device_utils;

/// Servicio centralizado para operaciones de Bluetooth
/// Abstrae la comunicación con Android MethodChannel
class BluetoothScannerService {
  static const MethodChannel _channel = MethodChannel('bluetooth_scanner');
  
  // Callbacks para cambios de estado
  static Function(bool)? _onBluetoothStateChanged;
  static Function(List<dynamic>)? _onDevicesFound;
  static Function(String)? _onConnectionStatus;

  // Estado interno
  static bool _isBluetoothEnabled = false;
  static bool _isScanning = false;
  static List<dynamic> _discoveredDevices = [];
  static String _currentStatus = 'Listo para comenzar';

  /// Inicializar el servicio de Bluetooth
  static Future<void> initialize() async {
    try {
      // Configurar callback para MethodChannel
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Inicializar estado
      await _checkBluetoothState();
      
      _currentStatus = 'Servicio Bluetooth inicializado';
      print('✅ BluetoothScannerService: Inicializado correctamente');
    } catch (e) {
      _currentStatus = 'Error inicializando servicio: $e';
      print('❌ BluetoothScannerService: Error en inicialización: $e');
    }
  }

  /// Verificar estado actual de Bluetooth
  static Future<bool> get isBluetoothEnabled async {
    await _checkBluetoothState();
    return _isBluetoothEnabled;
  }

  /// Obtener estado actual de escaneo
  static bool get isScanning => _isScanning;

  /// Obtener lista de dispositivos descubiertos
  static List<dynamic> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  /// Obtener estado actual del servicio
  static String get currentStatus => _currentStatus;

  /// Configurar callback para cambios de estado de Bluetooth
  static void setBluetoothStateCallback(Function(bool) callback) {
    _onBluetoothStateChanged = callback;
  }

  /// Configurar callback para cuando se encuentren dispositivos
  static void setDevicesFoundCallback(Function(List<dynamic>) callback) {
    _onDevicesFound = callback;
  }

  /// Configurar callback para cambios de estado de conexión
  static void setConnectionStatusCallback(Function(String) callback) {
    _onConnectionStatus = callback;
  }

  /// Habilitar Bluetooth
  static Future<bool> enableBluetooth() async {
    try {
      _updateStatus('Activando Bluetooth...');
      final result = await _channel.invokeMethod('enableBluetooth');
      _isBluetoothEnabled = result ?? false;
      
      if (_isBluetoothEnabled) {
        _updateStatus('Bluetooth activado - ¡Listo para escanear!');
        _onBluetoothStateChanged?.call(true);
      } else {
        _updateStatus('No se pudo activar Bluetooth');
        _onBluetoothStateChanged?.call(false);
      }
      
      return _isBluetoothEnabled;
    } catch (e) {
      _updateStatus('Error activando Bluetooth: $e');
      _isBluetoothEnabled = false;
      _onBluetoothStateChanged?.call(false);
      return false;
    }
  }

  /// Deshabilitar Bluetooth
  static Future<bool> disableBluetooth() async {
    try {
      _updateStatus('Desactivando Bluetooth...');
      final result = await _channel.invokeMethod('disableBluetooth');
      _isBluetoothEnabled = !(result ?? false);
      
      _updateStatus('Bluetooth desactivado');
      _onBluetoothStateChanged?.call(_isBluetoothEnabled);
      
      return !_isBluetoothEnabled;
    } catch (e) {
      _updateStatus('Error desactivando Bluetooth: $e');
      return false;
    }
  }

  /// Escanear dispositivos Bluetooth
  static Future<List<dynamic>> scanDevices({
    int timeoutSeconds = 10,
    bool continuous = false,
  }) async {
    if (_isScanning) {
      _updateStatus('Escaneo ya en progreso...');
      return _discoveredDevices;
    }

    if (!_isBluetoothEnabled) {
      _updateStatus('Bluetooth no está activado');
      return [];
    }

    try {
      _isScanning = true;
      _discoveredDevices.clear();
      _updateStatus('🔍 Buscando dispositivos...');

      final result = await _channel.invokeMethod('scanDevices', {
        'timeout': timeoutSeconds,
        'continuous': continuous,
      });

      _discoveredDevices = result ?? [];
      _isScanning = false;

      final deviceCount = _discoveredDevices.length;
      _updateStatus(deviceCount == 0
          ? 'No se encontraron dispositivos'
          : '✅ $deviceCount dispositivo${deviceCount != 1 ? 's' : ''} encontrado${deviceCount != 1 ? 's' : ''}');

      _onDevicesFound?.call(List.from(_discoveredDevices));
      
      return List.from(_discoveredDevices);
    } catch (e) {
      _isScanning = false;
      _updateStatus('Error durante el escaneo: $e');
      return [];
    }
  }

  /// Detener escaneo actual
  static Future<void> stopScanning() async {
    if (!_isScanning) return;

    try {
      await _channel.invokeMethod('stopScanning');
      _isScanning = false;
      _updateStatus('Escaneo detenido');
    } catch (e) {
      _updateStatus('Error deteniendo escaneo: $e');
    }
  }

  /// Conectar a un dispositivo específico
  static Future<bool> connectToDevice(Map<String, dynamic> device) async {
    if (!_isBluetoothEnabled) {
      _updateStatus('Bluetooth no está activado');
      return false;
    }

    try {
      _updateStatus('Conectando a ${device_utils.getDeviceDisplayName(device)}...');

      final result = await _channel.invokeMethod('connectToDevice', device);
      final success = result ?? false;

      if (success) {
        _updateStatus('Conectado a ${device_utils.getDeviceDisplayName(device)}');
        _onConnectionStatus?.call('connected');
      } else {
        _updateStatus('Error conectando al dispositivo');
        _onConnectionStatus?.call('failed');
      }
      
      return success;
    } catch (e) {
      _updateStatus('Error de conexión: $e');
      _onConnectionStatus?.call('error');
      return false;
    }
  }

  /// Desconectar del dispositivo actual
  static Future<void> disconnectDevice() async {
    try {
      await _channel.invokeMethod('disconnectDevice');
      _updateStatus('Dispositivo desconectado');
      _onConnectionStatus?.call('disconnected');
    } catch (e) {
      _updateStatus('Error desconectando: $e');
    }
  }

  /// Enviar datos al dispositivo conectado
  static Future<bool> sendData(String data) async {
    try {
      final result = await _channel.invokeMethod('sendData', {'data': data});
      return result ?? false;
    } catch (e) {
      _updateStatus('Error enviando datos: $e');
      return false;
    }
  }

  /// Leer datos del dispositivo conectado
  static Future<String?> readData() async {
    try {
      final result = await _channel.invokeMethod('readData');
      return result as String?;
    } catch (e) {
      _updateStatus('Error leyendo datos: $e');
      return null;
    }
  }

  /// Obtener información detallada del dispositivo
  static Future<Map<String, dynamic>?> getDeviceInfo(Map<String, dynamic> device) async {
    try {
      final result = await _channel.invokeMethod('getDeviceInfo', device);
      return result as Map<String, dynamic>?;
    } catch (e) {
      _updateStatus('Error obteniendo información del dispositivo: $e');
      return null;
    }
  }

  /// Realizar análisis de seguridad del dispositivo
  static Future<Map<String, dynamic>?> analyzeDeviceSecurity(Map<String, dynamic> device) async {
    try {
      _updateStatus('Analizando seguridad del dispositivo...');
      final result = await _channel.invokeMethod('analyzeSecurity', device);
      
      _updateStatus('Análisis de seguridad completado');
      return result as Map<String, dynamic>?;
    } catch (e) {
      _updateStatus('Error en análisis de seguridad: $e');
      return null;
    }
  }

  /// Limpiar recursos del servicio
  static void dispose() {
    _onBluetoothStateChanged = null;
    _onDevicesFound = null;
    _onConnectionStatus = null;
    _discoveredDevices.clear();
    _isScanning = false;
  }

  // Métodos privados
  static Future<void> _checkBluetoothState() async {
    try {
      final result = await _channel.invokeMethod('isBluetoothEnabled');
      _isBluetoothEnabled = result ?? false;
    } catch (e) {
      _isBluetoothEnabled = false;
    }
  }

  static void _updateStatus(String status) {
    _currentStatus = status;
    print('📡 BluetoothService: $status');
  }

  /// Manejar llamadas del MethodChannel
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onBluetoothStateChanged':
        final enabled = call.arguments as bool;
        _isBluetoothEnabled = enabled;
        _onBluetoothStateChanged?.call(enabled);
        break;
        
      case 'onDeviceFound':
        final device = call.arguments as Map<String, dynamic>;
        _discoveredDevices.add(device);
        _onDevicesFound?.call([device]); // Notificar dispositivo individual
        break;
        
      case 'onConnectionStatusChanged':
        final status = call.arguments as String;
        _onConnectionStatus?.call(status);
        break;
        
      default:
        print('❌ Método no reconocido: ${call.method}');
    }
  }

  /// Obtener información de depuración del servicio
  static Map<String, dynamic> getDebugInfo() {
    return {
      'isBluetoothEnabled': _isBluetoothEnabled,
      'isScanning': _isScanning,
      'discoveredDevicesCount': _discoveredDevices.length,
      'currentStatus': _currentStatus,
      'hasCallbacks': {
        'bluetoothState': _onBluetoothStateChanged != null,
        'devicesFound': _onDevicesFound != null,
        'connectionStatus': _onConnectionStatus != null,
      },
    };
  }
}
