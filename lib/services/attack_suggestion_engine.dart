// BlueSnafer Pro - Sistema de Sugerencias Inteligente con FLUJO GUIADO PASO A PASO
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AttackSuggestionEngine {
  final List<AttackRecord> _history = [];

  Map<String, AttackStats> _statsByType = {};
  Map<String, AttackStats> _statsByDevice = {};
  int _totalAttacks = 0;
  int _totalSuccess = 0;

  Future<void> loadHistory() async {
    try {
      final file = await _getHistoryFile();
      if (await file.exists()) {
        final data = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(data);
        _history.clear();
        _history.addAll(jsonList.map((e) => AttackRecord.fromJson(e)).toList());
        _recalculateStats();
      }
    } catch (e) {
      print('Error loading history: $e');
    }
  }

  Future<void> saveHistory() async {
    try {
      final file = await _getHistoryFile();
      final jsonList = _history.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error saving history: $e');
    }
  }

  void recordAttack({
    required String type,
    required String command,
    required bool success,
    required String deviceType,
    required String deviceName,
    required String deviceAddress,
    int? rssi,
    String? errorMessage,
  }) {
    final record = AttackRecord(
      type: type,
      command: command,
      success: success,
      deviceType: deviceType,
      deviceName: deviceName,
      deviceAddress: deviceAddress,
      rssi: rssi,
      errorMessage: errorMessage,
      timestamp: DateTime.now(),
    );
    _history.add(record);
    _totalAttacks++;
    if (success) _totalSuccess++;
    _updateStats(record);
    saveHistory();
  }

  // ============================================================
  // FLUJO GUIADO PASO A PASO - Sugerencia inteligente por fases
  // ============================================================
  Suggestion suggestNextAttack({
    required String deviceType,
    required String deviceName,
    List<String>? excludedTypes,
  }) {
    if (_history.isEmpty) {
      return _getInitialSuggestion(deviceType);
    }

    // FASE 1: Si no ha hecho reconocimiento → sugerir SDP primero
    if (!_hasAttempted('sdp_discover') && !_hasAttempted('sdp')) {
      return Suggestion(
        type: 'sdp_discover',
        command: 'scan',
        confidence: 95.0,
        reason: 'FASE 1/5: Descubre TODOS los perfiles Bluetooth expuestos (sin pairing).',
        alternativeReason: 'Si funciona → FASE 2: OBEX File Exfil',
      );
    }

    // FASE 2: Si ya hizo SDP → sugerir escaneo OBEX/FTP
    if (!_hasAttempted('file_exfil') && !_hasAttempted('obex_scan')) {
      return Suggestion(
        type: 'file_exfil',
        command: 'scan',
        confidence: 75.0,
        reason: 'FASE 2/5: Extrae archivos vía OBEX FTP. Puede descubrir datos sin auth.',
        alternativeReason: 'Si OBEX rechaza → FASE 3: Auth Bypass',
      );
    }

    // FASE 3: Si OBEX falla → sugerir bypass
    if (!_hasAttempted('bypass')) {
      return Suggestion(
        type: 'bypass',
        command: 'quick_connect',
        confidence: 60.0,
        reason: 'FASE 3/5: Bypass de auth. Quick Connect Race explota race condition.',
        alternativeReason: 'Si bypass falla → FASE 4: Advanced Exploits',
      );
    }

    // FASE 4: Advanced Exploits - sugerir según lo que no se ha intentado
    if (!_hasAttempted('mirror_profile')) {
      return Suggestion(
        type: 'mirror_profile',
        command: '',
        confidence: 65.0,
        reason: 'FASE 4: Clona la base de datos GATT del objetivo.',
        alternativeReason: 'Después: BlueBorne, AT Injection, Full Scan',
      );
    }

    if (!_hasAttempted('blueborne')) {
      return Suggestion(
        type: 'blueborne',
        command: 'scan',
        confidence: 50.0,
        reason: 'FASE 4: Verifica BlueBorne CVE-2017-1000251.',
        alternativeReason: 'Después: AT Injection, Full Scan',
      );
    }

    if (!_hasAttempted('at_injection')) {
      return Suggestion(
        type: 'at_injection',
        command: '',
        confidence: 55.0,
        reason: 'FASE 4: Inyecta comandos AT vía HFP.',
        alternativeReason: 'Después: Full Scan, HID Inject',
      );
    }

    if (!_hasAttempted('full_scan')) {
      return Suggestion(
        type: 'full_scan',
        command: 'scan',
        confidence: 70.0,
        reason: 'FASE 4: Escaneo completo SDP+GATT+OBEX.',
        alternativeReason: 'Después: HID Inject, Spoofing',
      );
    }

    if (!_hasAttempted('spoofing')) {
      return Suggestion(
        type: 'spoofing',
        command: 'BlueSnafer Pro',
        confidence: 40.0,
        reason: 'FASE 4: Clona identidad del dispositivo.',
        alternativeReason: 'Después: HID Inject',
      );
    }

    if (!_hasAttempted('hid_inject')) {
      return Suggestion(
        type: 'hid_inject',
        command: '',
        confidence: 60.0,
        reason: 'FASE 4: Inyección directa de keystrokes.',
        alternativeReason: 'Después: DoS como último recurso',
      );
    }

    // FASE 5: Ataques directos según tipo de dispositivo
    return _getDeviceSpecificSuggestion(deviceType, excludedTypes);
  }

  bool _hasAttempted(String type) {
    return _executedTypes.contains(type);
  }

  Set<String> get _executedTypes {
    return _history.map((r) => r.type).toSet();
  }

  // Sugerencia inicial - FLUJO PASO A PASO
  Suggestion _getInitialSuggestion(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'smartphone':
      case 'mobile phone':
        return Suggestion(
          type: 'sdp_discover',
          command: 'scan',
          confidence: 95.0,
          reason: 'PASO 1/5: Descubre perfiles expuestos (SDP). Sin pairing necesario.',
          alternativeReason: 'Si funciona → paso 2: OBEX File Exfil. Si falla → Auth Bypass',
        );

      case 'headset':
      case 'speaker':
      case 'audio':
        return Suggestion(
          type: 'btlejack',
          command: 'scan',
          confidence: 85.0,
          reason: 'PASO 1/4: Escanea servicios BLE del audio. Revela características expuestas.',
          alternativeReason: 'Siguiente: SNIFF → HIJACK → JAM',
        );

      case 'car':
      case 'vehicle':
        return Suggestion(
          type: 'btlejack',
          command: 'mitm',
          confidence: 70.0,
          reason: 'PASO 1/4: MITM en sistemas de coche. Intercepta comunicaciones BLE.',
          alternativeReason: 'Alternativa: SCAN para mapear, luego HIJACK',
        );

      case 'wearable':
        return Suggestion(
          type: 'pbap_extract',
          command: 'contacts',
          confidence: 60.0,
          reason: 'PASO 1/3: Extrae contactos/historial del wearable vía PBAP.',
          alternativeReason: 'Si PBAP falla → OBEX Trust Abuse',
        );

      default:
        return Suggestion(
          type: 'sdp_discover',
          command: 'scan',
          confidence: 90.0,
          reason: 'PASO 1/5: SDP Discovery - descubre TODOS los perfiles sin auth.',
          alternativeReason: 'Después: OBEX FTP → Auth Bypass → Ataque directo',
        );
    }
  }

  // Sugerencia específica por dispositivo (fase de ataque directo)
  Suggestion _getDeviceSpecificSuggestion(String deviceType, List<String>? excluded) {
    final excl = excluded ?? [];
    switch (deviceType.toLowerCase()) {
      case 'smartphone':
      case 'mobile phone':
        if (!excl.contains('hid') && !excl.contains('hid_script')) {
          return Suggestion(
            type: 'hid',
            command: 'notepad',
            confidence: 75.0,
            reason: 'FASE 5: HID Injection. Inyecta keystrokes reales en smartphone.',
            alternativeReason: 'Si HID falla → AT Injection o BlueBorne check',
          );
        }
        return Suggestion(
          type: 'blueborne',
          command: 'scan',
          confidence: 40.0,
          reason: 'FASE FINAL: Check BlueBorne CVE-2017-1000251 en smartphone.',
          alternativeReason: 'Si todo falla → DoS como último recurso',
        );

      case 'headset':
      case 'speaker':
      case 'audio':
        if (!excl.contains('btlejack')) {
          return Suggestion(
            type: 'btlejack',
            command: 'sniff',
            confidence: 65.0,
            reason: 'FASE 4: SNIFF captura datos BLE del headset.',
            alternativeReason: 'Si sniff falla → DoS Jam',
          );
        }
        return Suggestion(
          type: 'dos',
          command: 'gatt_flood',
          confidence: 50.0,
          reason: 'ÚLTIMO RECURSO: DoS GATT Flood en dispositivo de audio.',
          alternativeReason: 'Si todo falla → intentar bypass de nuevo',
        );

      default:
        if (!excl.contains('full_scan')) {
          return Suggestion(
            type: 'full_scan',
            command: 'scan',
            confidence: 55.0,
            reason: 'Escaneo completo de vulnerabilidades SDP+GATT+OBEX.',
            alternativeReason: 'Resultados mostrarán vectores de ataque disponibles',
          );
        }
        return Suggestion(
          type: 'dos',
          command: 'gatt_flood',
          confidence: 45.0,
          reason: 'ÚLTIMO RECURSO: DoS puede interrumpir servicio.',
          alternativeReason: 'Si todo falla → AUTH BYPASS en IA/VA',
        );
    }
  }

  // Fallback cuando todo ha fallado
  Suggestion _getFallbackSuggestion(String deviceType, List<String>? excluded) {
    final excl = excluded ?? [];
    if (!excl.contains('full_scan')) {
      return Suggestion(
        type: 'full_scan',
        command: 'scan',
        confidence: 50.0,
        reason: 'Re-evaluar superficie de ataque con escaneo completo.',
        alternativeReason: 'Los resultados guiarán el siguiente paso',
      );
    }
    if (!excl.contains('bypass')) {
      return Suggestion(
        type: 'bypass',
        command: 'quick_connect',
        confidence: 45.0,
        reason: 'Intentar bypass de auth con Quick Connect Race.',
        alternativeReason: 'Si falla → MAC Spoof o OBEX Trust Abuse',
      );
    }
    return Suggestion(
      type: 'dos',
      command: 'gatt_flood',
      confidence: 30.0,
      reason: 'ÚLTIMO RECURSO: DoS como último intento.',
      alternativeReason: 'Si todo falla → cambiar de objetivo',
    );
  }

  // Razón alternativa basada en tipo sugerido
  String _getAlternativeReason(String deviceType, String suggestedType) {
    if (suggestedType == 'sdp_discover' || suggestedType == 'sdp') {
      return 'Después de SDP → OBEX File Exfil → si falla, Auth Bypass';
    }
    if (suggestedType == 'file_exfil' || suggestedType == 'obex_scan') {
      return 'Si OBEX rechaza → Quick Connect Race o Trust Abuse en AUTH BYPASS';
    }
    if (suggestedType == 'bypass') {
      return 'Si bypass falla → Full Scan para ver qué perfiles siguen accesibles';
    }
    if (suggestedType == 'hid' || suggestedType == 'hid_script') {
      return 'Si HID falla → AT Injection o BlueBorne en ADVANCED EXPLOITS';
    }
    if (suggestedType == 'btlejack') {
      return 'Si BtleJack falla → Mirror Profile para clonar GATT database';
    }
    if (suggestedType == 'dos') {
      return 'Si DoS falla → Full Scan para re-evaluar, luego bypass';
    }
    return 'Si todo falla → AUTH BYPASS (Quick Connect / OBEX Trust) en IA/VA';
  }

  // Actualizar estadísticas
  void _updateStats(AttackRecord record) {
    final typeKey = '${record.type}_${record.command ?? "default"}';
    final deviceKey = record.deviceType.toLowerCase();

    if (!_statsByType.containsKey(typeKey)) {
      _statsByType[typeKey] = AttackStats(type: typeKey);
    }
    _statsByType[typeKey]!.addRecord(record.success);

    if (!_statsByDevice.containsKey(deviceKey)) {
      _statsByDevice[deviceKey] = AttackStats(type: deviceKey);
    }
    _statsByDevice[deviceKey]!.addRecord(record.success);
  }

  void _recalculateStats() {
    _statsByType.clear();
    _statsByDevice.clear();
    _totalAttacks = 0;
    _totalSuccess = 0;

    for (var record in _history) {
      _totalAttacks++;
      if (record.success) _totalSuccess++;
      _updateStats(record);
    }
  }

  Future<File> _getHistoryFile() async {
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      final appDir = await getApplicationDocumentsDirectory();
      return File('${appDir.path}/BlueSnafer_Files/attack_history.json');
    }
    final path = '${directory.path}/BlueSnafer_Files';
    await Directory(path).create(recursive: true);
    return File('$path/attack_history.json');
  }

  Map<String, dynamic> getGlobalStats() {
    return {
      'total_attacks': _totalAttacks,
      'total_success': _totalSuccess,
      'total_failed': _totalAttacks - _totalSuccess,
      'success_rate': _totalAttacks > 0
          ? (_totalSuccess / _totalAttacks * 100).toStringAsFixed(1)
          : '0.0',
      'history_size': _history.length,
      'attack_types': _statsByType.length,
      'device_types': _statsByDevice.length,
    };
  }

  List<Map<String, dynamic>> getTopAttacks({int limit = 5}) {
    final sorted = _statsByType.entries.toList()
      ..sort((a, b) => b.value.successRate.compareTo(a.value.successRate));

    return sorted.take(limit).map((e) => {
      'type': e.value.type,
      'total': e.value.total,
      'success': e.value.success,
      'success_rate': e.value.successRate.toStringAsFixed(1),
    }).toList();
  }

  AttackStats getStatsForType(String type) {
    return _statsByType[type] ?? AttackStats(type: type);
  }

  List<AttackRecord> getRecentHistory({int limit = 20}) {
    return _history.reversed.take(limit).toList();
  }

  Future<void> clearHistory() async {
    _history.clear();
    _statsByType.clear();
    _statsByDevice.clear();
    _totalAttacks = 0;
    _totalSuccess = 0;

    try {
      final file = await _getHistoryFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error clearing history: $e');
    }
  }
}

