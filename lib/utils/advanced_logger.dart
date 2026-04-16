import 'dart:convert';
import 'dart:io';

/// Sistema de logging avanzado para BlueSnafer Pro
class AdvancedLogger {
  static const String _logDir = 'logs';
  static const String _logFile = '$_logDir/bluesnafer.log';
  static const int _maxLogSize = 10 * 1024 * 1024; // 10MB
  static const int _maxLogFiles = 5;
  final String _name;

  static final Map<String, String> _levelPrefixes = {
    'debug': '[DEBUG]',
    'info': '[INFO]',
    'warning': '[WARN]',
    'error': '[ERROR]',
    'critical': '[CRITICAL]',
    'security': '[SECURITY]',
  };

  static bool _initialized = false;

  // Logger estático para contextos donde no hay instancia disponible
  static AdvancedLogger? _staticLogger;

  /// Crea una instancia de AdvancedLogger con un nombre específico
  AdvancedLogger(this._name);

  /// Obtener logger estático (crea uno si no existe)
  static AdvancedLogger get staticLogger {
    _staticLogger ??= AdvancedLogger('Static');
    return _staticLogger!;
  }

  /// Inicializar el sistema de logging
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final directory = Directory(_logDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      _initialized = true;

      // Crear archivo de log si no existe
      final logFile = File(_logFile);
      if (!await logFile.exists()) {
        await logFile.create();
      }

      // Rotar logs si es necesario
      await _rotateLogsIfNeeded();
    } catch (e) {
      print('Error initializing logger: $e');
    }
  }

  /// Registra un mensaje de depuración
  void logDebug(String message, [Map<String, dynamic>? context]) {
    _log('debug', message, context);
  }

  /// Registra un mensaje informativo
  void logInfo(String message, [Map<String, dynamic>? context]) {
    _log('info', message, context);
  }

  /// Registra una advertencia
  void logWarning(String message, [Map<String, dynamic>? context]) {
    _log('warning', message, context);
  }

  /// Registra un error
  void logError(String message, [Map<String, dynamic>? context, dynamic error, StackTrace? stackTrace]) {
    final errorContext = context ?? {};
    if (error != null) {
      errorContext['error'] = error.toString();
    }
    if (stackTrace != null) {
      errorContext['stackTrace'] = stackTrace.toString();
    }
    _log('error', message, errorContext);
  }

  /// Registra un error crítico
  void logCritical(String message, [Map<String, dynamic>? context]) {
    _log('critical', message, context);
  }

  /// Registra un evento de seguridad
  void logSecurity(String message, [Map<String, dynamic>? context]) {
    _log('security', message, context);
  }

  /// Log interno
  Future<void> _log(String level, String message, [Map<String, dynamic>? context]) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final timestamp = DateTime.now().toIso8601String();
      final prefix = _levelPrefixes[level] ?? '[UNKNOWN]';
      final logEntry = {
        'timestamp': timestamp,
        'level': level,
        'logger': _name,
        'message': message,
        if (context != null && context.isNotEmpty) 'context': context,
      };

      // Imprimir en consola
      print('$prefix [$timestamp] $_name - $message');
      if (context != null && context.isNotEmpty) {
        print('Contexto: $context');
      }

      // Escribir en archivo
      final file = File(_logFile);
      final sink = file.openWrite(mode: FileMode.writeOnlyAppend);
      sink.writeln(jsonEncode(logEntry));
      await sink.flush();
      await sink.close();

      // Rotar archivos si es necesario
      await _rotateLogsIfNeeded();
    } catch (e) {
      print('Error al registrar log: $e');
    }
  }

  /// Rotar archivos de log si es necesario
  static Future<void> _rotateLogsIfNeeded() async {
    try {
      final logFile = File(_logFile);
      if (!await logFile.exists()) return;

      final fileSize = await logFile.length();
      if (fileSize < _maxLogSize) return;

      // Renombrar archivos existentes
      for (int i = _maxLogFiles - 1; i >= 1; i--) {
        final oldFile = File('$_logDir/bluesnafer.$i.log');
        final newFile = File('$_logDir/bluesnafer.${i + 1}.log');

        if (await oldFile.exists()) {
          if (await newFile.exists()) {
            await newFile.delete();
          }
          await oldFile.rename(newFile.path);
        }
      }

      // Mover archivo actual a .1.log
      final backupFile = File('$_logDir/bluesnafer.1.log');
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      await logFile.rename(backupFile.path);

      // Crear nuevo archivo de log vacío
      await logFile.create();

    } catch (e) {
      print('Error rotating logs: $e');
    }
  }

  /// Obtener logs recientes
  static Future<List<String>> getRecentLogs({int lines = 100}) async {
    try {
      final logFile = File(_logFile);
      if (!await logFile.exists()) return [];

      final content = await logFile.readAsString();
      final allLines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();

      return allLines.take(lines).toList();
    } catch (e) {
      return ['Error reading logs: $e'];
    }
  }

  /// Limpiar logs antiguos
  static Future<void> clearOldLogs() async {
    try {
      final directory = Directory(_logDir);
      if (!await directory.exists()) return;

      final files = await directory.list().toList();
      final logFiles = files.where((file) =>
        file.path.endsWith('.log') && file.path.contains('bluesnafer'));

      for (final file in logFiles) {
        try {
          await (file as File).delete();
        } catch (e) {
          // Ignorar errores al eliminar archivos individuales
        }
      }

      await initialize(); // Recrear archivo de log
    } catch (e) {
      print('Error clearing logs: $e');
    }
  }
}

/// Extensiones útiles para logging
extension LoggingExtensions on Object {
  void logDebug(String message, [Map<String, dynamic>? context]) {
    AdvancedLogger.staticLogger.logDebug('$runtimeType: $message', context);
  }

  void logInfo(String message, [Map<String, dynamic>? context]) {
    AdvancedLogger.staticLogger.logInfo('$runtimeType: $message', context);
  }

  void logWarning(String message, [Map<String, dynamic>? context]) {
    AdvancedLogger.staticLogger.logWarning('$runtimeType: $message', context);
  }

  void logError(String message, [Map<String, dynamic>? context, Exception? exception]) {
    AdvancedLogger.staticLogger.logError('$runtimeType: $message', context, exception);
  }
}
