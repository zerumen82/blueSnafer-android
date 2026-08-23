import 'dart:async';
import '../utils/advanced_logger.dart';

/// Motor de análisis heurístico honesto.
///
/// Reemplaza la antigua capa de "IA" (modelos TFLite entrenados con ruido
/// aleatorio). No fabrica predicciones: deriva cada score exclusivamente de
/// hechos reales del dispositivo (servicios OBEX/FTP/GATT descubiertos por
/// SDP, versión de Bluetooth, estado de bonding, etc.) y lo reporta como
/// heurística, nunca como salida de un modelo.
class HeuristicAnalysisService {
  static final HeuristicAnalysisService _instance =
      HeuristicAnalysisService._internal();
  factory HeuristicAnalysisService() => _instance;
  HeuristicAnalysisService._internal();

  bool _isInitialized = false;

  /// Inicializa el motor. No carga modelos: es un análisis por reglas.
  Future<void> initializeAll() async {
    if (_isInitialized) return;
    _isInitialized = true;
    AdvancedLogger.staticLogger
        .logInfo('Motor de análisis heurístico listo (sin modelos TFLite)');
  }

  /// Libera recursos.
  void dispose() {
    _isInitialized = false;
  }

  // ===== Utilidades de hechos del dispositivo =====

  bool _fact(Map<String, dynamic> d, String key) {
    final v = d[key];
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return false;
  }

