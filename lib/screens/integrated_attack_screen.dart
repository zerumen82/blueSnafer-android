import 'package:flutter/material.dart';
import '../services/integrated_ai_service.dart';
// import '../services/tflite_ai_service.dart';
import '../models/tflite_models.dart';
import '../utils/advanced_logger.dart';
import '../utils/device_utils.dart' as device_utils;

/// Pantalla integrada que utiliza modelos TFLite reales en el flujo de ataque completo
class IntegratedAttackScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const IntegratedAttackScreen({Key? key, required this.device}) : super(key: key);

  @override
  _IntegratedAttackScreenState createState() => _IntegratedAttackScreenState();
}

class _IntegratedAttackScreenState extends State<IntegratedAttackScreen> {
  final IntegratedAIService _aiService = IntegratedAIService();

  bool _isInitialized = false;
  bool _isAnalyzing = false;
  bool _isGeneratingExploits = false;

  String _statusMessage = 'Sistema listo para análisis con modelos TFLite';
  String _currentStep = '';

  // Resultados del análisis
  CompleteSecurityAnalysis? _analysisResult;
  List<GeneratedExploit> _generatedExploits = [];
  OptimalAttackExecution? _attackExecution;

  // Datos del dispositivo para análisis
  final Map<String, dynamic> _deviceData = {};

  @override
  void initState() {
    super.initState();
    _initializeDeviceData();
    _initializeAIService();
  }

  void _initializeDeviceData() {
    // Preparar datos del dispositivo para análisis TFLite
    _deviceData.addAll({
      'bluetooth_version': 5.0,
      'android_version': 11.0,
      'has_ble': true,
      'has_obex': true,
      'has_ftp': false,
      'no_pairing_auth': true,
      'android_version_lt_10': false,
      'bluetooth_version_lt_5': false,
      'manufacturer_samsung': device_utils.getManufacturer(widget.device['address'] ?? '') == 'SAMSUNG',
      'manufacturer_xiaomi': device_utils.getManufacturer(widget.device['address'] ?? '') == 'XIAOMI',
      'services_gatt': true,
      'services_spp': false,
      'device_address': widget.device['address'],
      'device_name': device_utils.getDeviceDisplayName(widget.device),
      'platform': 'android',
    });
  }

