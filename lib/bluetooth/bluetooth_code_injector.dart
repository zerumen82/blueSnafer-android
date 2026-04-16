import 'dart:async';
import 'package:flutter/services.dart';
import '../utils/advanced_logger.dart';

/// Sistema de inyección de código real a través de conexiones Bluetooth
class BluetoothCodeInjector {
  static final BluetoothCodeInjector _instance =
      BluetoothCodeInjector._internal();
  factory BluetoothCodeInjector() => _instance;
  BluetoothCodeInjector._internal();

  final _logger = AdvancedLogger('BluetoothCodeInjector');

  /// Estado de la conexión Bluetooth
  BluetoothConnection? _connection;
  bool _isConnected = false;
  String? _connectedDeviceAddress;

  /// Inyectar código directamente en la conexión Bluetooth
  Future<InjectionResult> injectCode(
    String deviceAddress,
    String code,
    InjectionType type, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      _logger.logInfo('Iniciando inyección de código', {
        'device': deviceAddress,
        'type': type.name,
        'code_length': code.length,
      });

      // 1. Establecer conexión Bluetooth
      final connected = await _ensureConnection(deviceAddress);
      if (!connected) {
        return InjectionResult(
          success: false,
          message: 'No se pudo establecer conexión Bluetooth',
          data: {'connection_failed': true},
        );
      }

      // 2. Preparar código para inyección
      final preparedCode =
          await _prepareCodeForInjection(code, type, parameters);

      // 3. Inyectar código
      final result = await _performCodeInjection(preparedCode, type);

      _logger.logInfo('Inyección de código completada', {
        'success': result.success,
        'bytes_injected': preparedCode.length,
      });

      return result;
    } catch (e) {
      _logger.logError(
          'Error en inyección de código',
          {
            'device': deviceAddress,
            'error': e.toString(),
          },
          e);

      return InjectionResult(
        success: false,
        message: 'Error durante inyección: ${e.toString()}',
        data: {'error': e.toString()},
      );
    }
  }

  /// Asegurar que hay una conexión Bluetooth activa
  Future<bool> _ensureConnection(String deviceAddress) async {
    try {
      if (_isConnected && _connectedDeviceAddress == deviceAddress) {
        return true; // Ya conectado
      }

      // Cerrar conexión anterior si existe
      await _closeConnection();

      // Crear nueva conexión
      _connection = await BluetoothConnection.toAddress(deviceAddress);
      _connection!.input!.listen(_onDataReceived);

      _isConnected = true;
      _connectedDeviceAddress = deviceAddress;

      _logger
          .logInfo('Conexión Bluetooth establecida', {'device': deviceAddress});

      return true;
    } catch (e) {
      _logger.logError('Error estableciendo conexión Bluetooth', {
        'device': deviceAddress,
        'error': e.toString(),
      });

      return false;
    }
  }

  /// Preparar código para inyección según el tipo
  Future<Uint8List> _prepareCodeForInjection(
    String code,
    InjectionType type,
    Map<String, dynamic>? parameters,
  ) async {
    switch (type) {
      case InjectionType.shellCommand:
        return _prepareShellCommand(code, parameters);
      case InjectionType.javaCode:
        return _prepareJavaCode(code, parameters);
      case InjectionType.binaryPayload:
        return _prepareBinaryPayload(code, parameters);
      case InjectionType.scriptExecution:
        return _prepareScriptExecution(code, parameters);
    }
  }

  /// Preparar comando de shell para inyección
  Future<Uint8List> _prepareShellCommand(
    String command,
    Map<String, dynamic>? parameters,
  ) async {
    // Crear payload AT+COMMAND para comandos de terminal
    final atCommand = 'AT+${command.replaceAll(' ', '+')}\r\n';

    // Agregar parámetros si existen
    if (parameters != null && parameters.isNotEmpty) {
      final params =
          parameters.entries.map((e) => '${e.key}=${e.value}').join(',');
      return Uint8List.fromList('$atCommand$params\r\n'.codeUnits);
    }

    return Uint8List.fromList(atCommand.codeUnits);
  }

  /// Preparar código Java para inyección
  Future<Uint8List> _prepareJavaCode(
    String javaCode,
    Map<String, dynamic>? parameters,
  ) async {
    // Crear clase Java con el código proporcionado
    final className = 'InjectedCode_${DateTime.now().millisecondsSinceEpoch}';

    final fullJavaCode = '''
public class $className {
    public static void main(String[] args) {
        $javaCode
    }
}
''';

    return Uint8List.fromList(fullJavaCode.codeUnits);
  }

  /// Preparar payload binario
  Future<Uint8List> _prepareBinaryPayload(
    String code,
    Map<String, dynamic>? parameters,
  ) async {
    // Convertir código a bytes
    final codeBytes = Uint8List.fromList(code.codeUnits);

    // Agregar header de protocolo si es necesario
    if (parameters?['addProtocolHeader'] == true) {
      final header = _createProtocolHeader(parameters, codeBytes.length);
      final combined = Uint8List(header.length + codeBytes.length);
      combined.setAll(0, header);
      combined.setAll(header.length, codeBytes);
      return combined;
    }

    return codeBytes;
  }

  /// Preparar ejecución de script
  Future<Uint8List> _prepareScriptExecution(
    String scriptPath,
    Map<String, dynamic>? parameters,
  ) async {
    // Crear comando para ejecutar script
    final command = 'sh $scriptPath';

    if (parameters != null) {
      final args =
          parameters.entries.map((e) => '${e.key}="${e.value}"').join(' ');
      return Uint8List.fromList('$command $args\n'.codeUnits);
    }

    return Uint8List.fromList('$command\n'.codeUnits);
  }

  /// Crear header de protocolo personalizado
  Uint8List _createProtocolHeader(
      Map<String, dynamic>? parameters, int dataLength) {
    final magic = parameters?['magic'] ?? 'INJ';
    final version = parameters?['version'] ?? 1;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Header: MAGIC(3) + VERSION(1) + TIMESTAMP(8) + LENGTH(4)
    final header = Uint8List(16);
    final magicBytes = magic.codeUnits;

    for (var i = 0; i < 3 && i < magicBytes.length; i++) {
      header[i] = magicBytes[i];
    }

    header[3] = version;
    header.setRange(4, 12, _int64ToBytes(timestamp));
    header.setRange(
        12, 16, _int32ToBytes(dataLength)); // Longitud real de datos

    return header;
  }

  /// Convertir int64 a bytes
  Uint8List _int64ToBytes(int value) {
    final bytes = Uint8List(8);
    for (var i = 0; i < 8; i++) {
      bytes[i] = (value >> (i * 8)) & 0xFF;
    }
    return bytes;
  }

  /// Convertir int32 a bytes
  Uint8List _int32ToBytes(int value) {
    final bytes = Uint8List(4);
    for (var i = 0; i < 4; i++) {
      bytes[i] = (value >> (i * 8)) & 0xFF;
    }
    return bytes;
  }

  /// Realizar la inyección de código
  Future<InjectionResult> _performCodeInjection(
    Uint8List code,
    InjectionType type,
  ) async {
    try {
      if (_connection == null || !_isConnected) {
        return InjectionResult(
          success: false,
          message: 'No hay conexión Bluetooth activa',
          data: {'connection_lost': true},
        );
      }

      // Enviar código a través de la conexión
      _connection!.output.add(code);
      await _waitForOutput();

      // Esperar respuesta o confirmación
      final response = await _waitForResponse();

      return InjectionResult(
        success: response != null && response.contains('SUCCESS'),
        message: response?.contains('SUCCESS') == true
            ? 'Código inyectado exitosamente'
            : 'Error en inyección de código',
        data: {
          'bytes_sent': code.length,
          'response': response,
          'injection_type': type.name,
        },
      );
    } catch (e) {
      return InjectionResult(
        success: false,
        message: 'Error durante inyección: ${e.toString()}',
        data: {'error': e.toString()},
      );
    }
  }

  /// Esperar que el output se complete
  Future<void> _waitForOutput() async {
    // Simular delay para que el output se complete
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Esperar respuesta de la inyección
  Future<String?> _waitForResponse(
      {Duration timeout = const Duration(seconds: 10)}) async {
    final completer = Completer<String?>();

    Timer? responseTimer;

    // Configurar timeout
    responseTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    // Escuchar datos recibidos
    StreamSubscription? subscription;
    subscription = _connection?.input?.listen((data) {
      if (!completer.isCompleted) {
        final response = String.fromCharCodes(data);
        completer.complete(response);
        subscription?.cancel();
        responseTimer?.cancel();
      }
    });

    return completer.future;
  }

  /// Manejar datos recibidos
  void _onDataReceived(Uint8List data) {
    _logger.logDebug('Datos recibidos en conexión Bluetooth', {
      'data_length': data.length,
      'data': String.fromCharCodes(data),
    });
  }

  /// Cerrar conexión Bluetooth
  Future<void> _closeConnection() async {
    try {
      if (_connection != null) {
        await _connection!.close();
        _connection = null;
      }
      _isConnected = false;
      _connectedDeviceAddress = null;

      _logger.logInfo('Conexión Bluetooth cerrada');
    } catch (e) {
      _logger.logWarning(
          'Error cerrando conexión Bluetooth', {'error': e.toString()});
    }
  }

  /// Obtener estado de conexión
  bool get isConnected => _isConnected;
  String? get connectedDevice => _connectedDeviceAddress;

  /// Cerrar conexión manualmente
  Future<void> disconnect() async {
    await _closeConnection();
  }
}

