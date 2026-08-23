// Provider para state management de Bluetooth — delega a BluetoothScannerService (canal nativo real)
import 'package:flutter/foundation.dart';
import '../services/bluetooth_scanner_service.dart';

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
      name: map['name']?.toString() ?? map['deviceName']?.toString() ?? 'Unknown',
      address: map['address']?.toString() ?? map['deviceAddress']?.toString() ?? '',
      rssi: (map['rssi'] as num?)?.toInt() ?? 0,
      deviceType: map['deviceType']?.toString() ?? map['type']?.toString(),
      isConnected: map['isConnected'] == true,
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
    bool clearConnectedDevice = false,
    bool clearError = false,
  }) {
    return BluetoothProviderState(
      isBluetoothEnabled: isBluetoothEnabled ?? this.isBluetoothEnabled,
      isScanning: isScanning ?? this.isScanning,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectedDevice: clearConnectedDevice ? null : (connectedDevice ?? this.connectedDevice),
      currentStatus: currentStatus ?? this.currentStatus,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<BluetoothDevice> get connectedDevices {
    return discoveredDevices.where((d) => d.isConnected).toList();
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
        'isLoading: $isLoading}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BluetoothProviderState &&
        other.isBluetoothEnabled == isBluetoothEnabled &&
        other.isScanning == isScanning &&
        other.discoveredDevices.length == discoveredDevices.length &&
        other.connectedDevice == connectedDevice &&
        other.currentStatus == currentStatus &&
        other.error == error &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode => Object.hash(
        isBluetoothEnabled,
        isScanning,
        discoveredDevices.length,
        connectedDevice,
        currentStatus,
        error,
        isLoading,
      );
}

class BluetoothProvider with ChangeNotifier {
  BluetoothProviderState _state = const BluetoothProviderState();
  bool _initialized = false;

  bool get isBluetoothEnabled => _state.isBluetoothEnabled;
  bool get isScanning => _state.isScanning;
  List<BluetoothDevice> get discoveredDevices => _state.discoveredDevices;
  BluetoothDevice? get connectedDevice => _state.connectedDevice;
  String get currentStatus => _state.currentStatus;
  String? get error => _state.error;
  bool get isLoading => _state.isLoading;
  BluetoothProviderState get state => _state;

  void _updateState(BluetoothProviderState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  List<BluetoothDevice> _mapDevices(List<dynamic> raw) {
    return raw
        .whereType<Map>()
        .map((d) => BluetoothDevice.fromMap(Map<String, dynamic>.from(d)))
        .where((d) => d.address.isNotEmpty)
        .toList();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _updateState(_state.copyWith(isLoading: true, clearError: true));

      await BluetoothScannerService.initialize();

      BluetoothScannerService.setBluetoothStateCallback((enabled) {
        _updateState(_state.copyWith(
          isBluetoothEnabled: enabled,
          currentStatus: enabled ? 'Bluetooth activo' : 'Bluetooth desactivado',
        ));
      });

      BluetoothScannerService.setDevicesFoundCallback((devices) {
        final mapped = _mapDevices(devices);
        _updateState(_state.copyWith(
          discoveredDevices: mapped,
          isScanning: BluetoothScannerService.isScanning,
          currentStatus: BluetoothScannerService.currentStatus,
        ));
      });

      BluetoothScannerService.setConnectionStatusCallback((status) {
        if (status == 'disconnected') {
          _updateState(_state.copyWith(
            clearConnectedDevice: true,
            currentStatus: 'Dispositivo desconectado',
          ));
        }
      });

      final enabled = await BluetoothScannerService.isBluetoothEnabled;
      _updateState(_state.copyWith(
        isLoading: false,
        isBluetoothEnabled: enabled,
        currentStatus: 'Provider conectado al canal nativo Bluetooth',
      ));
      _initialized = true;
    } catch (e) {
      _updateState(_state.copyWith(
        isLoading: false,
        error: 'Error inicializando Bluetooth: $e',
        currentStatus: 'Error: $e',
      ));
    }
  }

  Future<bool> enableBluetooth() async {
    try {
      _updateState(_state.copyWith(isLoading: true, clearError: true));
      final ok = await BluetoothScannerService.enableBluetooth();
      _updateState(_state.copyWith(
        isLoading: false,
        isBluetoothEnabled: ok,
        currentStatus: ok ? 'Bluetooth activado' : 'No se pudo activar Bluetooth',
      ));
      return ok;
    } catch (e) {
      _updateState(_state.copyWith(
        isLoading: false,
        error: 'Error habilitando Bluetooth: $e',
      ));
      return false;
    }
  }

  Future<List<BluetoothDevice>> scanDevices({
    int timeoutSeconds = 10,
    bool continuous = false,
  }) async {
    try {
      if (!_initialized) await initialize();

      if (_state.isScanning) {
        _updateState(_state.copyWith(currentStatus: 'Escaneo ya en progreso...'));
        return _state.discoveredDevices;
      }

      if (!_state.isBluetoothEnabled) {
        _updateState(_state.copyWith(error: 'Bluetooth no está activado'));
        return [];
      }

      _updateState(_state.copyWith(
        isScanning: true,
        clearError: true,
        currentStatus: '🔍 Buscando dispositivos...',
      ));

      final devices = await BluetoothScannerService.scanDevices(
        timeoutSeconds: timeoutSeconds,
        continuous: continuous,
      );
      final mapped = _mapDevices(devices);

      _updateState(_state.copyWith(
        isScanning: false,
        discoveredDevices: mapped,
        currentStatus: mapped.isEmpty
            ? 'No se encontraron dispositivos'
            : '✅ ${mapped.length} dispositivo${mapped.length != 1 ? 's' : ''} encontrado${mapped.length != 1 ? 's' : ''}',
      ));

      return mapped;
    } catch (e) {
      _updateState(_state.copyWith(
        isScanning: false,
        error: 'Error durante el escaneo: $e',
      ));
      return [];
    }
  }

  Future<void> stopScanning() async {
    try {
      await BluetoothScannerService.stopScanning();
      _updateState(_state.copyWith(
        isScanning: false,
        currentStatus: 'Escaneo detenido',
      ));
    } catch (e) {
      _updateState(_state.copyWith(error: 'Error deteniendo escaneo: $e'));
    }
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _updateState(_state.copyWith(
        isLoading: true,
        clearError: true,
        currentStatus: 'Conectando a ${device.name}...',
      ));

      final ok = await BluetoothScannerService.connectToDevice(device.toMap());
      _updateState(_state.copyWith(
        isLoading: false,
        connectedDevice: ok ? device.copyWith(isConnected: true) : null,
        currentStatus: ok ? 'Conectado a ${device.name}' : 'Error conectando a ${device.name}',
        error: ok ? null : 'Conexión fallida',
      ));
      return ok;
    } catch (e) {
      _updateState(_state.copyWith(
        isLoading: false,
        error: 'Error conectando: $e',
      ));
      return false;
    }
  }

  Future<void> disconnectDevice() async {
    try {
      await BluetoothScannerService.disconnectDevice();
      _updateState(_state.copyWith(
        clearConnectedDevice: true,
        currentStatus: 'Dispositivo desconectado',
      ));
    } catch (e) {
      _updateState(_state.copyWith(error: 'Error desconectando: $e'));
    }
  }

  void clearDiscoveredDevices() {
    _updateState(_state.copyWith(
      discoveredDevices: [],
      currentStatus: 'Lista de dispositivos limpiada',
    ));
  }

  void clearError() {
    _updateState(_state.copyWith(clearError: true));
  }

  Future<void> refreshState() async {
    try {
      final enabled = await BluetoothScannerService.isBluetoothEnabled;
      final devices = _mapDevices(BluetoothScannerService.discoveredDevices);
      _updateState(_state.copyWith(
        isBluetoothEnabled: enabled,
        isScanning: BluetoothScannerService.isScanning,
        discoveredDevices: devices,
        currentStatus: BluetoothScannerService.currentStatus,
      ));
    } catch (e) {
      _updateState(_state.copyWith(error: 'Error refrescando estado: $e'));
    }
  }

  Map<String, dynamic> getDebugInfo() {
    return {
      'state': _state.toString(),
      'discoveredDevicesCount': _state.discoveredDevices.length,
      'connectedDevicesCount': _state.connectedDevice != null ? 1 : 0,
      'hasError': _state.error != null,
      'isInitialized': _initialized,
      'service': BluetoothScannerService.getDebugInfo(),
    };
  }
}