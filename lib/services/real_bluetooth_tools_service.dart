import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Servicio para herramientas Bluetooth reales del sistema
class RealBluetoothToolsService {
  static const platform = MethodChannel('com.bluesnafer_pro/bluetooth');

  /// Ejecuta análisis completo con herramientas reales del sistema
  static Future<Map<String, dynamic>> executeRealBluetoothAnalysis(
      String deviceAddress) async {
    try {
      final result =
          await platform.invokeMethod('executeRealBluetoothAnalysis', {
        'deviceAddress': deviceAddress,
      });
      return Map<String, dynamic>.from(result);
    } catch (e) {
      throw Exception('Error ejecutando análisis real: $e');
    }
  }
}

/// Servicio de análisis predictivo con IA
class PredictiveAIService {
  static const platform = MethodChannel('com.bluesnafer_pro/bluetooth');

  /// Ejecuta análisis predictivo completo
  static Future<Map<String, dynamic>> executePredictiveAIAnalysis(
      Map<String, String> deviceInfo) async {
    try {
      final result =
          await platform.invokeMethod('executePredictiveAIAnalysis', {
        'deviceInfo': deviceInfo,
      });
      return Map<String, dynamic>.from(result);
    } catch (e) {
      throw Exception('Error ejecutando análisis predictivo: $e');
    }
  }

  /// Registra un ataque para entrenamiento del modelo de IA
  static Future<void> recordAttackForAI({
    required Map<String, String> deviceInfo,
    required String attackType,
    required bool success,
    required int duration,
    required int payloadSize,
    required String responsePattern,
  }) async {
    try {
      await platform.invokeMethod('recordAttackForAI', {
        'deviceInfo': deviceInfo,
        'attackType': attackType,
        'success': success,
        'duration': duration,
        'payloadSize': payloadSize,
        'responsePattern': responsePattern,
      });
    } catch (e) {
      throw Exception('Error registrando ataque para IA: $e');
    }
  }
}

/// Widget para mostrar resultados de análisis predictivo con IA
class PredictiveAnalysisWidget extends StatefulWidget {
  final Map<String, String> deviceInfo;

  const PredictiveAnalysisWidget({super.key, required this.deviceInfo});

  @override
  State<PredictiveAnalysisWidget> createState() =>
      _PredictiveAnalysisWidgetState();
}

class _PredictiveAnalysisWidgetState extends State<PredictiveAnalysisWidget> {
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  String _statusMessage = 'Listo para análisis predictivo';

  Future<void> _executePredictiveAnalysis() async {
    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Ejecutando análisis predictivo con IA...';
    });

    try {
      final result = await PredictiveAIService.executePredictiveAIAnalysis(
          widget.deviceInfo);

      setState(() {
        _analysisResult = result;
        _statusMessage = 'Análisis predictivo completado';
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error en análisis predictivo: $e';
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              const Text(
                'ANÁLISIS PREDICTIVO CON IA',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _isAnalyzing ? Colors.orange : Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isAnalyzing ? 'ANALIZANDO' : 'LISTO',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Estado
          Text(
            _statusMessage,
            style: TextStyle(
              color: _isAnalyzing ? Colors.orange : Colors.white70,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 16),

          // Botón de análisis
          ElevatedButton.icon(
            onPressed: _isAnalyzing ? null : _executePredictiveAnalysis,
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.analytics, size: 16),
            label: Text(_isAnalyzing
                ? 'ANALIZANDO...'
                : 'EJECUTAR ANÁLISIS PREDICTIVO'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Resultados del análisis
          if (_analysisResult != null) ...[
            _buildAnalysisResults(),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisResults() {
    final prediction = _analysisResult!['prediction'] as Map<String, dynamic>?;
    final recommendations =
        _analysisResult!['recommendations'] as List<dynamic>? ?? [];
    final modelStats =
        _analysisResult!['model_statistics'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nivel de riesgo
        if (prediction != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getRiskColor(prediction['riskLevel'].toString()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(_getRiskIcon(prediction['riskLevel'].toString()),
                    color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'NIVEL DE RIESGO: ${prediction['riskLevel']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(prediction['estimatedSuccessRate'] * 100).toStringAsFixed(1)}% éxito estimado',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Vulnerabilidades predichas
          if (prediction['predictedVulnerabilities'] != null) ...[
            const Text(
              'VULNERABILIDADES PREDICHAS:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...prediction['predictedVulnerabilities'].map<Widget>(
              (vuln) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  vuln.toString(),
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Ataques recomendados
          if (prediction['recommendedAttacks'] != null) ...[
            const Text(
              'ATAQUES RECOMENDADOS:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...prediction['recommendedAttacks'].map<Widget>(
              (attack) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  attack.toString(),
                  style: const TextStyle(
                    color: Colors.purple,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],

        const SizedBox(height: 12),

        // Recomendaciones
        if (recommendations.isNotEmpty) ...[
          const Text(
            'RECOMENDACIONES DE IA:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...recommendations.map<Widget>(
            (rec) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                rec.toString(),
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Estadísticas del modelo
        if (modelStats != null) ...[
          const Text(
            'ESTADÍSTICAS DEL MODELO:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                _buildStatRow('Precisión del modelo',
                    '${(modelStats['model_accuracy'] * 100).toStringAsFixed(1)}%'),
                _buildStatRow('Ataques registrados',
                    modelStats['total_attacks_recorded'].toString()),
                _buildStatRow('Patrones de vulnerabilidad',
                    modelStats['vulnerability_patterns'].toString()),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toUpperCase()) {
      case 'CRÍTICO':
        return Colors.red;
      case 'ALTO':
        return Colors.orange;
      case 'MEDIO':
        return Colors.yellow;
      case 'BAJO':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRiskIcon(String riskLevel) {
    switch (riskLevel.toUpperCase()) {
      case 'CRÍTICO':
        return Icons.dangerous;
      case 'ALTO':
        return Icons.warning;
      case 'MEDIO':
        return Icons.info;
      case 'BAJO':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }
}


