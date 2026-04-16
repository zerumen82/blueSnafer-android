import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'file_access_screen.dart';
import 'services/real_exploit_service.dart';
import 'utils/device_utils.dart' as device_utils;

/// Pantalla simplificada para usuarios no avanzados
/// Flujo: Escanear → Atacar → Ver Archivos
class SimpleAttackScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const SimpleAttackScreen({super.key, required this.device});

  @override
  State<SimpleAttackScreen> createState() => _SimpleAttackScreenState();
}

class _SimpleAttackScreenState extends State<SimpleAttackScreen> {
  final RealExploitService _exploitService = RealExploitService();

  // Estados simples
  int _currentStep = 0; // 0: Analizando, 1: Listo, 2: Atacando, 3: Éxito
  String _statusMessage = 'Analizando dispositivo...';
  bool _canAttack = false;
  List<String> _simpleLog = [];
  double _attackProgress = 0.0;

  // Información del dispositivo
  int _vulnerabilityCount = 0;
  List<String> _availableExploits = [];

  @override
  void initState() {
    super.initState();
    _analyzeDevice();
  }

  /// PASO 1: Analizar dispositivo automáticamente usando el servicio real
  Future<void> _analyzeDevice() async {
    setState(() {
      _currentStep = 0;
      _statusMessage = 'Analizando dispositivo...';
      _simpleLog.add('📡 Conectando y analizando servicios...');
    });

    try {
      // Usamos el servicio de exploits real que ya implementamos
      final result = await _exploitService.executeAttack(
        deviceAddress: widget.device['address'],
        type: 'basic', // El tipo 'basic' ejecuta el AdvancedBLEExploits real
      );

      if (result['success'] == true) {
        final analysis = result['analysis'] as Map<dynamic, dynamic>?;
        final vulns = List<String>.from(analysis?['vulnerabilities'] ?? []);

        setState(() {
          _vulnerabilityCount = vulns.length;
          _availableExploits = vulns;
          _canAttack = _vulnerabilityCount > 0;
          _currentStep = 1;
          _statusMessage = _canAttack ? '✅ Dispositivo vulnerable' : '⚠️ Dispositivo seguro';
          _simpleLog.add('✅ Análisis real completado');
          _simpleLog.add('📊 Vulnerabilidades detectadas: $_vulnerabilityCount');
        });
      } else {
        throw Exception(result['message'] ?? 'Fallo en la conexión');
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error en análisis';
        _simpleLog.add('❌ Error real: $e');
        _canAttack = false;
        _currentStep = 1;
      });
    }
  }

  /// PASO 2: Ejecutar ataque automático real
  Future<void> _executeAutoAttack() async {
    if (!_canAttack) return;

    setState(() {
      _currentStep = 2;
      _statusMessage = '⚔️ Ejecutando exploit real...';
      _simpleLog.add('⚔️ Iniciando ataque sobre servicios detectados...');
    });

    try {
      // Ejecutar un ataque de inundación (DoS) como ejemplo de ataque automático
      final result = await _exploitService.executeDoS(widget.device['address'], 5);

      if (result['success'] == true) {
        setState(() {
          _currentStep = 3;
          _statusMessage = '✅ ¡Ataque exitoso!';
          _simpleLog.add('✅ El dispositivo ha sido saturado correctamente');
        });
        
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) _showSuccessDialog();
      } else {
        throw Exception(result['message'] ?? 'El ataque fue bloqueado');
      }
    } catch (e) {
      setState(() {
        _currentStep = 1;
        _statusMessage = '❌ Ataque fallido';
        _simpleLog.add('❌ Error técnico: $e');
      });
    }
  }

  /// PASO 3: Acceder a archivos
  void _accessFiles() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FileAccessScreen(device: widget.device),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              '¡Éxito!',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ],
        ),
        content: const Text(
          'Has obtenido acceso al dispositivo.\n\n¿Qué quieres hacer ahora?',
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _accessFiles();
              },
              icon: const Icon(Icons.folder_open, size: 28),
              label: const Text(
                'VER ARCHIVOS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = device_utils.getDeviceDisplayName(widget.device);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: Text(deviceName),
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Indicador de progreso visual
            _buildProgressIndicator(),

            // Estado actual
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color: _getStatusColor().withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_currentStep == 1 && _vulnerabilityCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$_vulnerabilityCount vulnerabilidades detectadas',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  // Barra de progreso durante ataque
                  if (_currentStep == 2 && _attackProgress > 0) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        value: _attackProgress,
                        backgroundColor: Colors.white24,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_getStatusColor()),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_attackProgress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Botón principal
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildMainButton(),
            ),

            // Log simplificado
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'ACTIVIDAD',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    Expanded(
                      child: _simpleLog.isEmpty
                          ? const Center(
                              child: Text(
                                'Sin actividad aún...',
                                style: TextStyle(color: Colors.white38),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _simpleLog.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    _simpleLog[index],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: [
          _buildProgressStep(1, 'Analizar', _currentStep >= 1),
          _buildProgressLine(_currentStep >= 2),
          _buildProgressStep(2, 'Atacar', _currentStep >= 2),
          _buildProgressLine(_currentStep >= 3),
          _buildProgressStep(3, 'Acceder', _currentStep >= 3),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEB1555) : Colors.white24,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '$step',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: isActive ? const Color(0xFFEB1555) : Colors.white24,
      ),
    );
  }

  Widget _buildMainButton() {
    String buttonText;
    IconData buttonIcon;
    VoidCallback? onPressed;
    bool isLoading = false;

    switch (_currentStep) {
      case 0: // Analizando
        buttonText = 'ANALIZANDO...';
        buttonIcon = Icons.search;
        onPressed = null;
        isLoading = true;
        break;
      case 1: // Análisis completado
        buttonText = _canAttack ? 'INICIAR ATAQUE' : 'REINTENTAR ANÁLISIS';
        buttonIcon = _canAttack ? Icons.flash_on : Icons.refresh;
        onPressed = _canAttack ? _executeAutoAttack : _analyzeDevice;
        break;
      case 2: // Atacando
        buttonText = 'ATACANDO...';
        buttonIcon = Icons.security;
        onPressed = null;
        isLoading = true;
        break;
      case 3: // Éxito
        buttonText = 'VER ARCHIVOS';
        buttonIcon = Icons.folder_open;
        onPressed = _accessFiles;
        break;
      default:
        buttonText = 'ERROR';
        buttonIcon = Icons.error;
        onPressed = null;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(buttonIcon, size: 28),
        label: Text(
          buttonText,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _getButtonColor(),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_currentStep) {
      case 0:
        return Colors.blue;
      case 1:
        return _canAttack ? Colors.orange : Colors.red;
      case 2:
        return Colors.purple;
      case 3:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (_currentStep) {
      case 0:
        return Icons.search;
      case 1:
        return _canAttack ? Icons.warning : Icons.shield;
      case 2:
        return Icons.flash_on;
      case 3:
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  Color _getButtonColor() {
    if (_currentStep == 3) return Colors.green;
    if (_currentStep == 1 && !_canAttack) return Colors.grey;
    return const Color(0xFFEB1555);
  }
}


