import 'package:flutter/material.dart';
import 'dart:io';
import '../security/file_encryption.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

/// Visor y gestor de archivos cifrados
class EncryptedFilesViewer extends StatefulWidget {
  const EncryptedFilesViewer({super.key});

  @override
  State<EncryptedFilesViewer> createState() => _EncryptedFilesViewerState();
}

class _EncryptedFilesViewerState extends State<EncryptedFilesViewer> {
  List<File> _encryptedFiles = [];
  bool _loading = true;
  String _statusMessage = 'Cargando archivos...';

  @override
  void initState() {
    super.initState();
    _loadEncryptedFiles();
  }

  Future<void> _loadEncryptedFiles() async {
    setState(() {
      _loading = true;
      _statusMessage = 'Buscando archivos cifrados...';
    });

    try {
      final directory = Directory('/sdcard/Download/');
      
      if (!await directory.exists()) {
        setState(() {
          _loading = false;
          _statusMessage = 'Directorio no encontrado';
        });
        return;
      }

      final files = directory.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.encrypted'))
          .toList();

      setState(() {
        _encryptedFiles = files;
        _loading = false;
        _statusMessage = files.isEmpty 
            ? 'No hay archivos cifrados'
            : '${files.length} archivo${files.length > 1 ? 's' : ''} cifrado${files.length > 1 ? 's' : ''}';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔐 Archivos Cifrados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEncryptedFiles,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage),
                ],
              ),
            )
          : _encryptedFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_open, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadEncryptedFiles,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header con información
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _statusMessage,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Toca un archivo para descifrarlo y verlo',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    
                    // Lista de archivos
                    Expanded(
                      child: ListView.builder(
                        itemCount: _encryptedFiles.length,
                        itemBuilder: (context, index) {
                          return _buildFileCard(_encryptedFiles[index]);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFileCard(File file) {
    final filename = file.path.split('/').last;
    final originalName = filename.replaceAll('.encrypted', '');
    final fileSize = file.lengthSync();
    final fileSizeStr = _formatFileSize(fileSize);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.lock, color: Colors.white),
        ),
        title: Text(
          originalName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Tamaño: $fileSizeStr'),
            Text('Cifrado: AES-256', style: TextStyle(color: Colors.orange[700])),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'decrypt':
                _decryptFile(file);
                break;
              case 'decrypt_share':
                _decryptAndShare(file);
                break;
              case 'delete':
                _deleteFile(file);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'decrypt',
              child: Row(
                children: [
                  Icon(Icons.lock_open, size: 20),
                  SizedBox(width: 8),
                  Text('Descifrar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'decrypt_share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 20),
                  SizedBox(width: 8),
                  Text('Descifrar y Compartir'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Eliminar', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _decryptFile(file),
      ),
    );
  }

  Future<void> _decryptFile(File encryptedFile) async {
    try {
      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Descifrando archivo...'),
            ],
          ),
        ),
      );

      // Descifrar archivo
      final decryptedFile = await FileEncryption().decryptFile(encryptedFile);

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso

        // Mostrar diálogo de éxito
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Archivo Descifrado'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('El archivo ha sido descifrado exitosamente.'),
                const SizedBox(height: 16),
                Text(
                  'Ubicación:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  decryptedFile.path,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _shareFile(decryptedFile);
                },
                icon: const Icon(Icons.share),
                label: const Text('Compartir'),
              ),
            ],
          ),
        );

        // Recargar lista
        _loadEncryptedFiles();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descifrar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _decryptAndShare(File encryptedFile) async {
    try {
      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Descifrando y preparando para compartir...'),
            ],
          ),
        ),
      );

      // Descifrar archivo
      final decryptedFile = await FileEncryption().decryptFile(encryptedFile);

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso

        // Compartir archivo
        await _shareFile(decryptedFile);

        // Recargar lista
        _loadEncryptedFiles();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareFile(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Archivo descifrado de BlueSnafer Pro',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteFile(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirmar Eliminación'),
        content: Text(
          '¿Estás seguro de que quieres eliminar este archivo?\n\n${file.path.split('/').last}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await file.delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Archivo eliminado')),
          );
        }
        
        _loadEncryptedFiles();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
