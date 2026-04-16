import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cross_file/cross_file.dart';

/// Gestor de exportación de resultados
class ExportManager {
  static final ExportManager _instance = ExportManager._internal();
  factory ExportManager() => _instance;
  ExportManager._internal();

  /// Exportar estadísticas a JSON
  Future<File> exportToJSON() async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = prefs.getString('attack_stats');
    
    final data = {
      'app': 'BlueSnafer Pro',
      'version': '3.1.0',
      'export_date': DateTime.now().toIso8601String(),
      'attacks': statsJson != null ? jsonDecode(statsJson) : [],
    };
    
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    
    final file = await _saveToFile('bluesnafer_export.json', jsonString);
    print('[EXPORT] Exportado a JSON: ${file.path}');
    
    return file;
  }

  /// Exportar estadísticas a CSV
  Future<File> exportToCSV() async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = prefs.getString('attack_stats');
    
    if (statsJson == null) {
      throw Exception('No hay datos para exportar');
    }
    
    final attacks = List<Map<String, dynamic>>.from(jsonDecode(statsJson));
    
    // Crear CSV
    final csv = StringBuffer();
    
    // Encabezados
    csv.writeln('Fecha,Dispositivo,Dirección,Tipo,Éxito,Exploit,Archivos,Tamaño (bytes),Duración (s)');
    
    // Datos
    for (final attack in attacks) {
      final timestamp = attack['timestamp'] as int?;
      final date = timestamp != null 
          ? DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String()
          : 'N/A';
      
      final deviceName = _escapeCsv(attack['device_name']?.toString() ?? 'Unknown');
      final deviceAddress = attack['device_address']?.toString() ?? 'N/A';
      final deviceType = attack['device_type']?.toString() ?? 'N/A';
      final success = attack['success'] == true ? 'Sí' : 'No';
      final exploit = _escapeCsv(attack['exploit_used']?.toString() ?? 'N/A');
      final files = attack['files_exfiltrated']?.toString() ?? '0';
      final size = attack['size_bytes']?.toString() ?? '0';
      final duration = attack['duration_seconds']?.toString() ?? '0';
      
      csv.writeln('$date,$deviceName,$deviceAddress,$deviceType,$success,$exploit,$files,$size,$duration');
    }
    
    final file = await _saveToFile('bluesnafer_export.csv', csv.toString());
    print('[EXPORT] Exportado a CSV: ${file.path}');
    
    return file;
  }

  /// Exportar a formato HTML (reporte)
  Future<File> exportToHTML() async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = prefs.getString('attack_stats');
    
    if (statsJson == null) {
      throw Exception('No hay datos para exportar');
    }
    
    final attacks = List<Map<String, dynamic>>.from(jsonDecode(statsJson));
    
    // Calcular estadísticas
    final totalAttacks = attacks.length;
    final successfulAttacks = attacks.where((a) => a['success'] == true).length;
    final successRate = ((successfulAttacks / totalAttacks) * 100).toStringAsFixed(1);
    
    final html = '''
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BlueSnafer Pro - Reporte de Ataques</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        h1 {
            color: #667eea;
            text-align: center;
            margin-bottom: 10px;
        }
        .subtitle {
            text-align: center;
            color: #666;
            margin-bottom: 30px;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
        }
        .stat-value {
            font-size: 36px;
            font-weight: bold;
            margin: 10px 0;
        }
        .stat-label {
            font-size: 14px;
            opacity: 0.9;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th {
            background: #667eea;
            color: white;
            padding: 12px;
            text-align: left;
        }
        td {
            padding: 10px;
            border-bottom: 1px solid #ddd;
        }
        tr:hover {
            background: #f5f5f5;
        }
        .success {
            color: #4caf50;
            font-weight: bold;
        }
        .failed {
            color: #f44336;
            font-weight: bold;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #666;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛡️ BlueSnafer Pro</h1>
        <div class="subtitle">Reporte de Ataques Bluetooth</div>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-label">Total Ataques</div>
                <div class="stat-value">$totalAttacks</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Exitosos</div>
                <div class="stat-value">$successfulAttacks</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Tasa de Éxito</div>
                <div class="stat-value">$successRate%</div>
            </div>
        </div>
        
        <h2>📊 Historial de Ataques</h2>
        <table>
            <thead>
                <tr>
                    <th>Fecha</th>
                    <th>Dispositivo</th>
                    <th>Tipo</th>
                    <th>Exploit</th>
                    <th>Estado</th>
                    <th>Archivos</th>
                </tr>
            </thead>
            <tbody>
${_generateTableRows(attacks)}
            </tbody>
        </table>
        
        <div class="footer">
            Generado el ${DateTime.now().toString()}<br>
            BlueSnafer Pro v3.1.0
        </div>
    </div>
</body>
</html>
''';
    
    final file = await _saveToFile('bluesnafer_report.html', html);
    print('[EXPORT] Exportado a HTML: ${file.path}');
    
    return file;
  }

  String _generateTableRows(List<Map<String, dynamic>> attacks) {
    return attacks.map((attack) {
      final timestamp = attack['timestamp'] as int?;
      final date = timestamp != null 
          ? DateTime.fromMillisecondsSinceEpoch(timestamp).toString().split('.')[0]
          : 'N/A';
      
      final deviceName = attack['device_name']?.toString() ?? 'Unknown';
      final deviceType = attack['device_type']?.toString() ?? 'N/A';
      final exploit = attack['exploit_used']?.toString() ?? 'N/A';
      final success = attack['success'] == true;
      final statusClass = success ? 'success' : 'failed';
      final statusText = success ? '✅ Exitoso' : '❌ Fallido';
      final files = attack['files_exfiltrated']?.toString() ?? '0';
      
      return '''
                <tr>
                    <td>$date</td>
                    <td>$deviceName</td>
                    <td>$deviceType</td>
                    <td>$exploit</td>
                    <td class="$statusClass">$statusText</td>
                    <td>$files</td>
                </tr>''';
    }).join('\n');
  }

  /// Guardar archivo
  Future<File> _saveToFile(String filename, String content) async {
    final directory = Directory('/sdcard/Download/');
    
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    final file = File('${directory.path}$filename');
    await file.writeAsString(content);
    
    return file;
  }

  /// Escapar valores CSV
  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Compartir archivo exportado
  Future<void> shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Reporte de BlueSnafer Pro',
    );
  }

  /// Exportar y compartir
  Future<void> exportAndShare(String format) async {
    File file;
    
    switch (format.toLowerCase()) {
      case 'json':
        file = await exportToJSON();
        break;
      case 'csv':
        file = await exportToCSV();
        break;
      case 'html':
        file = await exportToHTML();
        break;
      default:
        throw Exception('Formato no soportado: $format');
    }
    
    await shareFile(file);
  }
}
