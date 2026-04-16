import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme_manager.dart';
import '../security/auto_destruct.dart';
import '../utils/export_manager.dart';
import 'encrypted_files_viewer.dart';
import 'exploit_config_screen.dart';
import '../services/bluetooth_service.dart';

/// Pantalla de configuración
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoDestructEnabled = false;
  Duration? _remainingTime;
  bool _encryptFiles = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final remaining = await AutoDestruct().getRemainingTime();
    setState(() {
      _autoDestructEnabled = remaining != null;
      _remainingTime = remaining;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Configuración'),
      ),
      body: ListView(
        children: [
          // Sección: Apariencia
          _buildSectionHeader('🎨 Apariencia', theme),
          _buildThemeSwitch(isDark),
          const Divider(),

          // Sección: Seguridad
          _buildSectionHeader('🔒 Seguridad', theme),
          _buildEncryptionSwitch(),
          _buildAutoDestructSwitch(),
          if (_autoDestructEnabled) _buildAutoDestructInfo(),
          const Divider(),

          // Sección: Configuración de Exploits
          _buildSectionHeader('🛠️ Configuración de Exploits', theme),
          _buildConfigSection(),
          const Divider(),

          // Sección: Exportar
          _buildSectionHeader('📤 Exportar Datos', theme),
          _buildExportButton('JSON', Icons.code, Colors.blue),
          _buildExportButton('CSV', Icons.table_chart, Colors.green),
          _buildExportButton('HTML', Icons.web, Colors.orange),
          const Divider(),

          // Sección: Acerca de
          _buildSectionHeader('ℹ️ Acerca de', theme),
          _buildAboutTile(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThemeSwitch(bool isDark) {
    return SwitchListTile(
      title: const Text('Modo Oscuro'),
      subtitle: Text(isDark ? 'Tema oscuro activado' : 'Tema claro activado'),
      value: isDark,
      secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
      onChanged: (value) async {
        await ThemeManager().toggleTheme();
        setState(() {});
      },
    );
  }

  Widget _buildEncryptionSwitch() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Cifrar Archivos'),
          subtitle: const Text('Cifrar archivos exfiltrados automáticamente'),
          value: _encryptFiles,
          secondary: const Icon(Icons.lock),
          onChanged: (value) async {
            setState(() => _encryptFiles = value);
            // Guardar preferencia
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('encrypt_files', value);
          },
        ),
        ListTile(
          leading: const Icon(Icons.folder_special),
          title: const Text('Ver Archivos Cifrados'),
          subtitle: const Text('Descifrar y gestionar archivos'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EncryptedFilesViewer()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAutoDestructSwitch() {
    return SwitchListTile(
      title: const Text('Auto-Destrucción'),
      subtitle: Text(
        _autoDestructEnabled 
            ? 'Activado - Datos se eliminarán automáticamente'
            : 'Desactivado - Los datos permanecen',
      ),
      value: _autoDestructEnabled,
      secondary: const Icon(Icons.delete_forever),
      onChanged: (value) async {
        if (value) {
          await _showAutoDestructDialog();
        } else {
          await AutoDestruct().disable();
          setState(() {
            _autoDestructEnabled = false;
            _remainingTime = null;
          });
        }
      },
    );
  }

  Widget _buildAutoDestructInfo() {
    if (_remainingTime == null) return const SizedBox.shrink();

    final hours = _remainingTime!.inHours;
    final minutes = _remainingTime!.inMinutes.remainder(60);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⏰ Tiempo restante',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '$hours horas, $minutes minutos',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showExtendTimeDialog,
            child: const Text('Extender'),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(String format, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text('Exportar a $format'),
      subtitle: Text('Guardar estadísticas en formato $format'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _exportData(format),
    );
  }

  Widget _buildConfigSection() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.settings_applications),
          title: const Text('Configuración Avanzada'),
          subtitle: const Text('Personalizar parámetros de exploits'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ExploitConfigScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Restablecer a Valores por Defecto'),
          subtitle: const Text('Restablecer todos los parámetros a valores predeterminados'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showResetConfigDialog(),
        ),
      ],
    );
  }

  Future<void> _showResetConfigDialog() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Restablecer Configuración'),
        content: const Text(
          '¿Estás seguro de que quieres restablecer todos los parámetros a sus valores por defecto?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restablecer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldReset == true) {
      try {
        // Mostrar loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Restablecer configuración
        final result = await BluetoothService().resetConfig();

        if (mounted) {
          Navigator.pop(context); // Cerrar loading
          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Configuración restablecida'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Error al restablecer configuración'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Cerrar loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildAboutTile() {
    return ListTile(
      leading: const Icon(Icons.info),
      title: const Text('BlueSnafer Pro'),
      subtitle: const Text('Versión 3.1.0\nHerramienta de seguridad Bluetooth'),
      isThreeLine: true,
      onTap: _showAboutDialog,
    );
  }

  Future<void> _showAutoDestructDialog() async {
    final duration = await showDialog<Duration>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⏰ Auto-Destrucción'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Selecciona cuándo se eliminarán automáticamente los datos:',
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('1 hora'),
              onTap: () => Navigator.pop(context, const Duration(hours: 1)),
            ),
            ListTile(
              title: const Text('6 horas'),
              onTap: () => Navigator.pop(context, const Duration(hours: 6)),
            ),
            ListTile(
              title: const Text('24 horas'),
              onTap: () => Navigator.pop(context, const Duration(hours: 24)),
            ),
            ListTile(
              title: const Text('7 días'),
              onTap: () => Navigator.pop(context, const Duration(days: 7)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (duration != null) {
      await AutoDestruct().enable(duration: duration);
      await _loadSettings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-destrucción activada: ${_formatDuration(duration)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showExtendTimeDialog() async {
    final extension = await showDialog<Duration>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⏰ Extender Tiempo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('+1 hora'),
              onTap: () => Navigator.pop(context, const Duration(hours: 1)),
            ),
            ListTile(
              title: const Text('+6 horas'),
              onTap: () => Navigator.pop(context, const Duration(hours: 6)),
            ),
            ListTile(
              title: const Text('+24 horas'),
              onTap: () => Navigator.pop(context, const Duration(hours: 24)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (extension != null) {
      await AutoDestruct().extendTime(extension);
      await _loadSettings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tiempo extendido: ${_formatDuration(extension)}'),
          ),
        );
      }
    }
  }

  Future<void> _exportData(String format) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await ExportManager().exportAndShare(format);

      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportado a $format exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'BlueSnafer Pro',
      applicationVersion: '3.1.0',
      applicationIcon: const Icon(Icons.bluetooth, size: 48),
      children: [
        const Text(
          'Herramienta avanzada de seguridad Bluetooth para pruebas de penetración.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Características:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const Text('• 11+ exploits reales'),
        const Text('• 7 sistemas avanzados'),
        const Text('• Cifrado de archivos'),
        const Text('• Auto-destrucción'),
        const Text('• Estadísticas detalladas'),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final days = duration.inDays;
    
    if (days > 0) {
      return '$days día${days > 1 ? 's' : ''}';
    } else {
      return '$hours hora${hours > 1 ? 's' : ''}';
    }
  }
}


