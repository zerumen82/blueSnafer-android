import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Servicio de permisos para BlueSnafer Pro
/// 
/// NOTA: El almacenamiento interno de la app NO requiere permisos en Android 10+.
/// Usamos path_provider para acceder al directorio interno de la aplicación.
class PermissionService {
  /// Obtener versión de Android
  static Future<int> getAndroidVersion() async {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final version = androidInfo.version.release;
      return int.parse(version);
    } catch (e) {
      print('Error obteniendo versión de Android: $e');
      return 10; // Fallback seguro
    }
  }

  /// Solicitar todos los permisos necesarios
  static Future<void> requestAllPermissions() async {
    try {
      final androidVersion = await getAndroidVersion();

      if (androidVersion >= 12) {
        // Android 12+ - Permisos de Bluetooth
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
        ].request();
      } else {
        // Android <12 - Ubicación para Bluetooth
        await Permission.locationWhenInUse.request();
      }

      // Ubicación (siempre requerida para Bluetooth scanning)
      await Permission.locationWhenInUse.request();

      // NOTA: No solicitamos permiso de almacenamiento porque usamos
      // el almacenamiento interno de la app (no requiere permisos).
      // Solo solicitamos permisos de medios si la app necesita acceder
      // a fotos/videos/audio del sistema (opcional).

      // Notificaciones (Android 13+)
      if (androidVersion >= 13) {
        await Permission.notification.request();
      }
    } catch (e) {
      print('Error solicitando permisos: $e');
    }
  }

  /// Verificar estado actual de permisos
  static Future<Map<String, bool>> checkPermissions() async {
    final status = <String, bool>{};

    try {
      final androidVersion = await getAndroidVersion();

      // Bluetooth (Android 12+)
      if (androidVersion >= 12) {
        final scanStatus = await Permission.bluetoothScan.status;
        final connectStatus = await Permission.bluetoothConnect.status;
        final advertiseStatus = await Permission.bluetoothAdvertise.status;

        status['bluetoothScan'] = scanStatus.isGranted;
        status['bluetoothConnect'] = connectStatus.isGranted;
        status['bluetoothAdvertise'] = advertiseStatus.isGranted;
        status['bluetoothDeniedPermanently'] =
            scanStatus.isPermanentlyDenied ||
            connectStatus.isPermanentlyDenied;
      }

      // Ubicación (siempre requerida para Bluetooth scanning)
      final locationStatus = await Permission.locationWhenInUse.status;
      status['location'] = locationStatus.isGranted;
      status['locationDeniedPermanently'] = locationStatus.isPermanentlyDenied;

      // NOTA: El almacenamiento interno NO requiere permisos.
      // Marcamos como concedido ya que la app puede escribir en su directorio interno.
      status['storage'] = true;

      // Notificaciones (Android 13+)
      if (androidVersion >= 13) {
        final notificationStatus = await Permission.notification.status;
        status['notification'] = notificationStatus.isGranted;
      }
    } catch (e) {
      print('Error verificando permisos: $e');
      // Retornar valores default seguros
      return {
        'bluetoothScan': false,
        'bluetoothConnect': false,
        'location': false,
        'storage': true, // Almacenamiento interno siempre disponible
        'notification': false,
      };
    }

    return status;
  }

  /// Abrir configuración de la app
  static Future<bool> openAppSettingsPage() async {
    return await openAppSettings();
  }
}
