// BlueSnafer Pro - Servicio de Permisos Mejorado
import 'dart:io';
import 'package:permission_handler/permission_handler.dart' as permission_handler;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Resultado de la verificación de permisos
class PermissionResult {
  final bool allGranted;
  final bool hasCriticalDenied;
  final List<String> deniedPermissions;
  final List<String> permanentlyDeniedPermissions;
  final String message;

  PermissionResult({
    required this.allGranted,
    required this.hasCriticalDenied,
    required this.deniedPermissions,
    required this.permanentlyDeniedPermissions,
    required this.message,
  });
}

/// Servicio mejorado para manejo de permisos en BlueSnafer Pro
/// 
/// NOTA: El almacenamiento interno NO requiere permisos. Usamos path_provider
/// para acceder al directorio interno de la aplicación.
class PermissionHandlerService {
  static final PermissionHandlerService _instance =
      PermissionHandlerService._internal();

  factory PermissionHandlerService() => _instance;
  PermissionHandlerService._internal();

  /// Permisos críticos requeridos para Bluetooth scanning
  List<Permission> get _criticalPermissions => [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
    Permission.locationWhenInUse,
  ];

  /// Permisos adicionales (solo notificaciones - storage se maneja por separado)
  List<Permission> get _additionalPermissions => [
    Permission.notification,
    // NO pedimos Permission.storage aquí porque en Android 13+ siempre falla.
    // El almacenamiento se gestiona con MANAGE_EXTERNAL_STORAGE en el Manifest.
  ];

  /// Todos los permisos requeridos
  List<Permission> get _allPermissions => [
    ..._criticalPermissions,
    ..._additionalPermissions,
  ];

  /// Obtener versión de Android
  Future<int> getAndroidVersion() async {
    try {
      if (!Platform.isAndroid) return 10;
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final version = androidInfo.version.release;
      return int.parse(version);
    } catch (e) {
      print('Error obteniendo versión de Android: $e');
      return 10;
    }
  }

  /// Verificar todos los permisos y retornar resultado detallado
  Future<PermissionResult> checkAllPermissions() async {
    try {
      final denied = <String>[];
      final permanentlyDenied = <String>[];

      for (final permission in _allPermissions) {
        final status = await permission.status;
        final name = _permissionName(permission);

        if (status.isDenied) {
          denied.add(name);
          if (status.isPermanentlyDenied) {
            permanentlyDenied.add(name);
          }
        }
      }

      final allGranted = denied.isEmpty;

      // Verificar permisos críticos con await
      bool hasCritical = false;
      for (final p in _criticalPermissions) {
        final status = await p.status;
        if (status.isDenied || status.isPermanentlyDenied) {
          hasCritical = true;
          break;
        }
      }
      final hasCriticalDenied = hasCritical;

      String message;
      if (allGranted) {
        message = '✅ Todos los permisos concedidos';
      } else if (permanentlyDenied.isNotEmpty) {
        message = '🚫 Permisos denegados permanentemente: ${permanentlyDenied.join(", ")}';
      } else if (hasCriticalDenied) {
        message = '⚠️ Permisos críticos denegados: ${denied.where((p) => p.contains("BLUETOOTH") || p.contains("LOCATION")).join(", ")}';
      } else {
        message = '⚠️ Faltan permisos: ${denied.join(", ")}';
      }

      return PermissionResult(
        allGranted: allGranted,
        hasCriticalDenied: hasCriticalDenied,
        deniedPermissions: denied,
        permanentlyDeniedPermissions: permanentlyDenied,
        message: message,
      );
    } catch (e) {
      return PermissionResult(
        allGranted: false,
        hasCriticalDenied: true,
        deniedPermissions: ['ERROR'],
        permanentlyDeniedPermissions: [],
        message: '❌ Error verificando permisos: $e',
      );
    }
  }