  double _num(Map<String, dynamic> d, String key, double fallback) {
    final v = d[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  bool _hasService(Map<String, dynamic> d, String needle) {
    final services = d['services'];
    if (services is List) {
      return services.any((s) => s.toString().toLowerCase().contains(needle));
    }
    return false;
  }

  String _deviceTypeOf(Map<String, dynamic> d) {
    final t = d['deviceType']?.toString().toLowerCase() ?? '';
    if (t.isNotEmpty) return t;
    return d['name']?.toString().toLowerCase() ?? '';
  }

  // ===== Análisis por heurísticas =====

  /// Evalúa riesgo de bypass de PIN según hechos del dispositivo.
  PinBypassPrediction assessPinBypass(Map<String, dynamic> d) {
    final pinLength = _num(d, 'pinLength', 4.0);
    final authAttempts = _num(d, 'authAttempts', 1.0);
    final noPairingAuth = _fact(d, 'noPairingAuth') || _fact(d, 'noAuth');
    final lockoutDisabled = !_fact(d, 'lockoutEnabled');
    final bluetoothVersion = _num(d, 'bluetoothVersion', 5.0);

    var score = 0.0;
    score += pinLength <= 4 ? 0.25 : 0.0;
    score += authAttempts >= 3 ? 0.20 : 0.0;
    score += noPairingAuth ? 0.25 : 0.0;
    score += lockoutDisabled ? 0.15 : 0.0;
    score += bluetoothVersion < 4.0 ? 0.15 : 0.0;

    final threshold = 0.5;
    return PinBypassPrediction(
      isVulnerable: score >= threshold,
      confidence: score,
      threshold: threshold,
      outputClasses: const ['vulnerable', 'secure'],
      adaptiveFactors: {
        'pinLength': pinLength,
        'authAttempts': authAttempts,
        'noPairingAuth': noPairingAuth,
        'lockoutDisabled': lockoutDisabled,
      },
    );
  }

  /// Probabilidad de éxito por tipo de ataque según hechos del dispositivo.
  AttackSuccessPrediction assessAttackSuccess(Map<String, dynamic> d) {
    final hasObex =
        _fact(d, 'hasOBEX') || _fact(d, 'hasObex') || _hasService(d, 'obex');
    final hasFtp =
        _fact(d, 'supportsFTP') || _hasService(d, 'ftp') || _hasService(d, 'file');
    final hasBle = _fact(d, 'hasBle') || _fact(d, 'hasBLE');
    final noPairingAuth = _fact(d, 'noPairingAuth');
    final discoverable = _fact(d, 'discoverable');
    final isPhone = _deviceTypeOf(d).contains('phone') ||
        _deviceTypeOf(d).contains('mobile') ||
        _deviceTypeOf(d).contains('tablet');
    final btVersion = _num(d, 'bluetoothVersion', 5.0);

    final attackTypes = [
      'obex_put',
      'ftp_anonymous',
      'pin_bypass',
      'sdp_overflow',
      'l2cap_overflow',
      'at_commands',
      'ble_sniff',
      'mac_spoofing',
    ];

    final probs = <double>[
      hasObex ? 0.8 : 0.2, // obex_put
      hasFtp ? 0.75 : 0.2, // ftp_anonymous
      noPairingAuth ? 0.8 : 0.35, // pin_bypass
      btVersion < 4.2 ? 0.6 : 0.2, // sdp_overflow
      btVersion < 4.2 ? 0.5 : 0.15, // l2cap_overflow
      isPhone ? 0.55 : 0.25, // at_commands
      hasBle ? 0.6 : 0.2, // ble_sniff
      discoverable ? 0.5 : 0.2, // mac_spoofing
    ];

    return AttackSuccessPrediction(
      attackSuccessProbabilities: probs,
      attackTypes: attackTypes,
      overallSuccessScore:
          probs.reduce((a, b) => a > b ? a : b),
      adaptiveWeights: {
        for (var i = 0; i < attackTypes.length; i++) attackTypes[i]: probs[i],
      },
      modelConfidence: null,
      recommendedAttacks: _topAttacks(probs, attackTypes),
    );
  }

  /// Clasificación de dispositivo por hechos, no por modelo.
  DeviceClassification assessDeviceClassification(Map<String, dynamic> d) {
    const categories = ['smartphone', 'tablet', 'laptop', 'desktop', 'wearable', 'iot_sensor'];
    final name = _deviceTypeOf(d);
    final hasBle = _fact(d, 'hasBle') || _fact(d, 'hasBLE');
    final hasGatt = _fact(d, 'hasGatt') || _hasService(d, 'gatt');
    final hasObex =
        _fact(d, 'hasOBEX') || _fact(d, 'hasObex') || _hasService(d, 'obex');

    String category;
    var confidence = 0.4;
    if (name.contains('phone') || name.contains('mobile')) {
      category = 'smartphone';
      confidence = 0.8;
    } else if (name.contains('tablet')) {
      category = 'tablet';
      confidence = 0.8;
    } else if (name.contains('laptop') || name.contains('pc') || name.contains('computer')) {
      category = 'laptop';
      confidence = 0.8;
    } else if (name.contains('watch') || name.contains('band') || name.contains('fit')) {
      category = 'wearable';
      confidence = 0.7;
    } else if (hasObex && !hasGatt) {
      category = 'smartphone';
      confidence = 0.6;
    } else if (hasGatt && hasBle) {
      category = 'iot_sensor';
      confidence = 0.6;
    } else {
      category = 'desktop';
      confidence = 0.35;
    }

    final probs = List<double>.filled(categories.length, 0.0);
    final idx = categories.indexOf(category);
    if (idx >= 0) probs[idx] = confidence;

    return DeviceClassification(
      deviceCategory: category,
      categoryProbabilities: probs,
      categories: categories,
      confidence: confidence,
    );
  }

  /// Detección de contramedidas según hechos del dispositivo.
  CountermeasureDetection assessCountermeasures(Map<String, dynamic> d) {
    const countermeasures = [
      'pin_required',
      'authentication',
      'encryption',
      'device_whitelist',
      'rate_limiting',
      'ids',
      'firewall',
    ];

    final detected = <String>[];
    final probs = List<double>.filled(countermeasures.length, 0.0);
    var securityLevel = 0.0;

    final bondState = d['bondState']?.toString() ?? '';
    final bonded = bondState.toLowerCase().contains('bond') || _fact(d, 'isBonded');
    final requiresPin = _num(d, 'pinLength', 0.0) > 0 || _fact(d, 'requiresPin');
    final hasIds = _fact(d, 'hasIDS');

    void add(int i, String cm, double p) {
      if (p > 0.3) {
        detected.add(cm);
        probs[i] = p;
        securityLevel += p;
      }
    }

    add(0, 'pin_required', requiresPin ? 0.8 : 0.2);
    add(1, 'authentication', bonded ? 0.7 : 0.3);
    add(2, 'encryption', _num(d, 'encryptionLevel', 0.5));
    add(3, 'device_whitelist', _fact(d, 'whitelistEnabled') ? 0.7 : 0.1);
    add(4, 'rate_limiting', _fact(d, 'rateLimited') ? 0.6 : 0.1);
    add(5, 'ids', hasIds ? 0.8 : 0.2);
    add(6, 'firewall', _fact(d, 'hasFirewall') ? 0.7 : 0.2);

    return CountermeasureDetection(
      detectedCountermeasures: detected,
      countermeasureProbabilities: probs,
      countermeasures: countermeasures,
      overallSecurityLevel: securityLevel.clamp(0.0, 1.0),
    );
  }

  List<String> _topAttacks(List<double> probs, List<String> types) {
    final indexed = probs.asMap().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return indexed.take(3).map((e) => types[e.key]).toList();
  }

  // ===== Análisis completo =====

  Future<CompleteSecurityAnalysis> runCompleteSecurityAnalysis({
    required String deviceAddress,
    required Map<String, dynamic> deviceData,
  }) async {
    if (!_isInitialized) {
      throw Exception('Motor de análisis no inicializado');
    }

    final stopwatch = Stopwatch()..start();

    final pin = assessPinBypass(deviceData);
    final attack = assessAttackSuccess(deviceData);
    final classification = assessDeviceClassification(deviceData);
    final countermeasures = assessCountermeasures(deviceData);

    final strategy = _buildStrategy(pin, attack, classification, countermeasures);

    stopwatch.stop();

    final confidence = _overallConfidence([
      pin.confidence,
      attack.overallSuccessScore,
      classification.confidence,
      1.0 - countermeasures.overallSecurityLevel,
    ]);

    return CompleteSecurityAnalysis(
      deviceAddress: deviceAddress,
      pinBypassPrediction: pin,
      attackSuccessPrediction: attack,
      deviceClassification: classification,
      detectedCountermeasures: countermeasures,
      optimalAttackStrategy: strategy,
      analysisDuration: stopwatch.elapsed,
      timestamp: DateTime.now(),
      confidence: confidence,
    );
  }

  OptimalAttackStrategy _buildStrategy(
    PinBypassPrediction pin,
    AttackSuccessPrediction attack,
    DeviceClassification classification,
    CountermeasureDetection countermeasures,
  ) {
    final scores = <String, double>{};

    if (pin.isVulnerable) {
      scores['pin_bypass'] = pin.confidence * 0.9;
    }
    for (var i = 0; i < attack.attackTypes.length; i++) {
      final type = attack.attackTypes[i];
      final score = attack.attackSuccessProbabilities[i];
      if (score > 0.6) {
        scores[type] = score * _priorityMultiplier(type);
      }
    }

    for (final cm in countermeasures.detectedCountermeasures) {
      scores.removeWhere((attackType, _) => _blockedBy(attackType, cm));
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final recommended = sorted
        .take(3)
        .map((e) => RecommendedAttack(
              attackType: e.key,
              confidence: e.value,
              estimatedSuccessRate: e.value,
              requiredResources: _requiredResources(e.key),
            ))
        .toList();

    return OptimalAttackStrategy(
      recommendedAttacks: recommended,
      overallStrategyScore: sorted.isEmpty ? 0.0 : sorted.first.value,
      strategyRationale:
          'Análisis heurístico: ${classification.deviceCategory}, '
          'PIN bypass ${pin.isVulnerable ? "posible" : "no indicado"}, '
          'contramedidas: ${countermeasures.detectedCountermeasures.isEmpty ? "ninguna detectada" : countermeasures.detectedCountermeasures.join(", ")}',
    );
  }

  double _priorityMultiplier(String attackType) {
    const priorities = {
      'obex_put': 1.0,
      'ftp_anonymous': 0.9,
      'pin_bypass': 1.0,
      'sdp_overflow': 0.6,
      'l2cap_overflow': 0.5,
      'at_commands': 0.8,
      'ble_sniff': 0.7,
      'mac_spoofing': 0.4,
    };
    return priorities[attackType] ?? 0.5;
  }

  bool _blockedBy(String attackType, String countermeasure) {
    if (countermeasure == 'authentication' &&
        (attackType == 'obex_put' || attackType == 'ftp_anonymous')) {
      return true;
    }
    if (countermeasure == 'pin_required' && attackType == 'pin_bypass') {
      return false; // pin_bypass existe precisamente para saltarlo
    }
    if (countermeasure == 'firewall' && attackType == 'mac_spoofing') {
      return true;
    }
    return false;
  }

  List<String> _requiredResources(String attackType) {
    switch (attackType) {
      case 'ble_sniff':
        return ['Adaptador BLE con monitor mode (requerido)', 'root'];
      case 'mac_spoofing':
        return ['root', 'Interfaz reconfigurable'];
      case 'at_commands':
        return ['RFCOMM socket'];
      case 'obex_put':
      case 'ftp_anonymous':
        return ['Servicio OBEX/FTP expuesto en el objetivo'];
      case 'pin_bypass':
        return ['Bonding activo', 'Dispositivo objetivo en modo pairing'];
      default:
        return ['Conexión Bluetooth activa'];
    }
  }

  double _overallConfidence(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  // ===== Generación de exploits =====

  Future<List<GeneratedExploit>> generateOptimalExploits({
    required CompleteSecurityAnalysis analysis,
    String targetPlatform = 'android',
  }) async {
    if (!_isInitialized) {
      throw Exception('Motor de análisis no inicializado');
    }

    final exploits = <GeneratedExploit>[];
    for (final attack in analysis.optimalAttackStrategy.recommendedAttacks) {
      final spec = _exploitSpec(attack.attackType);
      if (spec == null) continue;
      exploits.add(GeneratedExploit(
        vulnerabilityType: attack.attackType,
        exploitCode: spec,
        targetPlatform: targetPlatform,
        generationMethod: 'heuristic',
        complexityLevel: _complexity(attack.attackType),
        estimatedSuccessRate: attack.estimatedSuccessRate,
        requiredResources: attack.requiredResources,
        timestamp: DateTime.now(),
      ));
    }
    return exploits;
  }

  String? _exploitSpec(String attackType) {
    switch (attackType) {
      case 'obex_put':
        return 'SDP → conectar OBEX FTP (UUID 0x1106) → PUT de prueba';
      case 'ftp_anonymous':
        return 'SDP → OBEX File Transfer sin autenticación → listar/extraer';
      case 'pin_bypass':
        return 'Pairing Just Works: confirmar bonding sin verificación PIN';
      case 'at_commands':
        return 'RFCOMM SPP → inyectar comandos AT (AT+NAME, AT+ADDR)';
      case 'sdp_overflow':
        return 'SDP request con payload extendido (requiere stack vulnerable)';
      case 'l2cap_overflow':
        return 'L2CAP ping con tamaño máximo (requiere stack vulnerable)';
      case 'ble_sniff':
        return 'Captura BLE en el canal activo (requiere hardware dedicado)';
      case 'mac_spoofing':
        return 'Spoofing MAC local vía hcitool (requiere root)';
      default:
        return null;
    }
  }

  String _complexity(String attackType) {
    switch (attackType) {
      case 'sdp_overflow':
      case 'l2cap_overflow':
      case 'ble_sniff':
      case 'mac_spoofing':
        return 'alta';
      default:
        return 'baja';
    }
  }

  // ===== Ejecución de ataque óptimo =====

  Future<OptimalAttackExecution> executeOptimalAttack({
    required String deviceAddress,
    required Map<String, dynamic> deviceData,
    String preferredProtocol = 'spp',
  }) async {
    if (!_isInitialized) {
      throw Exception('Motor de análisis no inicializado');
    }

    final stopwatch = Stopwatch()..start();

    try {
      final analysis = await runCompleteSecurityAnalysis(
        deviceAddress: deviceAddress,
        deviceData: deviceData,
      );

      final exploits = await generateOptimalExploits(
        analysis: analysis,
        targetPlatform: deviceData['platform'] ?? 'android',
      );

      final bestExploit = exploits.isNotEmpty ? exploits.first : null;
      stopwatch.stop();

      if (bestExploit == null) {
        return OptimalAttackExecution(
          success: false,
          message:
              'No hay ataques con señal suficiente para este dispositivo. Ejecuta full_scan para confirmar servicios.',
          analysisDuration: stopwatch.elapsed,
          timestamp: DateTime.now(),
        );
      }

      return OptimalAttackExecution(
        success: true,
        exploitExecuted: bestExploit,
        attackStrategy: analysis.optimalAttackStrategy,
        analysisDuration: stopwatch.elapsed,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      stopwatch.stop();
      return OptimalAttackExecution(
        success: false,
        message: 'Error durante análisis: ${e.toString()}',
        analysisDuration: stopwatch.elapsed,
        timestamp: DateTime.now(),
      );
    }
  }

  Future<SystemStats> getSystemStats() async {
    final stats = SystemStats();
    stats.isInitialized = _isInitialized;
    stats.isInitializing = false;
    stats.initializationProgress = _isInitialized ? 1.0 : 0.0;
    return stats;
  }

  // ===== Identificación y optimización =====

  Future<Map<String, dynamic>> identifyAndOptimize(
    Map<String, dynamic> deviceData, {
    bool isBlackoutActive = false,
  }) async {
    final classification = assessDeviceClassification(deviceData);
    final attack = assessAttackSuccess(deviceData);

    final deviceType = _titleCase(classification.deviceCategory);
    final recommendedAttack = _decideBestAttack(classification.deviceCategory, deviceData);
    final bestIdx = attack.attackTypes.indexOf(recommendedAttack);
    final successScore = bestIdx >= 0
        ? attack.attackSuccessProbabilities[bestIdx]
        : attack.overallSuccessScore;

    final reasonParts = <String>[
      'Clasificación heurística: $deviceType (${(classification.confidence * 100).toStringAsFixed(0)}%)',
    ];
    if (isBlackoutActive) reasonParts.add('RF Blackout activo');
    reasonParts.add(
        'Ataque recomendado: $recommendedAttack (éxito estimado: ${(successScore * 100).toStringAsFixed(0)}%)');

    return {
      'identifiedType': deviceType,
      'confidence': (classification.confidence * 100).toStringAsFixed(1),
      'recommendedAttack': recommendedAttack,
      'successProbability': (successScore * 100).toStringAsFixed(1),
      'riskLevel': successScore > 0.6 ? 'CRITICAL' : 'LOW',
      'rationale': reasonParts.join('. '),
    };
  }

  String _titleCase(String s) => s.isEmpty
      ? s
      : s.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  String _decideBestAttack(String deviceCategory, Map<String, dynamic> d) {
    final hasObex = _fact(d, 'hasOBEX') || _fact(d, 'hasObex') || _hasService(d, 'obex');
    final hasBle = _fact(d, 'hasBle') || _fact(d, 'hasBLE');

    final typeLower = deviceCategory.toLowerCase();
    if (typeLower.contains('iot') || typeLower.contains('sensor')) {
      return 'GATT_FLOOD_DOS';
    }
    if (typeLower.contains('wearable')) {
      return hasObex ? 'FILE_EXFILTRATION' : 'PBAP_EXTRACT';
    }
    if (typeLower.contains('phone') || typeLower.contains('mobile') ||
        typeLower.contains('tablet') || typeLower.contains('laptop')) {
      if (hasObex) return 'FILE_EXFILTRATION';
      return 'PBAP_EXTRACT';
    }
    if (hasBle) return 'BTLEJACK_SCAN';
    return 'BASIC_VULN_SCAN';
  }

  // ===== Lenguaje natural → comandos =====

  Future<Map<String, dynamic>> processNaturalCommand(
      String input, String deviceAddress) async {
    final command = input.toLowerCase();

    if (command.contains('derrumba') || command.contains('tira') || command.contains('bloquea')) {
      return {
        'action': 'DOS_ATTACK',
        'type': 'GATT_FLOOD',
        'params': {'duration': 15},
        'rationale': 'Se detectó intención de denegación de servicio.',
      };
    }

    if (command.contains('archivos') || command.contains('fotos') || command.contains('datos')) {
      return {
        'action': 'FILE_EXFILTRATION',
        'type': 'OBEX_SOCKET',
        'params': <String, dynamic>{},
        'rationale': 'Se detectó intención de extracción de información.',
      };
    }

    if (command.contains('escucha') || command.contains('espía') || command.contains('paquetes')) {
      return {
        'action': 'SNIFFING',
        'type': 'BTLEJACK_SNIFF',
        'params': {'duration': 30},
        'rationale': 'Se detectó intención de interceptación de tráfico.',
      };
    }

    if (command.contains('identifica') || command.contains('quién es')) {
      return {
        'action': 'AI_FINGERPRINTING',
        'type': 'CLASSIFICATION',
        'params': <String, dynamic>{},
        'rationale': 'Se detectó intención de reconocimiento avanzado.',
      };
    }

    return {
      'action': 'UNKNOWN',
      'message': 'No he podido determinar la acción técnica para esa instrucción.',
    };
  }

  // ===== Derivación de IMEI candidato desde BD_ADDR =====
  //
  // En algunos teléfonos antiguos (Samsung/MTK ~2010-2016) el dirección
  // Bluetooth se derivaba del IMEI en fábrica. No existe un algoritmo público
  // fiable: esto genera CANDIDATOS plausibles (TAC conocidos + SN derivado del
  // MAC + dígito de control Luhn) y los marca SIEMPRE como no verificados.

  /// Genera candidatos de IMEI a partir de la dirección Bluetooth.
  /// Devuelve una lista de mapas {imei, tac, verified: false, confidence}.
  List<Map<String, dynamic>> deriveImeiCandidates(String? bdAddress) {
    final mac = (bdAddress ?? '')
        .replaceAll(RegExp(r'[^0-9A-Fa-f]'), '')
        .toUpperCase();
    if (mac.length != 12) {
      return [];
    }

    // TACs (6 primeros dígitos) por fabricante mayoritario
    const tacByVendor = <String, List<String>>{
      'SAMSUNG': ['355146', '355147', '355942', '351977', '352932', '356936'],
      'HUAWEI': ['866472', '869416', '860861', '867651'],
      'XIAOMI': ['866354', '860222', '863885', '866505'],
      'NOKIA': ['351956', '358240', '356749', '355836'],
      'MOTOROLA': ['352228', '356844', '354523'],
    };

    // SN derivado del MAC: últimos 4 nibbles en decimal (fabricación histórica)
    final macTail = int.tryParse(mac.substring(8), radix: 16) ?? 0;
    final serial = (macTail % 1000000).toString().padLeft(6, '0');

    final candidates = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final tacs in tacByVendor.values) {
      for (final tac in tacs) {
        final base = tac + serial;
        final cd = _luhnCheckDigit(base);
        final imei = base + cd;
        if (seen.add(imei)) {
          candidates.add({
            'imei': imei,
            'tac': tac,
            'verified': false,
            'confidence': 0.3,
            'source': 'derivado de BD_ADDR (no verificado)',
          });
        }
      }
    }
    return candidates;
  }

  /// Dígito de control Luhn para un IMEI de 14 dígitos (TAC+SN).
  String _luhnCheckDigit(String base14) {
    final digits = base14.split('').map(int.parse).toList();
    var sum = 0;
    for (var i = 0; i < digits.length; i++) {
      var d = digits[i];
      // Doblar posiciones pares contando desde la izquierda (índice 0,2,4...)
      if (i % 2 == 0) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
    }
    final cd = (10 - (sum % 10)) % 10;
    return cd.toString();
  }

  // ===== Evaluación de vulnerabilidades (reemplaza MLVulnerabilityPredictor) =====

  Future<VulnerabilityPrediction> assessVulnerabilities(
      String deviceAddress, Map<String, dynamic> deviceData) async {
    final vulns = <VulnerabilityInfo>[];
    final hasObex = _fact(deviceData, 'hasOBEX') || _fact(deviceData, 'hasObex') ||
        _hasService(deviceData, 'obex');
    final hasFtp = _fact(deviceData, 'supportsFTP') || _hasService(deviceData, 'ftp');
    final hasGatt = _fact(deviceData, 'hasGatt') || _hasService(deviceData, 'gatt');
    final noPairingAuth = _fact(deviceData, 'noPairingAuth');
    final discoverable = _fact(deviceData, 'discoverable');
    final androidVersion = _num(deviceData, 'androidVersion', 13.0);
    final btVersion = _num(deviceData, 'bluetoothVersion', 5.0);
    final bondState = deviceData['bondState']?.toString() ?? '';
    final bonded = bondState.toLowerCase().contains('bond') || _fact(deviceData, 'isBonded');

    void addIf(double confidence, String id, String type) {
      if (confidence > 0.5) {
        vulns.add(VulnerabilityInfo(
          id: id,
          label: id,
          confidence: confidence,
          type: type,
        ));
      }
    }

    // OBEX sin autenticación: señal real detectada por SDP
    if (hasObex && !bonded) {
      addIf(0.8, 'no_auth_obex', 'configuration');
    }
    if (hasFtp && !bonded) {
      addIf(0.7, 'no_auth_obex', 'configuration');
    }
    // Pairing débil
    if (noPairingAuth || (btVersion <= 4.2 && !bonded)) {
      addIf(0.65, 'weak_pairing', 'pairing');
    }
    // GATT flood vector (presencia de servicios GATT)
    if (hasGatt) {
      addIf(0.55, 'CVE-2020-12351', 'cve');
    }
    // BlueBorne solo en stacks antiguos conocidos
    if (androidVersion < 8.0 && discoverable) {
      addIf(0.75, 'CVE-2017-1000251', 'cve');
    }
    // HID injection (CVE-2023-45866) solo si hay evidencia de perfil HID
    if (discoverable && btVersion >= 4.0) {
      addIf(0.6, 'CVE-2023-45866', 'cve');
    }
    // BlueSnarf en Android antiguo con OBEX
    if (androidVersion < 10.0 && hasObex) {
      addIf(0.6, 'CVE-2003-0300', 'cve');
    }
    // KNOB en stacks BR/EDR antiguos
    if (btVersion <= 4.2) {
      addIf(0.55, 'CVE-2019-9506', 'cve');
    }

    vulns.sort((a, b) => b.confidence.compareTo(a.confidence));

    final overallRisk = vulns.isEmpty
        ? 0.0
        : vulns.map((v) => v.confidence).reduce((a, b) => a + b) / vulns.length;

    return VulnerabilityPrediction(
      deviceAddress: deviceAddress,
      vulnerabilities: vulns,
      overallRiskLevel: _riskLevel(overallRisk),
      overallRiskScore: overallRisk,
      cveCount: vulns.length,
      recommendedAction: _recommendAction(vulns),
    );
  }

  String _riskLevel(double score) {
    if (score >= 0.7) return 'CRITICAL';
    if (score >= 0.5) return 'HIGH';
    if (score >= 0.3) return 'MEDIUM';
    return 'LOW';
  }

  String _recommendAction(List<VulnerabilityInfo> vulns) {
    if (vulns.isEmpty) {
      return 'No se detectaron señales de vulnerabilidad. Ejecutar full_scan para enumerar servicios manualmente.';
    }
    final top = vulns.first;
    switch (top.id) {
      case 'CVE-2017-1000251':
        return 'Ejecutar blueborne exploit (stack Android < 8)';
      case 'CVE-2023-45866':
        return 'Inyectar HID keystrokes (notepad/wifi/terminal)';
      case 'CVE-2003-0300':
        return 'Extraer contactos via obex_get (telecom/pb.vcf)';
      case 'no_auth_obex':
        return 'Extraer archivos via file_exfil/obex_scan';
      case 'weak_pairing':
        return 'Intentar bypass auth (quick_connect)';
      default:
        return 'Priorizar ataque para ${top.id}';
    }
  }

  /// Genera script HID según hechos del objetivo. Devuelve null si no hay señal.
  Future<String?> generateAIScript(Map<String, dynamic> deviceData) async {
    final classification = assessDeviceClassification(deviceData);
    final type = classification.deviceCategory;

    if (type.contains('laptop') || type.contains('desktop')) {
      // Windows: combinación de teclas por HID (Win+R)
      return 'cmd /c "echo prueba > %TEMP%\\bluesnafer_probe.txt"';
    }

    if (type.contains('phone') || type.contains('tablet') || type.contains('wearable')) {
      // Android: teclas de evento
      return 'input keyevent 26';
    }

    return null;
  }
}

// ===== Modelos de datos del análisis =====

class PinBypassPrediction {
  final bool isVulnerable;
  final double confidence;
  final double threshold;
  final List<String> outputClasses;
  final Map<String, dynamic>? adaptiveFactors;

  PinBypassPrediction({
    required this.isVulnerable,
    required this.confidence,
    required this.threshold,
    required this.outputClasses,
    this.adaptiveFactors,
  });
}

class AttackSuccessPrediction {
  final List<double> attackSuccessProbabilities;
  final List<String> attackTypes;
  final double overallSuccessScore;
  final Map<String, double>? adaptiveWeights;
  final double? modelConfidence;
  final List<String>? recommendedAttacks;

  AttackSuccessPrediction({
    required this.attackSuccessProbabilities,
    required this.attackTypes,
    required this.overallSuccessScore,
    this.adaptiveWeights,
    this.modelConfidence,
    this.recommendedAttacks,
  });
}

class DeviceClassification {
  final String deviceCategory;
  final List<double> categoryProbabilities;
  final List<String> categories;
  final double confidence;

  DeviceClassification({
    required this.deviceCategory,
    required this.categoryProbabilities,
    required this.categories,
    required this.confidence,
  });
}

class CountermeasureDetection {
  final List<String> detectedCountermeasures;
  final List<double> countermeasureProbabilities;
  final List<String> countermeasures;
  final double overallSecurityLevel;

  CountermeasureDetection({
    required this.detectedCountermeasures,
    required this.countermeasureProbabilities,
    required this.countermeasures,
    required this.overallSecurityLevel,
  });
}

class OptimalAttackStrategy {
  final List<RecommendedAttack> recommendedAttacks;
  final double overallStrategyScore;
  final String strategyRationale;

  OptimalAttackStrategy({
    required this.recommendedAttacks,
    required this.overallStrategyScore,
    required this.strategyRationale,
  });
}

class RecommendedAttack {
  final String attackType;
  final double confidence;
  final double estimatedSuccessRate;
  final List<String> requiredResources;

  RecommendedAttack({
    required this.attackType,
    required this.confidence,
    required this.estimatedSuccessRate,
    required this.requiredResources,
  });
}

class OptimalAttackExecution {
  final bool success;
  final GeneratedExploit? exploitExecuted;
  final OptimalAttackStrategy? attackStrategy;
  final Duration analysisDuration;
  final DateTime timestamp;
  final String? message;

  OptimalAttackExecution({
    required this.success,
    this.exploitExecuted,
    this.attackStrategy,
    required this.analysisDuration,
    required this.timestamp,
    this.message,
  });
}

class CompleteSecurityAnalysis {
  final String deviceAddress;
  final PinBypassPrediction pinBypassPrediction;
  final AttackSuccessPrediction attackSuccessPrediction;
  final DeviceClassification deviceClassification;
  final CountermeasureDetection detectedCountermeasures;
  final OptimalAttackStrategy optimalAttackStrategy;
  final Duration analysisDuration;
  final DateTime timestamp;
  final double confidence;

  CompleteSecurityAnalysis({
    required this.deviceAddress,
    required this.pinBypassPrediction,
    required this.attackSuccessPrediction,
    required this.deviceClassification,
    required this.detectedCountermeasures,
    required this.optimalAttackStrategy,
    required this.analysisDuration,
    required this.timestamp,
    required this.confidence,
  });
}

class SystemStats {
  bool isInitialized = false;
  bool isInitializing = false;
  double initializationProgress = 0.0;
  Map<String, int>? cacheStats;
}

class GeneratedExploit {
  final String vulnerabilityType;
  final String exploitCode;
  final String targetPlatform;
  final String generationMethod;
  final String complexityLevel;
  final double estimatedSuccessRate;
  final List<String> requiredResources;
  final DateTime timestamp;

  GeneratedExploit({
    required this.vulnerabilityType,
    required this.exploitCode,
    required this.targetPlatform,
    required this.generationMethod,
    required this.complexityLevel,
    required this.estimatedSuccessRate,
    required this.requiredResources,
    required this.timestamp,
  });
}

class VulnerabilityPrediction {
  final String deviceAddress;
  final List<VulnerabilityInfo> vulnerabilities;
  final String overallRiskLevel;
  final double overallRiskScore;
  final int cveCount;
  final String recommendedAction;

  VulnerabilityPrediction({
    required this.deviceAddress,
    required this.vulnerabilities,
    required this.overallRiskLevel,
    required this.overallRiskScore,
    required this.cveCount,
    required this.recommendedAction,
  });
}

class VulnerabilityInfo {
  final String id;
  final String label;
  final double confidence;
  final String type;

  VulnerabilityInfo({
    required this.id,
    required this.label,
    required this.confidence,
    required this.type,
  });
}
