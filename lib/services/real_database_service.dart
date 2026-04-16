import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Gestor de Evidencias REAL para misiones autónomas.
/// Guarda volcados de memoria, contactos y metadatos de archivos.
class RealDatabaseService {
  static final RealDatabaseService _instance = RealDatabaseService._internal();
  factory RealDatabaseService() => _instance;
  RealDatabaseService._internal();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Guardar evidencia de ataque
  Future<void> saveEvidence({
    required String targetAddress,
    required String type,
    required dynamic data,
  }) async {
    final path = await _localPath;
    final file = File('$path/evidences.json');
    
    List<Map<String, dynamic>> currentEvidences = [];
    if (await file.exists()) {
      final content = await file.readAsString();
      currentEvidences = List<Map<String, dynamic>>.from(json.decode(content));
    }

    currentEvidences.add({
      'timestamp': DateTime.now().toIso8601String(),
      'target': targetAddress,
      'type': type,
      'data': data,
    });

    await file.writeAsString(json.encode(currentEvidences));
  }

  /// Listar todas las evidencias capturadas
  Future<List<Map<String, dynamic>>> getEvidences() async {
    final path = await _localPath;
    final file = File('$path/evidences.json');
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    return List<Map<String, dynamic>>.from(json.decode(content));
  }
}
