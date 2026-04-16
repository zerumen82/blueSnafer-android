import 'dart:convert';
import 'dart:io';

// Import logging system
import 'advanced_logger.dart';

/// Sistema de configuración dinámica para BlueSnafer Pro
/// Reemplaza valores hardcodeados con configuración externa
class DynamicConfiguration {
  static const String _configDir = 'config';
  static const String _mainConfigFile = '$_configDir/bluesnafer.json';
  static const String _exploitConfigFile = '$_configDir/exploits.json';
  static const String _aiConfigFile = '$_configDir/ai.json';

  static Map<String, dynamic> _mainConfig = {};
  static Map<String, dynamic> _exploitConfig = {};
  static Map<String, dynamic> _aiConfig = {};

  static bool _initialized = false;

  /// Inicializar configuración
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Crear directorio de configuración si no existe
      final configDir = Directory(_configDir);
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }

      // Cargar configuración principal
      await _loadMainConfig();

      // Cargar configuración de exploits
      await _loadExploitConfig();

      // Cargar configuración de IA
      await _loadAiConfig();

      _initialized = true;
      AdvancedLogger.staticLogger
          .logInfo('Dynamic configuration initialized successfully');
    } catch (e) {
      AdvancedLogger.staticLogger.logError(
          'Failed to initialize dynamic configuration', {}, e as Exception?);
      // Usar configuración por defecto
      _loadDefaultConfig();
    }
  }

  /// Obtener configuración principal
  static Map<String, dynamic> getMainConfig() {
    return Map.from(_mainConfig);
  }

  /// Obtener configuración de exploits
  static Map<String, dynamic> getExploitConfig() {
    return Map.from(_exploitConfig);
  }

  /// Obtener configuración de IA
  static Map<String, dynamic> getAiConfig() {
    return Map.from(_aiConfig);
  }

  /// Obtener valor específico de configuración
  static dynamic getConfig(String section, String key, [dynamic defaultValue]) {
    switch (section) {
      case 'main':
        return _mainConfig[key] ?? defaultValue;
      case 'exploits':
        return _exploitConfig[key] ?? defaultValue;
      case 'ai':
        return _aiConfig[key] ?? defaultValue;
      default:
        return defaultValue;
    }
  }

  /// Establecer valor de configuración
  static Future<void> setConfig(
      String section, String key, dynamic value) async {
    switch (section) {
      case 'main':
        _mainConfig[key] = value;
        await _saveMainConfig();
        break;
      case 'exploits':
        _exploitConfig[key] = value;
        await _saveExploitConfig();
        break;
      case 'ai':
        _aiConfig[key] = value;
        await _saveAiConfig();
        break;
    }
  }

  /// Cargar configuración principal
  static Future<void> _loadMainConfig() async {
    try {
      final file = File(_mainConfigFile);
      if (await file.exists()) {
        final content = await file.readAsString();
        final parsed = json.decode(content);
        if (parsed is Map<String, dynamic>) {
          _mainConfig = parsed;
        } else {
          _mainConfig = _getDefaultMainConfig();
        }
      } else {
        // Crear configuración por defecto
        _mainConfig = _getDefaultMainConfig();
        await _saveMainConfig();
      }
    } catch (e) {
      AdvancedLogger.staticLogger.logWarning(
          'Failed to load main config, using defaults',
          {'error': e.toString()});
      _mainConfig = _getDefaultMainConfig();
    }
  }

  /// Cargar configuración de exploits
  static Future<void> _loadExploitConfig() async {
    try {
      final file = File(_exploitConfigFile);
      if (await file.exists()) {
        final content = await file.readAsString();
        final parsed = json.decode(content);
        if (parsed is Map<String, dynamic>) {
          _exploitConfig = parsed;
        } else {
          _exploitConfig = _getDefaultExploitConfig();
        }
      } else {
        // Crear configuración por defecto
        _exploitConfig = _getDefaultExploitConfig();
        await _saveExploitConfig();
      }
    } catch (e) {
      AdvancedLogger.staticLogger.logWarning(
          'Failed to load exploit config, using defaults',
          {'error': e.toString()});
      _exploitConfig = _getDefaultExploitConfig();
    }
  }

  /// Cargar configuración de IA
  static Future<void> _loadAiConfig() async {
    try {
      final file = File(_aiConfigFile);
      if (await file.exists()) {
        final content = await file.readAsString();
        final parsed = json.decode(content);
        if (parsed is Map<String, dynamic>) {
          _aiConfig = parsed;
        } else {
          _aiConfig = _getDefaultAiConfig();
        }
      } else {
        // Crear configuración por defecto
        _aiConfig = _getDefaultAiConfig();
        await _saveAiConfig();
      }
    } catch (e) {
      AdvancedLogger.staticLogger.logWarning(
          'Failed to load AI config, using defaults', {'error': e.toString()});
      _aiConfig = _getDefaultAiConfig();
    }
  }

  /// Guardar configuración principal
  static Future<void> _saveMainConfig() async {
    await _saveConfig(_mainConfigFile, _mainConfig);
  }

  /// Guardar configuración de exploits
  static Future<void> _saveExploitConfig() async {
    await _saveConfig(_exploitConfigFile, _exploitConfig);
  }

  /// Guardar configuración de IA
  static Future<void> _saveAiConfig() async {
    await _saveConfig(_aiConfigFile, _aiConfig);
  }

  /// Guardar configuración a archivo
  static Future<void> _saveConfig(
      String filePath, Map<String, dynamic> config) async {
    try {
      final file = File(filePath);
      final jsonString = const JsonEncoder.withIndent('  ').convert(config);
      await file.writeAsString(jsonString);
    } catch (e) {
      AdvancedLogger.staticLogger.logError('Failed to save config to $filePath',
          {}, e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Configuración principal por defecto
  static Map<String, dynamic> _getDefaultMainConfig() {
    return {
      'app_name': 'BlueSnafer Pro',
      'version': '2.0.0',
      'debug_mode': true,
      'log_level': 'INFO',
      'max_concurrent_exploits': 3,
      'default_timeout_ms': 30000,
      'retry_attempts': 3,
      'cache_ttl_minutes': 30,
      'ui_theme': 'dark',
      'auto_update': true,
      'enable_analytics': false,
      'method_channels': {
        'bluetooth': 'com.bluesnafer_pro/bluetooth',
        'commands': 'bluetooth_commands',
        'logs': 'bluetooth_logs'
      },
      'timeouts': {
        'vulnerability_check': 10000,
        'device_info': 5000,
        'exploit_execution': 30000,
        'connection': 15000
      }
    };
  }

  /// Configuración de exploits por defecto
  static Map<String, dynamic> _getDefaultExploitConfig() {
    return {
      'enable_adaptive_payloads': true,
      'enable_evasion_techniques': true,
      'enable_ml_predictions': true,
      'enable_combination_attacks': true,
      'default_success_rate_threshold': 0.5,
      'max_payloads_per_exploit': 5,
      'exploit_priorities': {
        'btlejack:scan': 10,
        'vuln:scan': 9,
        'file:enum_real': 8,
        'btlejack:sniff': 7,
        'vuln:obex_put': 6,
        'file:exfiltrate_real': 5,
        'btlejack:hijack': 4,
        'vuln:ftp_anonymous': 3,
        'btlejack:blesa': 2,
        'vuln:at_command_injection': 1
      },
      'evasion_techniques': [
        'channel_hopping',
        'mac_spoofing',
        'timing_attacks',
        'packet_fragmentation'
      ],
      'risk_assessment': {
        'high_risk_threshold': 0.8,
        'medium_risk_threshold': 0.6,
        'enable_risk_mitigation': true
      }
    };
  }

  /// Configuración de IA por defecto
  static Map<String, dynamic> _getDefaultAiConfig() {
    return {
      'ml_model_version': '2.0',
      'enable_recommendations': true,
      'enable_adaptive_learning': true,
      'prediction_confidence_threshold': 0.7,
      'max_recommendations': 5,
      'learning_rate': 0.01,
      'model_update_frequency_days': 7,
      'feature_weights': {
        'device_type': 0.3,
        'bluetooth_version': 0.25,
        'services_detected': 0.2,
        'historical_success': 0.15,
        'security_level': 0.1
      },
      'recommendation_engine': {
        'contextual_analysis': true,
        'historical_data_weight': 0.4,
        'real_time_data_weight': 0.6,
        'exploit_combination_bonus': 0.2
      }
    };
  }

  /// Cargar configuración por defecto si falla la carga
  static void _loadDefaultConfig() {
    _mainConfig = _getDefaultMainConfig();
    _exploitConfig = _getDefaultExploitConfig();
    _aiConfig = _getDefaultAiConfig();
  }

  /// Exportar toda la configuración
  static Map<String, dynamic> exportConfig() {
    return {
      'main': _mainConfig,
      'exploits': _exploitConfig,
      'ai': _aiConfig,
      'exported_at': DateTime.now().toIso8601String(),
      'version': '1.0'
    };
  }

  /// Importar configuración desde archivo
  static Future<void> importConfig(Map<String, dynamic> configData) async {
    try {
      if (configData.containsKey('main')) {
        _mainConfig = Map<String, dynamic>.from(configData['main']);
        await _saveMainConfig();
      }
      if (configData.containsKey('exploits')) {
        _exploitConfig = Map<String, dynamic>.from(configData['exploits']);
        await _saveExploitConfig();
      }
      if (configData.containsKey('ai')) {
        _aiConfig = Map<String, dynamic>.from(configData['ai']);
        await _saveAiConfig();
      }
      AdvancedLogger.staticLogger
          .logInfo('Configuration imported successfully');
    } catch (e) {
      AdvancedLogger.staticLogger.logError('Failed to import configuration', {},
          e is Exception ? e : Exception(e.toString()));
      throw Exception('Failed to import configuration: $e');
    }
  }

  /// Resetear configuración a valores por defecto
  static Future<void> resetToDefaults() async {
    _loadDefaultConfig();
    await _saveMainConfig();
    await _saveExploitConfig();
    await _saveAiConfig();
    AdvancedLogger.staticLogger.logInfo('Configuration reset to defaults');
  }

  /// Validar configuración actual
  static bool validateConfig() {
    try {
      // Validar configuración principal
      final mainValidation = _validateMainConfig();
      if (!mainValidation) return false;

      // Validar configuración de exploits
      final exploitValidation = _validateExploitConfig();
      if (!exploitValidation) return false;

      // Validar configuración de IA
      final aiValidation = _validateAiConfig();
      if (!aiValidation) return false;

      return true;
    } catch (e) {
      AdvancedLogger.staticLogger.logError('Configuration validation failed',
          {}, e is Exception ? e : Exception(e.toString()));
      return false;
    }
  }

  /// Validar configuración principal
  static bool _validateMainConfig() {
    return _mainConfig.containsKey('app_name') &&
        _mainConfig.containsKey('version') &&
        _mainConfig.containsKey('debug_mode');
  }

  /// Validar configuración de exploits
  static bool _validateExploitConfig() {
    return _exploitConfig.containsKey('enable_adaptive_payloads') &&
        _exploitConfig.containsKey('enable_evasion_techniques');
  }

  /// Validar configuración de IA
  static bool _validateAiConfig() {
    return _aiConfig.containsKey('ml_model_version') &&
        _aiConfig.containsKey('enable_recommendations');
  }
}

/// Extensiones útiles para acceso rápido a configuración
extension ConfigExtensions on DynamicConfiguration {
  static String get appName =>
      DynamicConfiguration.getConfig('main', 'app_name', 'BlueSnafer Pro');
  static String get version =>
      DynamicConfiguration.getConfig('main', 'version', '2.0.0');
  static bool get debugMode =>
      DynamicConfiguration.getConfig('main', 'debug_mode', true);
  static int get maxConcurrentExploits =>
      DynamicConfiguration.getConfig('main', 'max_concurrent_exploits', 3);
  static int get defaultTimeout =>
      DynamicConfiguration.getConfig('main', 'default_timeout_ms', 30000);

  static String get bluetoothChannel => DynamicConfiguration.getConfig(
      'main', 'method_channels.bluetooth', 'com.bluesnafer_pro/bluetooth');
  static String get commandsChannel => DynamicConfiguration.getConfig(
      'main', 'method_channels.commands', 'bluetooth_commands');
  static String get logsChannel => DynamicConfiguration.getConfig(
      'main', 'method_channels.logs', 'bluetooth_logs');

  static bool get enableAdaptivePayloads => DynamicConfiguration.getConfig(
      'exploits', 'enable_adaptive_payloads', true);
  static bool get enableEvasionTechniques => DynamicConfiguration.getConfig(
      'exploits', 'enable_evasion_techniques', true);
  static bool get enableMlPredictions =>
      DynamicConfiguration.getConfig('exploits', 'enable_ml_predictions', true);
  static double get defaultSuccessRateThreshold =>
      DynamicConfiguration.getConfig(
          'exploits', 'default_success_rate_threshold', 0.5);

  static bool get enableRecommendations =>
      DynamicConfiguration.getConfig('ai', 'enable_recommendations', true);
  static bool get enableAdaptiveLearning =>
      DynamicConfiguration.getConfig('ai', 'enable_adaptive_learning', true);
  static double get predictionConfidenceThreshold =>
      DynamicConfiguration.getConfig(
          'ai', 'prediction_confidence_threshold', 0.7);
}
