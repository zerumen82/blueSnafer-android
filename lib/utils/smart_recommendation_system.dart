import 'dart:math' as math;

class SmartRecommendationSystem {
  static final SmartRecommendationSystem _instance = SmartRecommendationSystem._internal();
  factory SmartRecommendationSystem() => _instance;
  SmartRecommendationSystem._internal();

  static const _attackTypeWeights = {
    'sdp_discover': 0.95,
    'sdp': 0.95,
    'obex_get': 0.80,
    'file_exfil': 0.75,
    'pbap_extract': 0.85,
    'bypass': 0.65,
    'blueborne': 0.50,
    'at_injection': 0.55,
    'mirror_profile': 0.60,
    'full_scan': 0.70,
    'hid': 0.75,
    'hid_inject': 0.70,
    'btlejack': 0.80,
    'dos': 0.40,
    'spoofing': 0.45,
    'opp_push': 0.55,
    'mediastore_enumerate': 0.70,
    'map_extract': 0.75,
    'blur_attack': 0.50,
    'sweyntooth_attack': 0.45,
    'a2dp_record': 0.55,
    'gatt_bulk_read': 0.65,
  };

  RankedRecommendation recommend({
    required String deviceType,
    required Set<String> executedTypes,
    required Map<String, int> successHistory,
    List<String>? excludedTypes,
  }) {
    final deviceTypeLower = deviceType.toLowerCase();
    final scores = <_ScoredAttack>[];
    final excl = excludedTypes ?? <String>[];

    var phaseOffset = 0;
    if (executedTypes.any((t) => t == 'sdp_discover' || t == 'sdp')) phaseOffset = 1;
    if (executedTypes.any((t) => t == 'file_exfil' || t == 'obex_get')) phaseOffset = 2;
    if (executedTypes.any((t) => t == 'bypass')) phaseOffset = 3;
    if (executedTypes.any((t) => t == 'mirror_profile')) phaseOffset = 4;

    for (final entry in _attackTypeWeights.entries) {
      final type = entry.key;
      final baseWeight = entry.value;

      if (executedTypes.contains(type)) continue;
      if (excl.contains(type)) continue;
      if (!_isTypeApplicable(type, deviceTypeLower)) continue;

      var score = baseWeight;

      if (successHistory.containsKey(type)) {
        final successes = successHistory[type]!;
        final historyBonus = math.min(successes / 10.0, 0.2);
        score += historyBonus;
      }

      final phaseBonus = _getPhaseBonus(type, phaseOffset);
      score += phaseBonus;

      scores.add(_ScoredAttack(type, score));
    }

    scores.sort((a, b) => b.score.compareTo(a.score));

    if (scores.isEmpty) {
      return RankedRecommendation(
        type: 'full_scan',
        command: 'scan',
        confidence: 50.0,
        reason: 'Todas las opciones convencionales agotadas. Escaneo completo.',
        alternativeReason: 'Considera cambiar de objetivo o usar modo manual',
      );
    }

    final best = scores.first;
    final bestPhase = _getPhaseForType(best.type);
    final remainingCount = scores.length;

    return RankedRecommendation(
      type: best.type,
      command: _defaultCommand(best.type),
      confidence: (best.score * 100).clamp(5.0, 99.0),
      reason: _buildReason(best.type, best.score, bestPhase, deviceTypeLower),
      alternativeReason: _buildAlternativeReason(best.type, bestPhase, remainingCount),
    );
  }

  bool _isTypeApplicable(String type, String deviceType) {
    if (type == 'a2dp_record') return deviceType.contains('audio') || deviceType.contains('headset') || deviceType.contains('speaker');
    if (type == 'map_extract' || type == 'pbap_extract') return deviceType.contains('phone') || deviceType.contains('tablet') || deviceType.contains('smartphone');
    if (type == 'hid' || type == 'hid_inject') return deviceType.contains('phone') || deviceType.contains('laptop') || deviceType.contains('tablet');
    return true;
  }

  double _getPhaseBonus(String type, num currentPhase) {
    final phase = _getPhaseForType(type);
    if (phase > currentPhase) return 0.05;
    if (phase == currentPhase) return 0.10;
    return -0.05;
  }

  num _getPhaseForType(String type) {
    if (type == 'sdp_discover' || type == 'sdp' || type == 'full_scan') return 1;
    if (type == 'extract_images' || type == 'mediastore_enhanced' || type == 'gatt_image_read' || type == 'opp_server_mode' || type == 'map_image_extract') return 1.5;
    if (type == 'file_exfil' || type == 'obex_get' || type == 'pbap_extract' ||
        type == 'map_extract' || type == 'mediastore_enumerate') return 2;
    if (type == 'bypass' || type == 'spoofing' || type == 'opp_push') return 3;
    if (type == 'mirror_profile' || type == 'blueborne' || type == 'btlejack') return 4;
    if (type == 'at_injection' || type == 'hid' || type == 'hid_inject') return 5;
    if (type == 'dos') return 6;
    return 1;
  }

  String _buildReason(String type, double score, num phase, String deviceType) {
    final pct = (score * 100).toStringAsFixed(0);
    final phaseLabels = {
      1: 'Reconocimiento',
      1.5: 'Extracción de imágenes',
      2: 'Extracción de datos',
      3: 'Bypass de autenticación',
      4: 'Ataques BLE/avanzados',
      5: 'Inyección',
      6: 'Denegación de servicio',
    };
    final phaseLabel = phaseLabels[phase] ?? 'General';
    return 'FASE $phase ($phaseLabel) — $type (confianza $pct%). Recomendado para $deviceType.';
  }

  String _buildAlternativeReason(String type, num phase, int remaining) {
    if (remaining > 1) return '$remaining alternativas disponibles si esta falla';
    if (phase == 6) return 'Última opción. Considera cambiar de objetivo.';
    return 'Después: continuar con siguiente fase de ataque';
  }

  String? _defaultCommand(String type) {
    const commands = {
      'sdp_discover': 'scan',
      'full_scan': 'scan',
      'pbap_extract': 'all',
      'bypass': 'quick_connect',
      'btlejack': 'sniff',
      'dos': 'gatt_flood',
    };
    return commands[type];
  }

  List<String> rankAll(Map<String, double> scores) {
    final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }
}

class _ScoredAttack {
  final String type;
  final double score;
  _ScoredAttack(this.type, this.score);
}

class RankedRecommendation {
  final String type;
  final String? command;
  final double confidence;
  final String reason;
  final String alternativeReason;

  RankedRecommendation({
    required this.type,
    this.command,
    required this.confidence,
    required this.reason,
    this.alternativeReason = '',
  });
}
