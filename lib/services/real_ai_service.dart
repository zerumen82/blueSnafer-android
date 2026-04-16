import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/advanced_logger.dart';

/// Servicio para ejecutar comandos reales del sistema y generar modelos de IA
class RealAIService {
  static final RealAIService _instance = RealAIService._internal();
  factory RealAIService() => _instance;
  RealAIService._internal();

  bool _isGenerating = false;
  String _currentStatus = 'Listo';
  double _progress = 0.0;
  StreamSubscription? _processSubscription;

  /// Estado actual del servicio
  bool get isGenerating => _isGenerating;
  String get currentStatus => _currentStatus;
  double get progress => _progress;

  /// Stream para progreso de generación
  Stream<double> get progressStream => _progressController.stream;
  final StreamController<double> _progressController = StreamController<double>.broadcast();

  /// Genera todos los modelos de IA usando comandos reales del sistema
  Future<bool> generateAllAIModels() async {
    if (_isGenerating) return false;

    _isGenerating = true;
    _progress = 0.0;
    _currentStatus = 'Iniciando generación de modelos de IA...';

    try {
      AdvancedLogger.staticLogger.logInfo('Iniciando generación real de modelos de IA');

      // Paso 1: Verificar dependencias de Python
      _updateProgress(0.1, 'Verificando dependencias de Python...');
      final pythonCheck = await _checkPythonDependencies();
      if (!pythonCheck) {
        _currentStatus = 'Error: Dependencias de Python no disponibles';
        _isGenerating = false;
        return false;
      }

      // Paso 2: Crear directorio de modelos
      _updateProgress(0.2, 'Creando directorio de modelos...');
      await _createModelsDirectory();

      // Paso 3: Generar modelo PIN Bypass
      _updateProgress(0.3, 'Generando modelo PIN Bypass...');
      await _generatePinBypassModel();

      // Paso 4: Generar modelo de éxito de ataques
      _updateProgress(0.5, 'Generando modelo de éxito de ataques...');
      await _generateAttackSuccessModel();

      // Paso 5: Generar clasificador de dispositivos
      _updateProgress(0.7, 'Generando clasificador de dispositivos...');
      await _generateDeviceClassifier();

      // Paso 6: Generar detector de contramedidas
      _updateProgress(0.8, 'Generando detector de contramedidas...');
      await _generateCountermeasureDetector();

      // Paso 7: Generar analizador de vulnerabilidades Java
      _updateProgress(0.9, 'Generando analizador de vulnerabilidades Java...');
      await _generateJavaVulnerabilityAnalyzer();

      // Paso 8: Generar generador de exploits Java
      _updateProgress(0.95, 'Generando generador de exploits Java...');
      await _generateJavaExploitGenerator();

      // Finalización
      _updateProgress(1.0, '¡Generación de modelos completada exitosamente!');
      _currentStatus = 'Todos los modelos generados correctamente';

      _isGenerating = false;
      return true;

    } catch (e) {
      _currentStatus = 'Error durante generación: ${e.toString()}';
      _isGenerating = false;
      AdvancedLogger.staticLogger.logError('Error generando modelos de IA', {'error': e.toString()});
      return false;
    }
  }

  /// Verifica si Python y las dependencias están disponibles
  Future<bool> _checkPythonDependencies() async {
    try {
      final result = await Process.run('python', ['--version']);
      if (result.exitCode != 0) {
        return false;
      }

      // Verificar TensorFlow
      final tfResult = await Process.run('python', ['-c', 'import tensorflow as tf; print("TensorFlow OK")']);
      if (tfResult.exitCode != 0) {
        return false;
      }

      // Verificar NumPy
      final npResult = await Process.run('python', ['-c', 'import numpy as np; print("NumPy OK")']);
      if (npResult.exitCode != 0) {
        return false;
      }

      return true;

    } catch (e) {
      AdvancedLogger.staticLogger.logError('Error verificando dependencias Python', {'error': e.toString()});
      return false;
    }
  }

  /// Crea directorio de modelos si no existe
  Future<void> _createModelsDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');

      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      // También crear directorio en assets si no existe
      final assetsDir = Directory('assets/models');
      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }

    } catch (e) {
      AdvancedLogger.staticLogger.logError('Error creando directorio de modelos', {'error': e.toString()});
    }
  }

  /// Genera modelo PIN Bypass
  Future<void> _generatePinBypassModel() async {
    await _runPythonScript('create_pin_bypass_model.py', 'Generando modelo PIN Bypass...');
  }

  /// Genera modelo de éxito de ataques
  Future<void> _generateAttackSuccessModel() async {
    await _runPythonScript('create_attack_success_model.py', 'Generando modelo de éxito de ataques...');
  }

  /// Genera clasificador de dispositivos
  Future<void> _generateDeviceClassifier() async {
    await _runPythonScript('create_device_classifier.py', 'Generando clasificador de dispositivos...');
  }

  /// Genera detector de contramedidas
  Future<void> _generateCountermeasureDetector() async {
    await _runPythonScript('create_countermeasure_detector.py', 'Generando detector de contramedidas...');
  }

  /// Genera analizador de vulnerabilidades Java
  Future<void> _generateJavaVulnerabilityAnalyzer() async {
    await _runPythonScript('create_java_vulnerability_analyzer.py', 'Generando analizador de vulnerabilidades Java...');
  }

  /// Genera generador de exploits Java
  Future<void> _generateJavaExploitGenerator() async {
    await _runPythonScript('create_java_exploit_generator.py', 'Generando generador de exploits Java...');
  }

  /// Ejecuta script Python específico
  Future<void> _runPythonScript(String scriptName, String statusMessage) async {
    try {
      _currentStatus = statusMessage;

      final process = await Process.start('python', [scriptName], runInShell: true);

      // Manejar salida del proceso
      process.stdout.transform(utf8.decoder).listen((data) {
        AdvancedLogger.staticLogger.logInfo('Python stdout: $data');
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        AdvancedLogger.staticLogger.logWarning('Python stderr: $data');
      });

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        throw Exception('Script $scriptName falló con código de salida $exitCode');
      }

    } catch (e) {
      AdvancedLogger.staticLogger.logError('Error ejecutando script $scriptName', {'error': e.toString()});
      throw e;
    }
  }

  /// Actualiza progreso y notifica a listeners
  void _updateProgress(double progress, String status) {
    _progress = progress;
    _currentStatus = status;
    _progressController.add(progress);
  }

  /// Obtiene estadísticas reales de los modelos generados
  Future<Map<String, dynamic>> getModelsStats() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');

      if (!await modelsDir.exists()) {
        return {'models_count': 0, 'total_size': 0};
      }

      final files = await modelsDir.list().toList();
      int totalSize = 0;

      for (final file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }

      return {
        'models_count': files.length,
        'total_size': totalSize,
        'models_directory': modelsDir.path,
      };

    } catch (e) {
      AdvancedLogger.staticLogger.logError('Error obteniendo estadísticas de modelos', {'error': e.toString()});
      return {'error': e.toString()};
    }
  }

  /// Libera recursos
  void dispose() {
    _processSubscription?.cancel();
    _progressController.close();
  }
}
