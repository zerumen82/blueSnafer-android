import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/advanced_logger.dart';
import 'tflite_real_service.dart';

class RealAIService {
  static final RealAIService _instance = RealAIService._internal();
  factory RealAIService() => _instance;
  RealAIService._internal();

  final TFLiteRealService _tfliteService = TFLiteRealService();
  bool _isGenerating = false;
  String _currentStatus = 'Listo';
  double _progress = 0.0;
  bool _modelsLoaded = false;

  bool get isGenerating => _isGenerating;
  String get currentStatus => _currentStatus;
  double get progress => _progress;
  bool get modelsLoaded => _modelsLoaded;

  Stream<double> get progressStream => _progressController.stream;
  final StreamController<double> _progressController = StreamController<double>.broadcast();

  Future<bool> generateAllAIModels() async {
    if (_isGenerating) return false;
    if (_modelsLoaded) return true;

    _isGenerating = true;
    _progress = 0.0;
    _currentStatus = 'Cargando modelos TFLite desde assets...';

    try {
      AdvancedLogger.staticLogger.logInfo('Cargando modelos TFLite desde assets...');

      _updateProgress(0.2, 'Inicializando servicio TFLite...');
      await _tfliteService.initializeAll();

      _updateProgress(0.5, 'Verificando modelos cargados...');
      final loadedModels = _tfliteService.getLoadedModels();
      
      _updateProgress(0.8, 'Verificando integración...');
      _currentStatus = 'Modelos TFLite cargados correctamente';
      
      _updateProgress(1.0, '¡Modelos TFLite cargados!');
      _modelsLoaded = true;
      _isGenerating = false;

      AdvancedLogger.staticLogger.logInfo('Modelos TFLite cargados: ${loadedModels.length}');
      return true;

    } catch (e) {
      _currentStatus = 'Error cargando modelos: ${e.toString()}';
      _isGenerating = false;
      AdvancedLogger.staticLogger.logError('Error cargando modelos TFLite', {'error': e.toString()});
      return false;
    }
  }

  Future<Map<String, dynamic>> runModelInference(String modelName, List<double> input) async {
    if (!_modelsLoaded) {
      await generateAllAIModels();
    }

    try {
      final results = await _tfliteService.runInference(modelName, input);
      return {
        'success': true,
        'results': results,
        'model': modelName,
      };
    } catch (e) {
      AdvancedLogger.staticLogger.logError('Error en inferencia', {'error': e.toString()});
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getModelsStats() async {
    try {
      final stats = _tfliteService.getServiceStats();
      final appDir = await getApplicationDocumentsDirectory();
      
      return {
        'loadedModels': stats['loadedModels'] ?? 0,
        'modelNames': stats['modelNames'] ?? [],
        'isInitialized': stats['isInitialized'] ?? false,
        'assetsPath': '${appDir.path}/assets/models',
      };
    } catch (e) {
      AdvancedLogger.staticLogger.logError('Error obteniendo estadísticas', {'error': e.toString()});
      return {'error': e.toString()};
    }
  }

  Future<List<String>> getAvailableModels() async {
    if (!_modelsLoaded) {
      await generateAllAIModels();
    }
    return _tfliteService.getLoadedModels();
  }

  void _updateProgress(double progress, String status) {
    _progress = progress;
    _currentStatus = status;
    _progressController.add(progress);
  }

  void dispose() {
    _tfliteService.dispose();
    _progressController.close();
  }
}
