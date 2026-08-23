import '../utils/advanced_logger.dart';

/// Motor de estrategia honesto basado en hechos del reconocimiento.
///
/// Reemplaza EnhancedMLEngine, que prometía "+25% de precisión ML" con modelos
/// de ruido. Las recomendaciones se derivan de la superficie de ataque REAL
/// descubierta (servicios SDP/BLE, vulnerabilidades conocidas del fingerprint).
class StrategyEngine {
  static final StrategyEngine _instance = StrategyEngine._internal();
  factory StrategyEngine() => _instance;
  StrategyEngine._internal();

  final List<AttackTrainingData> _history = [];
  final AdvancedLogger _logger = AdvancedLogger('StrategyEngine');

  /// Genera una estrategia determinista según la superficie de ataque real.
  Future<AttackStrategy> predictBestStrategy(
      Map<String, dynamic> deviceProfile) async {
    final recommended = <String>[];
    final services = (deviceProfile['sdpServices'] as List?) ?? const [];
    final bleServices = (deviceProfile['bleServices'] as List?) ?? const [];
    final vulns = (deviceProfile['knownVulnerabilities'] as List?) ?? const [];

    bool hasService(List s, String needle) =>
        s.any((x) => x.toString().toLowerCase().contains(needle));

    if (hasService(services, 'obex')) recommended.add('file_exfil');
    if (hasService(services, 'ftp') || hasService(services, 'file')) {
      recommended.add('file_exfil_dir');
    }
    if (hasService(services, 'pbap')) recommended.add('pbap_extract');
    if (hasService(services, 'map')) recommended.add('map_extract');
    if (hasService(services, 'hid') || hasService(services, 'l2cap')) {
      recommended.add('hid_inject');
    }
    if (hasService(bleServices, 'gatt')) recommended.add('gatt_bulk_read');

    for (final v in vulns) {
      final id = v.toString().toLowerCase();
      if (id.contains('blueborne')) recommended.add('blueborne');
      if (id.contains('hid')) recommended.add('hid_inject');
      if (id.contains('obex') || id.contains('snarf')) recommended.add('file_exfil');
      if (id.contains('pairing') || id.contains('knob')) recommended.add('bypass');
    }

    final unique = recommended.toSet().toList();
    if (unique.isEmpty) unique.add('full_scan');

    final expectedSuccess = (unique.length / 5.0).clamp(0.2, 0.9).toDouble();

    return AttackStrategy(
      recommendedExploits: unique,
      expectedSuccess: expectedSuccess,
      source: 'heuristic',
    );
  }

  /// Registra el resultado real en el histórico (sin claims de ML).
  Future<void> updateModelRealTime(AttackResult result) async {
    _history.add(AttackTrainingData(
      deviceProfile: result.deviceProfile,
      exploitsUsed: result.exploitsUsed,
      success: result.success,
      duration: result.duration,
      timestamp: DateTime.now(),
    ));
    if (_history.length > 1000) {
      _history.removeAt(0);
    }
    _logger.logInfo('Histórico de resultados actualizado',
        {'total': _history.length});
  }

  /// Estadísticas honestas del histórico en memoria.
  Future<MLStatistics> getModelStatistics() async {
    final successes = _history.where((d) => d.success).length;
    return MLStatistics(
      totalSamples: _history.length,
      successRate:
          _history.isEmpty ? 0.0 : successes / _history.length,
    );
  }
}

/// Estrategia recomendada según la superficie de ataque descubierta.
class AttackStrategy {
  final List<String> recommendedExploits;
  final double expectedSuccess;
  final String source;

  AttackStrategy({
    required this.recommendedExploits,
    required this.expectedSuccess,
    required this.source,
  });

  factory AttackStrategy.fallback() => AttackStrategy(
        recommendedExploits: const ['full_scan'],
        expectedSuccess: 0.2,
        source: 'fallback',
      );

  factory AttackStrategy.fromMap(Map<String, dynamic> map) => AttackStrategy(
        recommendedExploits:
            List<String>.from(map['recommendedExploits'] ?? const []),
        expectedSuccess: (map['expectedSuccess'] as num?)?.toDouble() ?? 0.2,
        source: map['source']?.toString() ?? 'unknown',
      );

  Map<String, dynamic> toJson() => {
        'recommendedExploits': recommendedExploits,
        'expectedSuccess': expectedSuccess,
        'source': source,
      };
}

/// Resultado real de un ataque (para el histórico).
class AttackResult {
  final Map<String, dynamic> deviceProfile;
  final List<String> exploitsUsed;
  final bool success;
  final Duration duration;

  AttackResult({
    required this.deviceProfile,
    required this.exploitsUsed,
    required this.success,
    required this.duration,
  });
}

class AttackTrainingData {
  final Map<String, dynamic> deviceProfile;
  final List<String> exploitsUsed;
  final bool success;
  final Duration duration;
  final DateTime timestamp;

  AttackTrainingData({
    required this.deviceProfile,
    required this.exploitsUsed,
    required this.success,
    required this.duration,
    required this.timestamp,
  });
}

/// Estadísticas del histórico (solo datos reales registrados).
class MLStatistics {
  final int totalSamples;
  final double successRate;

  MLStatistics({
    required this.totalSamples,
    required this.successRate,
  });

  Map<String, dynamic> toJson() => {
        'total_samples': totalSamples,
        'success_rate': successRate,
      };
}
