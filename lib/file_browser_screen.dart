import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/real_exploit_service.dart';
import 'utils/device_utils.dart' as device_utils;

class FileBrowserScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const FileBrowserScreen({
    super.key,
    required this.device,
  });

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  final RealExploitService _exploitService = RealExploitService();
  
  List<FileItem> _files = [];
  bool _loading = false;
  String _currentPath = '/DCIM';
  final Set<String> _selectedFiles = {};

  @override
  void initState() {
    super.initState();
    _loadRealFiles();
  }

  Future<void> _loadRealFiles() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final result = await _exploitService.exfiltrateFiles(widget.device['address']);

      if (!mounted) return;
      // Kotlin returns files nested inside result['data']['files']
      final data = result['data'] as Map?;
      final rawFiles = (data?['files'] as List?) ?? (result['files'] as List?);
      
      if (!mounted) return;
      if (result['success'] == true && rawFiles != null) {
        // Parsear datos REALES del OBEX XML
        final realFiles = rawFiles.map<FileItem>((f) {
          final map = f as Map;
          return FileItem(
            name: map['name']?.toString() ?? 'unknown',
            path: map['path']?.toString() ?? map['name']?.toString() ?? 'unknown',
            isDirectory: map['type']?.toString() == 'directory',
            size: int.tryParse(map['size']?.toString() ?? '0') ?? 0,
          );
        }).toList();

        setState(() {
          _files = realFiles;
          _loading = false;
        });

        if (realFiles.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${realFiles.length} archivos reales encontrados', style: const TextStyle(fontSize: 12)),
              backgroundColor: Colors.green[900],
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception(result['error'] ?? result['message'] ?? 'Fallo en la conexión OBEX');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error OBEX: $e')),
        );
      }
    }
  }

  Future<void> _downloadSelected() async {
    if (_selectedFiles.isEmpty || !mounted) return;

    setState(() => _loading = true);

    try {
      int successCount = 0;
      for (String filePath in _selectedFiles) {
        if (!mounted) break;
        final fileName = filePath.split('/').last;
        final result = await _exploitService.downloadFile(widget.device['address'], fileName);

        if (result['success'] == true) {
          successCount++;
        }
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _selectedFiles.clear();
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('✓ Transferencia Completa'),
          content: Text('Se han descargado $successCount archivos correctamente.\n\nUbicación: Carpeta de Descargas'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en descarga: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device_utils.getDeviceDisplayName(widget.device), style: const TextStyle(fontSize: 16)),
            Text(_currentPath, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : _files.isEmpty
              ? const Center(
                  child: Text(
                    'Sin archivos - Conectando a servicio OBEX...',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    final isSelected = _selectedFiles.contains(file.path);
                    
                    return ListTile(
                      leading: Icon(
                        file.isDirectory ? Icons.folder : _getFileIcon(file.name),
                        color: file.isDirectory ? Colors.amber : Colors.cyanAccent,
                      ),
                      title: Text(
                        file.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        file.isDirectory ? 'Directorio' : _formatSize(file.size),
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: file.isDirectory
                          ? const Icon(Icons.chevron_right, color: Colors.grey)
                          : Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedFiles.add(file.path);
                                  } else {
                                    _selectedFiles.remove(file.path);
                                  }
                                });
                              },
                              activeColor: Colors.cyanAccent,
                            ),
                      onTap: () {
                        if (file.isDirectory) {
                          setState(() {
                            _currentPath = file.path;
                            _loadRealFiles();
                          });
                        } else {
                          setState(() {
                            if (_selectedFiles.contains(file.path)) {
                              _selectedFiles.remove(file.path);
                            } else {
                              _selectedFiles.add(file.path);
                            }
                          });
                        }
                      },
                    );
                  },
                ),
      floatingActionButton: _selectedFiles.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _downloadSelected,
              backgroundColor: Colors.cyanAccent,
              icon: const Icon(Icons.download, color: Colors.black),
              label: const Text('DESCARGAR', style: TextStyle(color: Colors.black)),
            )
          : null,
    );
  }

  IconData _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
      case 'txt':
        return Icons.description;
      case 'mp4':
      case 'avi':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
  });

  factory FileItem.fromMap(Map<dynamic, dynamic> map) {
    return FileItem(
      name: map['name'] ?? '',
      path: map['path'] ?? '',
      isDirectory: map['isDirectory'] ?? false,
      size: map['size'] ?? 0,
    );
  }
}
