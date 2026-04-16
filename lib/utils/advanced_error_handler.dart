import 'dart:async';

// Import logging system
import 'advanced_logger.dart';

/// Sistema avanzado de manejo de errores y reintentos
class AdvancedErrorHandler {
  static const int _defaultMaxRetries = 3;
  static const Duration _defaultRetryDelay = Duration(seconds: 1);
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Ejecutar operación con manejo de errores y reintentos
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = _defaultMaxRetries,
    Duration retryDelay = _defaultRetryDelay,
    Duration timeout = _defaultTimeout,
    bool Function(Exception)? shouldRetry,
    String operationName = 'operation',
  }) async {
    int attempt = 0;
    Exception? lastException;

    while (attempt <= maxRetries) {
      try {
        final result = await operation().timeout(timeout);

        if (attempt > 0) {
          AdvancedLogger.staticLogger.logInfo(
            'Operation succeeded after $attempt retries',
            {'operation': operationName, 'attempts': attempt + 1}
          );
        }

        return result;
      } catch (e) {
        lastException = e as Exception;
        attempt++;

        AdvancedLogger.staticLogger.logWarning(
          'Operation attempt $attempt failed',
          {
            'operation': operationName,
            'attempt': attempt,
            'max_retries': maxRetries,
            'error': e.toString()
          }
        );

        // Verificar si deberíamos reintentar
        if (attempt <= maxRetries &&
            (shouldRetry == null || shouldRetry(lastException))) {
          if (attempt < maxRetries) {
            await Future.delayed(retryDelay * attempt); // Backoff exponencial
          }
          continue;
        }

        break;
      }
    }

    // Si llegamos aquí, todas las tentativas fallaron
    AdvancedLogger.staticLogger.logError(
      'Operation failed after $maxRetries attempts',
      {
        'operation': operationName,
        'total_attempts': attempt,
        'final_error': lastException.toString()
      },
      lastException
    );

    throw lastException!;
  }

  /// Ejecutar operación con timeout y manejo de errores
  static Future<T> executeWithTimeout<T>(
    Future<T> Function() operation, {
    Duration timeout = _defaultTimeout,
    String operationName = 'operation',
  }) async {
    try {
      return await operation().timeout(timeout);
    } catch (e) {
      if (e is TimeoutException) {
        AdvancedLogger.staticLogger.logError(
          'Operation timed out',
          {
            'operation': operationName,
            'timeout_seconds': timeout.inSeconds
          }
        );
      }
      rethrow;
    }
  }

  /// Manejar errores de conexión Bluetooth
  static Future<T> handleBluetoothError<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    String operationName = 'bluetooth_operation',
  }) async {
    return executeWithRetry(
      operation,
      maxRetries: maxRetries,
      shouldRetry: (exception) {
        // Reintentar en errores de conexión, timeout, o problemas de red
        final errorString = exception.toString().toLowerCase();
        return errorString.contains('connection') ||
            errorString.contains('timeout') ||
            errorString.contains('network') ||
            errorString.contains('socket');
      },
      operationName: operationName,
    );
  }

  /// Manejar errores de ejecución de exploits
  static Future<T> handleExploitError<T>(
    Future<T> Function() operation, {
    int maxRetries = 2,
    String operationName = 'exploit_operation',
  }) async {
    return executeWithRetry(
      operation,
      maxRetries: maxRetries,
      shouldRetry: (exception) {
        // Reintentar en errores temporales, pero no en errores de lógica
        final errorString = exception.toString().toLowerCase();
        return !errorString.contains('not vulnerable') &&
            !errorString.contains('invalid exploit') &&
            !errorString.contains('authentication required');
      },
      operationName: operationName,
    );
  }

  /// Crear wrapper de error seguro para operaciones críticas
  static Future<T?> safeExecute<T>(
    Future<T> Function() operation, {
    T? fallbackValue,
    String operationName = 'safe_operation',
  }) async {
    try {
      return await operation();
    } catch (e) {
      AdvancedLogger.staticLogger.logWarning(
        'Safe operation failed, using fallback',
        {
          'operation': operationName,
          'error': e.toString(),
          'fallback_provided': fallbackValue != null
        }
      );

      if (fallbackValue != null) {
        return fallbackValue;
      }

      return null;
    }
  }

  /// Ejecutar operación con circuito breaker pattern
  static Future<T> executeWithCircuitBreaker<T>(
    Future<T> Function() operation, {
    String circuitName = 'default',
    Duration timeout = _defaultTimeout,
    int failureThreshold = 5,
    Duration resetTimeout = const Duration(minutes: 1),
  }) async {
    return _getCircuitBreaker(circuitName).execute(operation, timeout: timeout);
  }

  /// Obtener instancia de circuit breaker
  static CircuitBreaker _getCircuitBreaker(String name) {
    _circuitBreakers.putIfAbsent(name, () => CircuitBreaker(name));
    return _circuitBreakers[name]!;
  }

  static final Map<String, CircuitBreaker> _circuitBreakers = {};
}