  Future<void> _initializeAIService() async {
    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Inicializando modelos TFLite...';
      _currentStep = 'Inicialización';
    });

    try {
      await _aiService.initializeAll();

      setState(() {
        _isInitialized = true;
        _isAnalyzing = false;
        _statusMessage = 'Modelos TFLite inicializados correctamente';
      });

      AdvancedLogger.staticLogger.logInfo('Servicio integrado inicializado exitosamente');
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _statusMessage = 'Error inicializando modelos TFLite: ${e.toString()}';
      });
      AdvancedLogger.staticLogger.logError('Error inicializando servicio integrado', {'error': e.toString()});
    }
  }

  Future<void> _runCompleteAnalysis() async {
    if (!_isInitialized) return;

    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Ejecutando análisis completo con modelos TFLite...';
      _currentStep = 'Análisis completo';
      _analysisResult = null;
    });

    try {
      final analysis = await _aiService.runCompleteSecurityAnalysis(
        deviceAddress: widget.device['address'],
        deviceData: _deviceData,
      );

      setState(() {
        _analysisResult = analysis;
        _isAnalyzing = false;
        _statusMessage = 'Análisis completado - Confianza general: ${(analysis.confidence * 100).toStringAsFixed(1)}%';
      });

      AdvancedLogger.staticLogger.logInfo('Análisis completo ejecutado exitosamente',
          {'confidence': analysis.confidence, 'device': widget.device['address']});

    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _statusMessage = 'Error en análisis: ${e.toString()}';
      });
      AdvancedLogger.staticLogger.logError('Error en análisis completo', {'error': e.toString()});
    }
  }

  Future<void> _generateOptimalExploits() async {
    if (_analysisResult == null) return;

    setState(() {
      _isGeneratingExploits = true;
      _statusMessage = 'Generando exploits óptimos basados en análisis...';
      _currentStep = 'Generación de exploits';
      _generatedExploits = [];
    });

    try {
      final exploits = await _aiService.generateOptimalExploits(
        analysis: _analysisResult!,
        targetPlatform: _deviceData['platform'],
      );

      setState(() {
        _generatedExploits = exploits;
        _isGeneratingExploits = false;
        _statusMessage = '${exploits.length} exploits generados basados en modelos TFLite';
      });

      AdvancedLogger.staticLogger.logInfo('Exploits generados exitosamente', {'count': exploits.length});

    } catch (e) {
      setState(() {
        _isGeneratingExploits = false;
        _statusMessage = 'Error generando exploits: ${e.toString()}';
      });
      AdvancedLogger.staticLogger.logError('Error generando exploits', {'error': e.toString()});
    }
  }

  Future<void> _executeOptimalAttack() async {
    if (_analysisResult == null || _generatedExploits.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Ejecutando ataque óptimo basado en modelos TFLite...';
      _currentStep = 'Ejecución de ataque';
      _attackExecution = null;
    });

    try {
      final execution = await _aiService.executeOptimalAttack(
        deviceAddress: widget.device['address'],
        deviceData: _deviceData,
      );

      setState(() {
        _attackExecution = execution;
        _isAnalyzing = false;
        _statusMessage = execution.success
            ? 'Ataque ejecutado exitosamente con modelo TFLite'
            : 'Ataque no pudo ejecutarse: ${execution.message}';
      });

      AdvancedLogger.staticLogger.logInfo('Ataque óptimo ejecutado',
          {'success': execution.success, 'device': widget.device['address']});

    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _statusMessage = 'Error ejecutando ataque: ${e.toString()}';
      });
      AdvancedLogger.staticLogger.logError('Error ejecutando ataque óptimo', {'error': e.toString()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ataque Integrado TFLite - ${device_utils.getDeviceDisplayName(widget.device)}'),
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        color: const Color(0xFF0A0E21),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información del dispositivo
              _buildDeviceInfo(),

              const SizedBox(height: 24),

              // Estado del sistema
              _buildSystemStatus(),

              const SizedBox(height: 24),

              // Botones de acción
              if (!_isAnalyzing && !_isGeneratingExploits) ...[
                _buildActionButton(
                  '🔍 ANÁLISIS COMPLETO',
                  'Ejecutar análisis completo con modelos TFLite',
                  _runCompleteAnalysis,
                  Colors.blue,
                ),

                if (_analysisResult != null) ...[
                  const SizedBox(height: 16),
                  _buildActionButton(
                    '⚔️ GENERAR EXPLOITS',
                    'Generar exploits óptimos basados en análisis',
                    _generateOptimalExploits,
                    Colors.orange,
                  ),

                  if (_generatedExploits.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildActionButton(
                      '🚀 EJECUTAR ATAQUE',
                      'Ejecutar ataque óptimo con modelos TFLite',
                      _executeOptimalAttack,
                      Colors.red,
                    ),
                  ],
                ],
              ] else
                _buildLoadingIndicator(),

              const SizedBox(height: 24),

              // Resultados del análisis
              if (_analysisResult != null) _buildAnalysisResults(),

              // Exploits generados
              if (_generatedExploits.isNotEmpty) _buildGeneratedExploits(),

              // Ejecución de ataque
              if (_attackExecution != null) _buildAttackExecution(),

              const SizedBox(height: 24),

              // Información técnica
              _buildTechnicalInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dispositivo Objetivo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Nombre: ${device_utils.getDeviceDisplayName(widget.device)}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            'Dirección: ${widget.device['address']}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            'RSSI: ${widget.device['rssi'] ?? 0} dBm',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isInitialized ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isInitialized ? Colors.green : Colors.orange,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isInitialized ? Icons.check_circle : Icons.warning,
                color: _isInitialized ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 12),
              Text(
                _isInitialized ? 'Modelos TFLite Cargados' : 'Modelos No Inicializados',
                style: TextStyle(
                  color: _isInitialized ? Colors.green : Colors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          if (_currentStep.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Paso actual: $_currentStep',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, String subtitle, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFFEB1555),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Procesando con modelos TFLite...',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResults() {
    if (_analysisResult == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resultados del Análisis TFLite',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Predicción PIN Bypass
          _buildPredictionCard(
            '🔒 PIN Bypass',
            _analysisResult!.pinBypassPrediction.isVulnerable ? 'VULNERABLE' : 'SEGURO',
            _analysisResult!.pinBypassPrediction.confidence,
            _analysisResult!.pinBypassPrediction.isVulnerable ? Colors.red : Colors.green,
          ),

          const SizedBox(height: 12),

          // Predicción éxito ataques
          _buildPredictionCard(
            '⚔️ Éxito de Ataques',
            '${(_analysisResult!.attackSuccessPrediction.overallSuccessScore * 100).toStringAsFixed(1)}%',
            _analysisResult!.attackSuccessPrediction.overallSuccessScore,
            _analysisResult!.attackSuccessPrediction.overallSuccessScore > 0.7 ? Colors.green : Colors.orange,
          ),

          const SizedBox(height: 12),

          // Clasificación dispositivo
          _buildPredictionCard(
            '📱 Clasificación',
            _analysisResult!.deviceClassification.deviceCategory.toUpperCase(),
            _analysisResult!.deviceClassification.confidence,
            Colors.blue,
          ),

          const SizedBox(height: 12),

          // Contramedidas
          _buildCountermeasuresCard(),
        ],
      ),
    );
  }

  Widget _buildPredictionCard(String title, String value, double confidence, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${(confidence * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountermeasuresCard() {
    final countermeasures = _analysisResult!.detectedCountermeasures;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🛡️ Contramedidas Detectadas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            countermeasures.detectedCountermeasures.isEmpty
                ? 'No se detectaron contramedidas específicas'
                : countermeasures.detectedCountermeasures.join(', '),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedExploits() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Exploits Generados por Modelos TFLite',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._generatedExploits.map((exploit) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      exploit.vulnerabilityType.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(exploit.estimatedSuccessRate * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Plataforma: ${exploit.targetPlatform}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  'Complejidad: ${exploit.complexityLevel}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildAttackExecution() {
    if (_attackExecution == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _attackExecution!.success ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _attackExecution!.success ? Colors.green : Colors.red,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _attackExecution!.success ? Icons.check_circle : Icons.error,
                color: _attackExecution!.success ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 12),
              Text(
                _attackExecution!.success ? 'Ataque Ejecutado' : 'Ataque Fallido',
                style: TextStyle(
                  color: _attackExecution!.success ? Colors.green : Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _attackExecution!.message ?? 'Estado del ataque',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'Duración del análisis: ${_attackExecution!.analysisDuration.inSeconds}s',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información Técnica',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildTechInfoRow('Modelos TFLite Cargados', '6 modelos'),
          _buildTechInfoRow('Caché de Predicciones', '${_aiService.getSystemStats().then((stats) => stats.cacheStats?['predictions_cached'] ?? 0)} entradas'),
          _buildTechInfoRow('Caché de Ataques', '${_aiService.getSystemStats().then((stats) => stats.cacheStats?['attacks_cached'] ?? 0)} entradas'),
          _buildTechInfoRow('Caché de Exploits', '${_aiService.getSystemStats().then((stats) => stats.cacheStats?['exploits_cached'] ?? 0)} entradas'),
        ],
      ),
    );
  }

  Widget _buildTechInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }
}


