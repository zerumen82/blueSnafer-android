import 'dart:async';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../utils/advanced_logger.dart';

/// Servicio real para modelos TFLite utilizando la librería tflite_flutter
class TFLiteRealService {
  static final TFLiteRealService _instance = TFLiteRealService._internal();
  factory TFLiteRealService() => _instance;
  TFLiteRealService._internal();

  final Map<String, Interpreter> _interpreters = {};
  bool _isInitialized = false;

  /// Inicializar todos los modelos de IA desde assets
  Future<void> initializeAll() async {
    if (_isInitialized) return;

    final models = [
      'attack_success_model',
      'countermeasure_detector_model',
      'device_classifier_model',
      'pin_bypass_model',
      'vulnerability_model',
      'java_exploit_generator',
    ];

    for (var modelName in models) {
      try {
        final interpreter = await Interpreter.fromAsset('assets/models/$modelName.tflite');
        _interpreters[modelName] = interpreter;
        AdvancedLogger.staticLogger.logInfo('Modelo TFLite cargado: $modelName');
      } catch (e) {
        AdvancedLogger.staticLogger.logError('Error cargando modelo $modelName: $e');
      }
    }

    _isInitialized = true;
  }

  /// Ejecutar inferencia real sobre un modelo específico
  Future<List<double>> runInference(String modelName, List<double> input) async {
    if (!_isInitialized) {
      await initializeAll();
    }

    final interpreter = _interpreters[modelName];
    if (interpreter == null) {
      AdvancedLogger.staticLogger.logWarning('Intérprete no encontrado para: $modelName');
      return List<double>.filled(10, 0.0);
    }

    try {
      // Preparar entrada (TensorFloat)
      var inputTensor = Float32List.fromList(input).buffer.asFloat32List();
      
      // Obtener forma de salida del modelo
      var outputShape = interpreter.getOutputTensor(0).shape;
      var outputSize = outputShape.reduce((a, b) => a * b);
      var output = Float32List(outputSize).buffer.asFloat32List();

      // Ejecutar inferencia
      interpreter.run(inputTensor, output);
      
      return output.toList();
    } catch (e) {
      AdvancedLogger.staticLogger.logError('Error en inferencia TFLite ($modelName): $e');
      return List<double>.filled(10, 0.0);
    }
  }

  /// Obtener estadísticas de los modelos cargados
  Map<String, dynamic> getServiceStats() {
    return {
      'loadedModels': _interpreters.length,
      'isInitialized': _isInitialized,
      'modelNames': _interpreters.keys.toList(),
    };
  }

  /// Liberar recursos de los intérpretes
  void dispose() {
    for (var interpreter in _interpreters.values) {
      interpreter.close();
    }
    _interpreters.clear();
    _isInitialized = false;
  }

  List<String> getLoadedModels() => _interpreters.keys.toList();
}
