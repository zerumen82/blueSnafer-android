// Provider para state management de Bluetooth - Refactorización de arquitectura
import 'package:flutter/foundation.dart';

/// Modelo de estado para dispositivos Bluetooth
class BluetoothDevice {
  final String name;
  final String address;
  final int rssi;
  final String? deviceType;
  final bool isConnected;
  final Map<String, dynamic>? additionalData;

  const BluetoothDevice({
    required this.name,
    required this.address,
    required this.rssi,
    this.deviceType,
    this.isConnected = false,
    this.additionalData,
  });

  factory BluetoothDevice.fromMap(Map<String, dynamic> map) {
    return BluetoothDevice(
      name: map['name']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      rssi: map['rssi'] ?? 0,
      deviceType: map['deviceType']?.toString(),
      isConnected: map['isConnected'] ?? false,
      additionalData: map,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'rssi': rssi,
      'deviceType': deviceType,
      'isConnected': isConnected,
      ...?additionalData,
    };
  }

  BluetoothDevice copyWith({
    String? name,
    String? address,
    int? rssi,
    String? deviceType,
    bool? isConnected,
    Map<String, dynamic>? additionalData,
  }) {
    return BluetoothDevice(
      name: name ?? this.name,
      address: address ?? this.address,
      rssi: rssi ?? this.rssi,
      deviceType: deviceType ?? this.deviceType,
      isConnected: isConnected ?? this.isConnected,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  @override
  String toString() {
    return 'BluetoothDevice{name: $name, address: $address, rssi: $rssi, isConnected: $isConnected}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BluetoothDevice &&
        other.name == name &&
        other.address == address;
  }

  @override
  int get hashCode => name.hashCode ^ address.hashCode;
}

/// Estado completo del Provider de Bluetooth
class BluetoothProviderState {
  final bool isBluetoothEnabled;
  final bool isScanning;
  final List<BluetoothDevice> discoveredDevices;
  final BluetoothDevice? connectedDevice;
  final String currentStatus;
  final String? error;
  final bool isLoading;

  const BluetoothProviderState({
    this.isBluetoothEnabled = false,
    this.isScanning = false,
    this.discoveredDevices = const [],
    this.connectedDevice,
    this.currentStatus = 'Listo para comenzar',
    this.error,
    this.isLoading = false,
  });

  BluetoothProviderState copyWith({
    bool? isBluetoothEnabled,
    bool? isScanning,
    List<BluetoothDevice>? discoveredDevices,
    BluetoothDevice? connectedDevice,
    String? currentStatus,
    String? error,
    bool? isLoading,
  }) {
    return BluetoothProviderState(
      isBluetoothEnabled: isBluetoothEnabled ?? this.isBluetoothEnabled,
      isScanning: isScanning ?? this.isScanning,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      currentStatus: currentStatus ?? this.currentStatus,
      error: error ?? this.error,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Obtener dispositivos conectados
  List<BluetoothDevice> get connectedDevices {
    return discoveredDevices.where((device) => device.isConnected).toList();
  }

  /// Verificar si hay dispositivos disponibles
  bool get hasDiscoveredDevices => discoveredDevices.isNotEmpty;

  /// Obtener dispositivo por dirección
  BluetoothDevice? getDeviceByAddress(String address) {
    try {
      return discoveredDevices.firstWhere(
        (device) => device.address == address,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'BluetoothProviderState{'
        'isBluetoothEnabled: $isBluetoothEnabled, '
        'isScanning: $isScanning, '
        'discoveredDevices: ${discoveredDevices.length}, '
        'connectedDevice: $connectedDevice, '
        'currentStatus: $currentStatus, '
        'error: $error, '
        'isLoading: $isLoading'
        '}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BluetoothProviderState &&
        other.isBluetoothEnabled == isBluetoothEnabled &&
        other.isScanning == isScanning &&
        listEquals(other.discoveredDevices, discoveredDevices) &&
        other.connectedDevice == connectedDevice &&
        other.currentStatus == currentStatus &&
        other.error == error &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode {
    return isBluetoothEnabled.hashCode ^
        isScanning.hashCode ^
        discoveredDevices.hashCode ^
        connectedDevice.hashCode ^
        currentStatus.hashCode ^
        error.hashCode ^
        isLoading.hashCode;
  }
}

/// Provider principal para manejo de estado de Bluetooth
class BluetoothProvider with ChangeNotifier {
  BluetoothProviderState _state = const BluetoothProviderState();

  // Getters para acceso rápido al estado
  bool get isBluetoothEnabled => _state.isBluetoothEnabled;
  bool get isScanning => _state.isScanning;
  List<BluetoothDevice> get discoveredDevices => _state.discoveredDevices;
  BluetoothDevice? get connectedDevice => _state.connectedDevice;
  String get currentStatus => _state.currentStatus;
  String? get error => _state.error;
  bool get isLoading => _state.isLoading;

  /// Estado completo (solo lectura)
  BluetoothProviderState get state => _state;

  void _updateState(BluetoothProviderState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  void _updateError(String error) {
    _updateState(_state.copyWith(
      error: error,
      isLoading: false,
      currentStatus: 'Error: $error',
    ));
  }

  void _updateStatus(String status) {
    _updateState(_state.copyWith(
      currentStatus: status,
      error: null,
    ));
  }

  // Métodos principales del Provider

  /// Inicializar el provider y servicio de Bluetooth
  Future<void> initialize() async {
    try {
      _updateState(_state.copyWith(isLoading: true, error: null));

      // Simular inicialización
      _updateState(_state.copyWith(
        isLoading: false,
        currentStatus: 'Provider de Bluetooth inicializado',
      ));
    } catch (e) {
      _updateError('Error inicializando Bluetooth: $e');
    }
  }



  // Métodos de acción

  /// Habilitar Bluetooth
  Future<bool> enableBluetooth() async {
    try {
      _updateState(_state.copyWith(isLoading: true));

      // Simular resultado
      _updateState(_state.copyWith(
        isLoading: false,
        isBluetoothEnabled: true,
        currentStatus: 'Bluetooth activado - ¡Listo para escanear!',
      ));

      return true;
    } catch (e) {
      _updateError('Error habilitando Bluetooth: $e');
      return false;
    }
  }

  /// Escanear dispositivos Bluetooth
  Future<List<BluetoothDevice>> scanDevices({
    int timeoutSeconds = 10,
    bool continuous = false,
  }) async {
    try {
      if (_state.isScanning) {
        _updateStatus('Escaneo ya en progreso...');
        return _state.discoveredDevices;
      }

      if (!_state.isBluetoothEnabled) {
        _updateError('Bluetooth no está activado');
        return [];
      }

      _updateState(_state.copyWith(
        isScanning: true,
        error: null,
        currentStatus: '🔍 Buscando dispositivos...',
      ));

      // Simular resultado
      final devices = <dynamic>[];
      final bluetoothDevices = devices
          .map((device) =>
              BluetoothDevice.fromMap(device as Map<String, dynamic>))
          .toList();

      _updateState(_state.copyWith(
        isScanning: false,
        discoveredDevices: bluetoothDevices,
        currentStatus: bluetoothDevices.isEmpty
            ? 'No se encontraron dispositivos'
            : '✅ ${bluetoothDevices.length} dispositivo${bluetoothDevices.length != 1 ? 's' : ''} encontrado${bluetoothDevices.length != 1 ? 's' : ''}',
      ));

      return bluetoothDevices;
    } catch (e) {
      _updateState(_state.copyWith(
        isScanning: false,
        error: 'Error durante el escaneo: $e',
      ));
      return [];
    }
  }

  /// Detener escaneo
  Future<void> stopScanning() async {
    try {
      _updateState(_state.copyWith(
        isScanning: false,
        currentStatus: 'Escaneo detenido',
      ));
    } catch (e) {
      _updateError('Error deteniendo escaneo: $e');
    }
  }

  /// Conectar a un dispositivo
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _updateState(_state.copyWith(
        isLoading: true,
        currentStatus: 'Conectando a ${device.name}...',
      ));

      // Simular resultado
      _updateState(_state.copyWith(
        isLoading: false,
        connectedDevice: device.copyWith(isConnected: true),
        currentStatus: 'Conectado a ${device.name}',
      ));

      return true;
    } catch (e) {
      _updateError('Error conectando: $e');
      return false;
    }
  }

  /// Desconectar dispositivo
  Future<void> disconnectDevice() async {
    try {
      _updateState(_state.copyWith(
        connectedDevice: null,
        currentStatus: 'Dispositivo desconectado',
      ));
    } catch (e) {
      _updateError('Error desconectando: $e');
    }
  }

  /// Limpiar dispositivos descubiertos
  void clearDiscoveredDevices() {
    _updateState(_state.copyWith(
      discoveredDevices: [],
      currentStatus: 'Lista de dispositivos limpiada',
    ));
  }

  /// Limpiar errores
  void clearError() {
    _updateState(_state.copyWith(error: null));
  }

  /// Refrescar estado desde el servicio
  Future<void> refreshState() async {
    try {
      // Simular resultado
      final enabled = _state.isBluetoothEnabled;
      final scanning = _state.isScanning;
      final devices = _state.discoveredDevices;

      _updateState(_state.copyWith(
        isBluetoothEnabled: enabled,
        isScanning: scanning,
        discoveredDevices: devices,
      ));
    } catch (e) {
      _updateError('Error refrescando estado: $e');
    }
  }

  /// Obtener información de depuración
  Map<String, dynamic> getDebugInfo() {
    return {
      'state': _state.toString(),
      'discoveredDevicesCount': _state.discoveredDevices.length,
      'connectedDevicesCount': _state.connectedDevices.length,
      'hasError': _state.error != null,
      'isInitialized': !_state.isLoading,
    };
  }
}
