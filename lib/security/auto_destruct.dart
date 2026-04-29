import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Sistema de autodestrucción para proteger datos sensibles
/// Implementación real con persistencia y temporizadores nativos
class AutoDestruct {
  static final AutoDestruct _instance = AutoDestruct._internal();
  factory AutoDestruct() => _instance;
  AutoDestruct._internal();

  static const String _prefsKey = 'autodestruct_enabled';
  static const String _prefsTimeKey = 'autodestruct_remaining_ms';
  static const String _prefsDestructTimeKey = 'autodestruct_destruct_time';

  Timer? _countdownTimer;
  Duration? _remainingTime;
  bool _isEnabled = false;
  final StreamController<Duration?> _timeRemainingController =
      StreamController<Duration?>.broadcast();
  final StreamController<void> _destructTriggeredController =
      StreamController<void>.broadcast();

  /// Stream que emite el tiempo restante actualizado cada segundo
  Stream<Duration?> get timeRemainingStream => _timeRemainingController.stream;

  /// Stream que emite un evento cuando la autodestrucción se activa
  Stream<void> get destructTriggeredStream => _destructTriggeredController.stream;

  /// Inicializa el sistema de autodestrucción cargando estado persistente
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_prefsKey) ?? false;

    if (_isEnabled) {
      final savedTime = prefs.getInt(_prefsTimeKey);
      final destructTime = prefs.getInt(_prefsDestructTimeKey);

      if (savedTime != null && destructTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final remaining = destructTime - now;

        if (remaining > 0) {
          _remainingTime = Duration(milliseconds: remaining);
          _startCountdown();
        } else {
          // El tiempo ya expiró
          await _disable();
          _destructTriggeredController.add(null);
        }
      } else {
        await _disable();
      }
    }
  }

  /// Obtener tiempo restante para autodestrucción
  Future<Duration?> getRemainingTime() async {
    if (!_isEnabled) return null;

    final prefs = await SharedPreferences.getInstance();
    final destructTime = prefs.getInt(_prefsDestructTimeKey);

    if (destructTime == null) {
      await _disable();
      return null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = destructTime - now;

    if (remaining <= 0) {
      await _disable();
      _destructTriggeredController.add(null);
      return Duration.zero;
    }

    return Duration(milliseconds: remaining);
  }

  /// Configurar tiempo de autodestrucción
  Future<void> setAutoDestructTime(Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    final destructTime = DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;

    await prefs.setInt(_prefsDestructTimeKey, destructTime);
    await prefs.setInt(_prefsTimeKey, duration.inMilliseconds);

    _remainingTime = duration;
    _timeRemainingController.add(_remainingTime);
  }

  /// Activar/desactivar autodestrucción
  Future<void> setAutoDestructEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
    _isEnabled = enabled;

    if (enabled) {
      _startCountdown();
    } else {
      await _disable();
    }
  }

  /// Verificar si la autodestrucción está activada
  Future<bool> isAutoDestructEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_prefsKey) ?? false;
    return _isEnabled;
  }

  /// Desactivar autodestrucción
  Future<void> disable() async {
    await _disable();
  }

  /// Activar autodestrucción
  Future<void> enable({required Duration duration}) async {
    await setAutoDestructTime(duration);
    await setAutoDestructEnabled(true);
  }

  /// Extender tiempo de autodestrucción
  Future<void> extendTime(Duration extension) async {
    final currentTime = await getRemainingTime();
    if (currentTime != null) {
      final newDuration = currentTime + extension;
      await setAutoDestructTime(newDuration);
    }
  }

  /// Forzar activación inmediata de autodestrucción
  Future<void> triggerDestructNow() async {
    await _disable();
    _destructTriggeredController.add(null);
    // Aquí se implementaría la lógica real de borrado seguro
    // Por ejemplo: borrado recursivo de directorios sensibles
  }

  // ========== Métodos privados ==========

  Future<void> _disable() async {
    _isEnabled = false;
    _remainingTime = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_prefsTimeKey);
    await prefs.remove(_prefsDestructTimeKey);

    _timeRemainingController.add(null);
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = await getRemainingTime();

      if (remaining == null || remaining <= Duration.zero) {
        timer.cancel();
        await _disable();
        _destructTriggeredController.add(null);
      } else {
        _remainingTime = remaining;
        _timeRemainingController.add(remaining);
      }
    });
  }

  /// Limpia todos los recursos
  void dispose() {
    _countdownTimer?.cancel();
    _timeRemainingController.close();
    _destructTriggeredController.close();
  }
}