/// Circuit Breaker para prevenir llamadas repetidas a servicios fallidos
class CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration resetTimeout;

  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;

  CircuitBreaker(this.name,
      {this.failureThreshold = 5,
      this.resetTimeout = const Duration(minutes: 1)});

  /// Ejecutar operación con circuit breaker
  Future<T> execute<T>(Future<T> Function() operation,
      {Duration timeout = const Duration(seconds: 30)}) async {
    switch (_state) {
      case CircuitBreakerState.closed:
        try {
          final result = await operation().timeout(timeout);
          _reset();
          return result;
        } catch (e) {
          _recordFailure();
          rethrow;
        }

      case CircuitBreakerState.open:
        if (_shouldAttemptReset()) {
          _state = CircuitBreakerState.halfOpen;
          AdvancedLogger.staticLogger.logInfo('Circuit breaker half-open for $name');
        } else {
          throw Exception('Circuit breaker is OPEN for $name');
        }
        break;

      case CircuitBreakerState.halfOpen:
        try {
          final result = await operation().timeout(timeout);
          _reset();
          AdvancedLogger.staticLogger.logInfo('Circuit breaker closed for $name');
          return result;
        } catch (e) {
          _recordFailure();
          _state = CircuitBreakerState.open;
          AdvancedLogger.staticLogger.logWarning('Circuit breaker opened for $name');
          rethrow;
        }
    }

    // Si llegamos aquí en half-open, ejecutar la operación
    if (_state == CircuitBreakerState.halfOpen) {
      try {
        final result = await operation().timeout(timeout);
        _reset();
        return result;
      } catch (e) {
        _recordFailure();
        _state = CircuitBreakerState.open;
        rethrow;
      }
    }

    throw Exception('Circuit breaker in invalid state');
  }

  void _recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= failureThreshold) {
      _state = CircuitBreakerState.open;
      AdvancedLogger.staticLogger.logWarning(
        'Circuit breaker opened for $name',
        {'failures': _failureCount, 'threshold': failureThreshold}
      );
    }
  }

  void _reset() {
    _state = CircuitBreakerState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
  }

  bool _shouldAttemptReset() {
    if (_lastFailureTime == null) return true;

    return DateTime.now().difference(_lastFailureTime!) >= resetTimeout;
  }

  CircuitBreakerState get state => _state;
  int get failureCount => _failureCount;
}

/// Estados del circuit breaker
enum CircuitBreakerState {
  closed, // Operación normal
  open, // Bloqueado debido a fallos
  halfOpen, // Probando si el servicio está disponible
}

/// Extensiones útiles para manejo de errores
extension ErrorHandlingExtensions on Future {
  /// Ejecutar con manejo de errores básico
  Future<T?> safeExecute<T>({T? fallback}) {
    return AdvancedErrorHandler.safeExecute(() => this as Future<T>,
        fallbackValue: fallback);
  }

  /// Ejecutar con reintentos
  Future<T> withRetry<T>({
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
    bool Function(Exception)? shouldRetry,
    String operationName = 'async_operation',
  }) {
    return AdvancedErrorHandler.executeWithRetry(
      () => this as Future<T>,
      maxRetries: maxRetries,
      retryDelay: retryDelay,
      shouldRetry: shouldRetry,
      operationName: operationName,
    );
  }

  /// Ejecutar con timeout
  Future<T> withTimeout<T>(Duration timeout,
      {String operationName = 'timed_operation'}) {
    return AdvancedErrorHandler.executeWithTimeout(
      () => this as Future<T>,
      timeout: timeout,
      operationName: operationName,
    );
  }
}

/// Clase para excepciones personalizadas
class BlueSnaferException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;

  BlueSnaferException(this.message, {this.code = 'UNKNOWN', this.context});

  @override
  String toString() {
    final contextStr =
        context != null ? ' | Context: ${context.toString()}' : '';
    return 'BlueSnaferException[$code]: $message$contextStr';
  }
}

/// Excepciones específicas de Bluetooth
class BluetoothException extends BlueSnaferException {
  BluetoothException(super.message, {super.context})
      : super(code: 'BLUETOOTH_ERROR');
}

/// Excepciones específicas de exploits
class ExploitException extends BlueSnaferException {
  ExploitException(super.message, {super.context})
      : super(code: 'EXPLOIT_ERROR');
}

/// Excepciones específicas de configuración
class ConfigurationException extends BlueSnaferException {
  ConfigurationException(super.message, {super.context})
      : super(code: 'CONFIG_ERROR');
}