  /// Solicitar todos los permisos necesarios
  Future<PermissionResult> requestAllPermissions() async {
    try {
      final androidVersion = await getAndroidVersion();

      // Solicitar permisos críticos primero
      final requestedPermissions = <Permission>[];

      // Android 12+ requiere permisos específicos de Bluetooth
      if (androidVersion >= 12) {
        requestedPermissions.addAll([
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
        ]);
      }

      // Ubicación siempre requerida para BLE scanning
      requestedPermissions.add(Permission.locationWhenInUse);

      // NO solicitamos Permission.storage - en Android 13+ siempre está denegado.
      // Los archivos descargados van a Downloads/ que no requiere permisos especiales.
      // Para Android 11-12 se podría usar manageExternalStorage pero no es necesario
      // porque usamos getExternalStorageDirectory() para almacenamiento interno de la app.

      // Notificaciones (Android 13+)
      if (androidVersion >= 13) {
        requestedPermissions.add(Permission.notification);
      }

      // Solicitar todos los permisos
      await requestedPermissions.request();

      // Verificar resultados
      return await checkAllPermissions();
    } catch (e) {
      return PermissionResult(
        allGranted: false,
        hasCriticalDenied: true,
        deniedPermissions: ['ERROR'],
        permanentlyDeniedPermissions: [],
        message: '❌ Error solicitando permisos: $e',
      );
    }
  }

  /// Solicitar solo permisos críticos (Bluetooth + Ubicación)
  Future<PermissionResult> requestCriticalPermissions() async {
    try {
      final androidVersion = await getAndroidVersion();

      final requestedPermissions = <Permission>[];

      if (androidVersion >= 12) {
        requestedPermissions.addAll([
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
        ]);
      }

      requestedPermissions.add(Permission.locationWhenInUse);

      await requestedPermissions.request();

      // Verificar solo permisos críticos
      final criticalResults = await Future.wait(
        _criticalPermissions.map((p) => p.status),
      );

      final allGranted = criticalResults.every((s) => s.isGranted);
      final denied = <String>[];
      final permanentlyDenied = <String>[];

      for (final permission in _criticalPermissions) {
        final status = await permission.status;
        final name = _permissionName(permission);
        if (status.isDenied) {
          denied.add(name);
          if (status.isPermanentlyDenied) {
            permanentlyDenied.add(name);
          }
        }
      }

      return PermissionResult(
        allGranted: allGranted,
        hasCriticalDenied: !allGranted,
        deniedPermissions: denied,
        permanentlyDeniedPermissions: permanentlyDenied,
        message: allGranted
          ? '✅ Permisos críticos concedidos'
          : '⚠️ Faltan permisos críticos: ${denied.join(", ")}',
      );
    } catch (e) {
      return PermissionResult(
        allGranted: false,
        hasCriticalDenied: true,
        deniedPermissions: ['ERROR'],
        permanentlyDeniedPermissions: [],
        message: '❌ Error solicitando permisos críticos: $e',
      );
    }
  }

  /// Abrir configuración de la aplicación
  Future<bool> openAppSettings() async {
    return await permission_handler.openAppSettings();
  }

  /// Verificar si Bluetooth está disponible y activado
  Future<Map<String, dynamic>> checkBluetoothHardware() async {
    try {
      // Nota: Esto requiere flutter_blue_plus para verificación completa
      // Por ahora retornamos información básica
      return {
        'available': Platform.isAndroid || Platform.isIOS,
        'enabled': true, // Asumimos que está activado si tenemos permisos
        'message': Platform.isAndroid
          ? 'Bluetooth disponible en Android'
          : 'Bluetooth disponible',
      };
    } catch (e) {
      return {
        'available': false,
        'enabled': false,
        'message': 'Error verificando Bluetooth: $e',
      };
    }
  }

  String _permissionName(Permission permission) {
    if (permission == Permission.bluetoothScan) return 'BLUETOOTH_SCAN';
    if (permission == Permission.bluetoothConnect) return 'BLUETOOTH_CONNECT';
    if (permission == Permission.bluetoothAdvertise) return 'BLUETOOTH_ADVERTISE';
    if (permission == Permission.locationWhenInUse) return 'LOCATION';
    if (permission == Permission.notification) return 'NOTIFICATION';
    return permission.toString();
  }
}
