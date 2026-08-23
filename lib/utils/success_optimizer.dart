import 'dart:math' as math;

class SuccessOptimizer {
  static final SuccessOptimizer _instance = SuccessOptimizer._internal();
  factory SuccessOptimizer() => _instance;
  SuccessOptimizer._internal();
  final Map<String, _DeviceLearning> _deviceLearning = {};
  static const int _maxHistoryPerDevice = 50;

  void recordResult({
    required String deviceAddress,
    required String attackType,
    required bool success,
    required int durationMs,
  }) {
    final learning = _deviceLearning.putIfAbsent(deviceAddress, () => _DeviceLearning());
    learning.records.add(_AttackRecord(attackType, success, durationMs, DateTime.now()));
    if (learning.records.length > _maxHistoryPerDevice) {
      learning.records.removeAt(0);
    }
  }

  int calculateBackoffDelay(String deviceAddress, String attackType, int attempt) {
    const baseDelay = 2000;
    final learning = _deviceLearning[deviceAddress];

    if (learning != null) {
      final similarRecords = learning.records.where((r) => r.type == attackType).toList();
      if (similarRecords.isNotEmpty) {
        final avgDuration = similarRecords.map((r) => r.durationMs).reduce((a, b) => a + b) ~/ similarRecords.length;
        final adaptiveDelay = math.max(avgDuration ~/ 2, baseDelay);
        return (adaptiveDelay * math.pow(1.5, attempt - 1)).toInt();
      }
    }

    return baseDelay * (1 << (attempt - 1));
  }

  int estimateTimeout(String deviceAddress, String attackType) {
    const defaults = {
      'sdp_discover': 5000,
      'full_scan': 10000,
      'obex_get': 15000,
      'file_exfil': 15000,
      'pbap_extract': 30000,
      'bypass': 8000,
      'blueborne': 12000,
      'btlejack': 15000,
      'hid': 10000,
      'dos': 15000,
    };

    final baseTimeout = defaults[attackType] ?? 10000;
    final learning = _deviceLearning[deviceAddress];

    if (learning != null) {
      final records = learning.records.where((r) => r.type == attackType && r.success).toList();
      if (records.isNotEmpty) {
        final avgDuration = records.map((r) => r.durationMs).reduce((a, b) => a + b) ~/ records.length;
        return (avgDuration * 1.5).toInt();
      }
    }

    return baseTimeout;
  }

  double predictSuccessProbability(String deviceAddress, String attackType, Map<String, dynamic> deviceProfile) {
    final learning = _deviceLearning[deviceAddress];
    if (learning == null || learning.records.isEmpty) return 0.5;

    final typeRecords = learning.records.where((r) => r.type == attackType).toList();
    if (typeRecords.isEmpty) {
      final successCount = learning.records.where((r) => r.success).length;
      return successCount / learning.records.length;
    }

    final successCount = typeRecords.where((r) => r.success).length;
    return successCount / typeRecords.length;
  }

  List<String> optimizeSequence(String deviceAddress, List<String> attacks, Map<String, dynamic> deviceProfile) {
    if (attacks.length <= 1) return attacks;

    final scored = attacks.map((attack) {
      final prob = predictSuccessProbability(deviceAddress, attack, deviceProfile);
      return _ScoredSequence(attack, prob);
    }).toList();

    scored.sort((a, b) {
      if ((b.prob - a.prob).abs() < 0.1) {
        return _getAttackPriority(a.type).compareTo(_getAttackPriority(b.type));
      }
      return b.prob.compareTo(a.prob);
    });

    return scored.map((s) => s.type).toList();
  }

  int _getAttackPriority(String type) {
    const priorities = {
      'sdp_discover': 1,
      'sdp': 1,
      'full_scan': 1,
      'obex_get': 2,
      'file_exfil': 2,
      'pbap_extract': 2,
      'map_extract': 2,
      'mediastore_enumerate': 2,
      'bypass': 3,
      'mirror_profile': 4,
      'blueborne': 4,
      'btlejack': 4,
      'blur_attack': 4,
      'at_injection': 5,
      'hid': 5,
      'hid_inject': 5,
      'dos': 6,
    };
    return priorities[type] ?? 5;
  }

  Map<String, dynamic> getDeviceStatistics(String deviceAddress) {
    final learning = _deviceLearning[deviceAddress];
    if (learning == null || learning.records.isEmpty) {
      return {'total_attempts': 0, 'success_rate': 0.0, 'attacks': <String, dynamic>{}};
    }

    final byType = <String, List<bool>>{};
    for (final r in learning.records) {
      byType.putIfAbsent(r.type, () => []).add(r.success);
    }

    final attackStats = <String, dynamic>{};
    for (final entry in byType.entries) {
      final successes = entry.value.where((s) => s).length;
      final total = entry.value.length;
      attackStats[entry.key] = {
        'attempts': total,
        'successes': successes,
        'rate': total > 0 ? successes / total : 0.0,
      };
    }

    final totalSuccesses = learning.records.where((r) => r.success).length;
    return {
      'total_attempts': learning.records.length,
      'success_rate': totalSuccesses / learning.records.length,
      'attacks': attackStats,
    };
  }
}

class _AttackRecord {
  final String type;
  final bool success;
  final int durationMs;
  final DateTime timestamp;

  _AttackRecord(this.type, this.success, this.durationMs, this.timestamp);
}

class _DeviceLearning {
  final List<_AttackRecord> records = [];
}

class _ScoredSequence {
  final String type;
  final double prob;
  _ScoredSequence(this.type, this.prob);
}