/// Tipos de inyección de código
enum InjectionType {
  shellCommand, // Comandos de terminal
  javaCode, // Código Java
  binaryPayload, // Payload binario
  scriptExecution, // Ejecución de scripts
}

/// Resultado de una inyección de código
class InjectionResult {
  final bool success;
  final String? message;
  final Map<String, dynamic> data;

  const InjectionResult({
    required this.success,
    required this.message,
    required this.data,
  });

  /// Factory constructor para compatibilidad con API simple
  factory InjectionResult.simple({
    required bool success,
    required String message,
    required Map<String, dynamic> data,
  }) {
    return InjectionResult(
      success: success,
      message: message,
      data: data,
    );
  }
}

/// Clase BluetoothDevice simplificada
class BluetoothDevice {
  final String address;

  BluetoothDevice(this.address);
}

/// Clase BluetoothConnection real y robusta
class BluetoothConnection {
  final Stream<Uint8List>? input;
  final StreamSink<Uint8List> output;
  final MethodChannel _channel;
  final StreamController<Uint8List> _inputController;
  final StreamController<Uint8List> _outputController;
  final String _address;
  bool _isConnected = false;
  bool _isClosed = false;

  BluetoothConnection._(
    this._address,
    this._channel,
    this._inputController,
    this._outputController,
  )   : input = _inputController.stream,
        output = _outputController.sink;