class AttackRecord {
  final String type;
  final String command;
  final bool success;
  final String deviceType;
  final String deviceName;
  final String deviceAddress;
  final int? rssi;
  final String? errorMessage;
  final DateTime timestamp;

  AttackRecord({
    required this.type,
    required this.command,
    required this.success,
    required this.deviceType,
    required this.deviceName,
    required this.deviceAddress,
    this.rssi,
    this.errorMessage,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'command': command,
      'success': success,
      'device_type': deviceType,
      'device_name': deviceName,
      'device_address': deviceAddress,
      'rssi': rssi,
      'error_message': errorMessage,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static AttackRecord fromJson(Map<String, dynamic> json) {
    return AttackRecord(
      type: json['type'],
      command: json['command'] ?? '',
      success: json['success'],
      deviceType: json['device_type'],
      deviceName: json['device_name'],
      deviceAddress: json['device_address'],
      rssi: json['rssi'],
      errorMessage: json['error_message'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class AttackStats {
  final String type;
  int total = 0;
  int success = 0;
  int failed = 0;

  AttackStats({required this.type});

  void addRecord(bool wasSuccess) {
    total++;
    if (wasSuccess) {
      success++;
    } else {
      failed++;
    }
  }

  double get successRate => total > 0 ? (success / total * 100) : 0.0;
}

class Suggestion {
  final String type;
  final String? command;
  final double confidence;
  final String reason;
  final String alternativeReason;

  Suggestion({
    required this.type,
    this.command,
    required this.confidence,
    required this.reason,
    this.alternativeReason = '',
  });

  String get displayText => command != null ? '$type: $command' : type;
}
