import 'package:flutter/material.dart';
import 'services/permission_service.dart';
import 'screens/welcome_screen.dart';

/// Pantalla de solicitud de permisos iniciales
class PermissionRequestScreen extends StatefulWidget {
  const PermissionRequestScreen({super.key});

  @override
  State<PermissionRequestScreen> createState() => _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> with WidgetsBindingObserver {
  bool _isRequesting = false;
  bool _allGranted = false;
  Map<String, bool> _permissionStatus = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refrescar permisos cuando la app vuelve a primer plano
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _checkPermissions();
        }
      });
    }
  }

  Future<void> _checkPermissions() async {
    final status = await PermissionService.checkPermissions();
    if (mounted) {
      setState(() {
        _permissionStatus = status;
        
        // CORRECCIÓN: Usar AND para Android 12+ (requiere AMBOS permisos)
        final bluetoothScanOk = status['bluetoothScan'] == true;
        final bluetoothConnectOk = status['bluetoothConnect'] == true;
        final locationOk = status['location'] == true;
        
        // Android 12+: requiere bluetoothScan Y bluetoothConnect
        // Android <12: requiere location
        final bluetoothOk = bluetoothScanOk && bluetoothConnectOk;
        
        // Requerimos Bluetooth (ambos permisos en Android 12+) Y Ubicación
        _allGranted = bluetoothOk && locationOk;
        
        print('=== ESTADO PERMISOS ===');
        print('Bluetooth Scan: $bluetoothScanOk');
        print('Bluetooth Connect: $bluetoothConnectOk');
        print('Ubicación: $locationOk');
        print('Todos concedidos: $_allGranted');
        print('======================');
      });
    }
  }

  void _navigateToApp() {
    print('=== NAVEGANDO A LA APP ===');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }

  Future<void> _requestPermissions() async {
    if (_isRequesting) return;
    
    setState(() {
      _isRequesting = true;
    });

    try {
      await PermissionService.requestAllPermissions().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Timeout solicitando permisos');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Timeout. Intenta de nuevo o usa Configuración Manual.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
      );
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    if (mounted) {
      setState(() {
        _isRequesting = false;
      });
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 30),
              // Icono
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueAccent.withOpacity(0.5),
                      Colors.greenAccent.withOpacity(0.5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bluetooth_searching,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              // Título
              const Text(
                'BlueSnafer Pro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Permisos Requeridos',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 25),
              // Lista de permisos
              Expanded(
                child: _buildPermissionList(),
              ),
              const SizedBox(height: 20),
              // Botones
              _buildButtons(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionList() {
    return ListView(
      children: [
        // Bluetooth
        _buildPermissionItem(
          icon: Icons.bluetooth,
          title: 'Bluetooth',
          description: 'Escaneo y conexión (Android 12+)',
          isGranted: _permissionStatus['bluetoothScan'] == true &&
                     _permissionStatus['bluetoothConnect'] == true,
          isPermanentlyDenied: _permissionStatus['bluetoothDeniedPermanently'] == true,
        ),
        const SizedBox(height: 8),
        // Ubicación
        _buildPermissionItem(
          icon: Icons.location_on,
          title: 'Ubicación',
          description: 'Requerido para Bluetooth',
          isGranted: _permissionStatus['location'] == true,
          isPermanentlyDenied: _permissionStatus['locationDeniedPermanently'] == true,
        ),
        const SizedBox(height: 8),
        // Almacenamiento (siempre disponible - interno)
        _buildPermissionItem(
          icon: Icons.storage,
          title: 'Almacenamiento',
          description: 'Directorio interno (sin permisos)',
          isGranted: true, // El almacenamiento interno no requiere permisos
        ),
        const SizedBox(height: 8),
        // Notificaciones
        _buildPermissionItem(
          icon: Icons.notifications,
          title: 'Notificaciones',
          description: 'Alertas en segundo plano',
          isGranted: _permissionStatus['notification'] == true,
        ),
      ],
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    bool isPermanentlyDenied = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isGranted 
                ? Colors.greenAccent 
                : (isPermanentlyDenied ? Colors.red : Colors.orange),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: isPermanentlyDenied ? Colors.redAccent : Colors.white38,
                    fontSize: 10,
                  ),
                ),
                if (isPermanentlyDenied)
                  const Text(
                    '⚠️ Ir a Configuración',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            isGranted 
                ? Icons.check_circle 
                : (isPermanentlyDenied ? Icons.error : Icons.pending),
            color: isGranted 
                ? Colors.greenAccent 
                : (isPermanentlyDenied ? Colors.red : Colors.orange),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isRequesting 
                ? null 
                : (_allGranted ? _navigateToApp : _requestPermissions),
            style: ElevatedButton.styleFrom(
              backgroundColor: _allGranted ? Colors.greenAccent : Colors.blueAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isRequesting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(
                    _allGranted ? 'COMENZAR' : 'OTORGAR PERMISOS',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () async {
            await PermissionService.openAppSettingsPage();
            // Esperar a que el usuario vuelva y refrescar automáticamente
            await Future.delayed(const Duration(milliseconds: 1000));
            if (mounted) {
              await _checkPermissions();
            }
          },
          icon: const Icon(Icons.settings, size: 18),
          label: const Text(
            'Configuración Manual (auto-refresca)',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