  static Future<BluetoothConnection> toAddress(String address) async {
    try {
      // Usar MethodChannel para conexión Bluetooth real
      final channel = MethodChannel('com.bluesnafer_pro/bluetooth');

      // Crear controllers ANTES de conectar
      final inputController = StreamController<Uint8List>();
      final outputController = StreamController<Uint8List>();

      // Configurar handlers para datos recibidos
      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onDataReceived':
            final data = call.arguments['data'] as List<int>?;
            if (data != null && !inputController.isClosed) {
              inputController.add(Uint8List.fromList(data));
            }
            break;

          case 'onConnectionClosed':
            if (!inputController.isClosed) {
              inputController.close();
            }
            if (!outputController.isClosed) {
              await outputController.close();
            }
            break;

          case 'onConnectionError':
            final error =
                call.arguments['error'] as String? ?? 'Error desconocido';
            if (!inputController.isClosed) {
              inputController.addError(Exception(error));
            }
            break;

          case 'onDeviceReady':
            // Dispositivo listo para comunicación
            break;
        }
      });

      // Establecer conexión a través del código nativo
      final result = await channel.invokeMethod('connectToDevice', {
        'address': address,
        'timeout': 10000, // 10 segundos timeout
        'enableNotifications': true,
        'autoReconnect': false,
      });

      if (result['success'] == true) {
        final connection = BluetoothConnection._(
          address,
          channel,
          inputController,
          outputController,
        );
        connection._isConnected = true;

        // Configurar envío de datos al nativo
        outputController.stream.listen(
          (data) async {
            if (connection._isConnected && !connection._isClosed) {
              try {
                await channel.invokeMethod('sendData', {
                  'address': address,
                  'data': data.toList(),
                });
              } catch (e) {
                // Error enviando datos
                if (!inputController.isClosed) {
                  inputController.addError(e);
                }
              }
            }
          },
          onError: (error) {
            if (!inputController.isClosed) {
              inputController.addError(error);
            }
          },
          onDone: () {
            // Stream cerrado
          },
        );

        return connection;
      } else {
        // Limpiar controllers si la conexión falla
        await inputController.close();
        await outputController.close();

        throw Exception(
            'Error conectando al dispositivo: ${result['error'] ?? 'Error desconocido'}');
      }
    } catch (e) {
      throw Exception('Fallo en conexión Bluetooth: $e');
    }
  }

  /// Verificar si la conexión está activa
  bool get isConnected => _isConnected && !_isClosed;

  /// Obtener dirección del dispositivo conectado
  String get address => _address;

  /// Cerrar conexión de forma segura
  Future<void> close() async {
    if (_isClosed) return;

    _isClosed = true;
    _isConnected = false;

    try {
      // Cerrar controllers
      if (!_inputController.isClosed) {
        await _inputController.close();
      }
      if (!_outputController.isClosed) {
        await _outputController.close();
      }

      // Desconectar del dispositivo nativo
      await _channel.invokeMethod('disconnect', {
        'address': _address,
      });
    } catch (e) {
      // Ignorar errores en cierre
      print('[BluetoothConnection] Error en cierre: $e');
    }
  }

  /// Enviar datos de forma segura
  Future<void> send(Uint8List data) async {
    if (!isConnected) {
      throw Exception('Conexión no establecida o cerrada');
    }

    try {
      output.add(data);
    } catch (e) {
      throw Exception('Error enviando datos: $e');
    }
  }

  /// Esperar a que el dispositivo esté listo
  Future<void> waitForReady(
      {Duration timeout = const Duration(seconds: 5)}) async {
    final completer = Completer<void>();
    Timer? timeoutTimer;

    // Escuchar evento de dispositivo listo
    Future<dynamic> handleMethodCall(MethodCall call) async {
      if (call.method == 'onDeviceReady') {
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
      return null;
    }

    _channel.setMethodCallHandler(handleMethodCall);

    // Configurar timeout
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
            TimeoutException('Timeout esperando dispositivo listo', timeout));
      }
    });

    return completer.future;
  }
}
