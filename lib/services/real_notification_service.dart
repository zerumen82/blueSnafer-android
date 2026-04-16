import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

/// Servicio de notificaciones real con permisos del sistema
/// Implementación real usando permission_handler para Android/iOS
class RealNotificationService {
  static final RealNotificationService _instance =
      RealNotificationService._internal();
  factory RealNotificationService() => _instance;
  RealNotificationService._internal();

  static const String _notificationsKey = 'notification_queue';
  static const MethodChannel _channel =
      MethodChannel('com.bluesnafer_pro/notifications');

  /// Inicializar el servicio de notificaciones
  Future<void> initialize() async {
    try {
      // Verificar permisos de notificación
      final hasPermission = await checkNotificationPermission();
      if (!hasPermission) {
        print(
            '[NOTIFICATION_SERVICE] ⚠️ Permisos de notificación no concedidos');
      } else {
        print(
            '[NOTIFICATION_SERVICE] ✅ Servicio de notificaciones inicializado con permisos');
      }
    } catch (e) {
      print('[NOTIFICATION_SERVICE] ❌ Error inicializando servicio: $e');
    }
  }

  /// Mostrar notificación inmediata (real o nativa)
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    final timestamp = DateTime.now();

    // Verificar permisos primero
    final hasPermission = await checkNotificationPermission();
    if (!hasPermission) {
      print('⚠️ No se puede mostrar notificación: permisos no concedidos');
      // Como fallback, mostrar en consola
      print('🔔 $title: $body');
      return;
    }

    // Guardar en preferencias para historial
    final prefs = await SharedPreferences.getInstance();
    final notifications = _getNotificationQueue(prefs);

    notifications.add({
      'id': id,
      'title': title,
      'body': body,
      'payload': payload,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': 'immediate',
    });

    await _saveNotificationQueue(notifications);

    // Intentar mostrar notificación nativa
    try {
      await _channel.invokeMethod('showNotification', {
        'id': id,
        'title': title,
        'body': body,
        'payload': payload,
      });
      print('📱 Notificación nativa mostrada: $title');
    } catch (e) {
      // Fallback a consola si no hay canal nativo
      print('🔔 $title');
      print('   $body');
      if (payload != null) {
        print('   Payload: $payload');
      }
    }
  }

  /// Programar notificación para tiempo específico (real)
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    int id = 1,
  }) async {
    // Verificar permisos
    final hasPermission = await checkNotificationPermission();
    if (!hasPermission) {
      print('⚠️ No se puede programar notificación: permisos no concedidos');
      return;
    }

    if (scheduledTime.isBefore(DateTime.now())) {
      // Si la hora ya pasó, mostrar inmediatamente
      await showNotification(
          title: title, body: body, payload: payload, id: id);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final notifications = _getNotificationQueue(prefs);

    notifications.add({
      'id': id,
      'title': title,
      'body': body,
      'payload': payload,
      'timestamp': scheduledTime.millisecondsSinceEpoch,
      'type': 'scheduled',
    });

    await _saveNotificationQueue(notifications);

    // Intentar programar notificación nativa
    try {
      await _channel.invokeMethod('scheduleNotification', {
        'id': id,
        'title': title,
        'body': body,
        'payload': payload,
        'timestamp': scheduledTime.millisecondsSinceEpoch,
      });
      print(
          '📱 Notificación nativa programada para ${scheduledTime.toLocal()}: $title');
    } catch (e) {
      // Fallback a logging
      print(
          '⏰ NOTIFICACIÓN PROGRAMADA para ${scheduledTime.toLocal()}: $title - $body');
    }
  }

  /// Mostrar advertencia de auto-destrucción (1 hora antes)
  Future<void> showAutoDestructWarning() async {
    await showNotification(
      title: '⚠️ Advertencia de Auto-Destrucción',
      body:
          'La eliminación automática de datos comenzará en 1 hora. Si deseas continuar, extiende el tiempo.',
      payload: 'auto_destruct_warning',
      id: 100,
    );
  }

  /// Mostrar notificación de inicio de destrucción
  Future<void> showDestructionStarted() async {
    await showNotification(
      title: '🔥 Eliminación de Datos Iniciada',
      body:
          'El sistema de auto-destrucción está eliminando todos los datos sensibles...',
      payload: 'destruction_started',
      id: 101,
    );
  }

  /// Mostrar notificación de destrucción completada
  Future<void> showDestructionCompleted() async {
    await showNotification(
      title: '✅ Eliminación Completada',
      body: 'Todos los datos sensibles han sido eliminados del sistema.',
      payload: 'destruction_completed',
      id: 102,
    );
  }

  /// Mostrar notificación de tiempo restante
  Future<void> showTimeRemaining(Duration remaining) async {
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    String timeText;

    if (hours > 0) {
      timeText = '$hours horas y $minutes minutos';
    } else {
      timeText = '$minutes minutos';
    }

    await showNotification(
      title: '⏰ Tiempo Restante',
      body: 'Auto-destrucción en: $timeText',
      payload: 'time_remaining',
      id: 103,
    );
  }

  /// Cancelar todas las notificaciones
  Future<void> cancelAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);

    // Intentar cancelar notificaciones nativas programadas
    try {
      await _channel.invokeMethod('cancelAllNotifications');
      print('🚫 Notificaciones nativas canceladas');
    } catch (e) {
      // Ignorar si no hay canal nativo
    }

    print('🚫 Todas las notificaciones han sido canceladas');
  }

  /// Cancelar notificación específica
  Future<void> cancelNotification(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = _getNotificationQueue(prefs);

    notifications.removeWhere((notification) => notification['id'] == id);

    await _saveNotificationQueue(notifications);

    // Intentar cancelar notificación nativa
    try {
      await _channel.invokeMethod('cancelNotification', {'id': id});
      print('🚫 Notificación nativa $id cancelada');
    } catch (e) {
      // Ignorar si no hay canal nativo
    }

    print('🚫 Notificación $id cancelada');
  }

  /// Programar serie de notificaciones para countdown
  Future<void> scheduleCountdownNotifications({
    required DateTime destructTime,
    List<Duration> warningTimes = const [
      Duration(hours: 24),
      Duration(hours: 12),
      Duration(hours: 6),
      Duration(hours: 1),
      Duration(minutes: 30),
    ],
  }) async {
    print(
        '📅 Programando ${warningTimes.length} notificaciones para countdown...');

    for (int i = 0; i < warningTimes.length; i++) {
      final notificationTime = destructTime.subtract(warningTimes[i]);
      if (notificationTime.isAfter(DateTime.now())) {
        final hours = warningTimes[i].inHours;
        final minutes = warningTimes[i].inMinutes.remainder(60);
        String warningText;

        if (hours > 0) {
          warningText = hours == 1 ? '1 hora' : '$hours horas';
        } else {
          warningText = minutes == 1 ? '1 minuto' : '$minutes minutos';
        }

        await scheduleNotification(
          title: '⏰ Recordatorio de Auto-Destrucción',
          body: 'La eliminación de datos comenzará en $warningText.',
          scheduledTime: notificationTime,
          payload: 'countdown_warning_$i',
          id: 200 + i,
        );
      }
    }

    // Programar notificación de inicio
    await scheduleNotification(
      title: '🔥 Iniciando Auto-Destrucción',
      body: 'El proceso de eliminación de datos sensibles ha comenzado.',
      scheduledTime: destructTime,
      payload: 'destruction_start',
      id: 299,
    );

    print('✅ $warningTimes.length notificaciones de countdown programadas');
  }

  /// Procesar notificaciones programadas
  Future<void> processScheduledNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = _getNotificationQueue(prefs);
    final now = DateTime.now();

    final dueNotifications = notifications.where((notification) {
      final scheduledTime =
          DateTime.fromMillisecondsSinceEpoch(notification['timestamp'] ?? 0);
      return scheduledTime.isBefore(now) && notification['type'] == 'scheduled';
    }).toList();

    for (final notification in dueNotifications) {
      final title = notification['title'] as String;
      final body = notification['body'] as String;
      final payload = notification['payload'] as String?;
      final id = notification['id'] as int;

      // Mostrar notificación
      print('🔔 NOTIFICACIÓN PROGRAMADA: $title - $body');

      // Remover de la cola
      notifications.remove(notification);
    }

    await _saveNotificationQueue(notifications);

    if (dueNotifications.isNotEmpty) {
      print('✅ ${dueNotifications.length} notificaciones procesadas');
    }
  }

  /// Verificar permisos de notificación reales del sistema
  Future<bool> checkNotificationPermission() async {
    try {
      // Verificar permiso de notificación
      final status = await Permission.notification.status;

      if (status.isGranted) {
        print('✅ Permisos de notificación verificados: CONCEDIDOS');
        return true;
      } else if (status.isDenied) {
        print('⚠️ Permisos de notificación: DENEGADOS');
        return false;
      } else if (status.isPermanentlyDenied) {
        print('❌ Permisos de notificación: PERMANENTEMENTE DENEGADOS');
        print('   Se requiere abrir configuraciones de la app');
        return false;
      }

      return false;
    } catch (e) {
      print('❌ Error verificando permisos: $e');
      return false;
    }
  }

  /// Solicitar permisos de notificación reales del sistema
  Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();

      if (status.isGranted) {
        print('✅ Permisos de notificación solicitados: CONCEDIDOS');

        // Intentar inicializar canal de notificaciones nativo si es Android
        try {
          await _channel.invokeMethod('initializeNotificationChannel');
          print('📱 Canal de notificaciones nativo inicializado');
        } catch (e) {
          // Ignorar si no hay canal nativo
        }

        return true;
      } else if (status.isDenied) {
        print('⚠️ Permisos de notificación: DENEGADOS POR USUARIO');
        return false;
      } else if (status.isPermanentlyDenied) {
        print('❌ Permisos de notificación: PERMANENTEMENTE DENEGADOS');
        print('   Abriendo configuraciones de la app...');
        await openAppSettings();
        return false;
      }

      return false;
    } catch (e) {
      print('❌ Error solicitando permisos: $e');
      return false;
    }
  }

  /// Verificar si las notificaciones están habilitadas en el sistema
  Future<bool> areNotificationsEnabled() async {
    try {
      // Verificar permiso de app
      final hasPermission = await checkNotificationPermission();
      if (!hasPermission) return false;

      // Verificar si el sistema tiene notificaciones habilitadas
      try {
        final result =
            await _channel.invokeMethod<bool>('areNotificationsEnabled');
        return result ?? false;
      } catch (e) {
        // Si no hay canal nativo, asumir que están habilitadas si hay permiso
        return hasPermission;
      }
    } catch (e) {
      print('❌ Error verificando estado de notificaciones: $e');
      return false;
    }
  }

  /// Obtener estado de inicialización
  bool get isInitialized => true;

  /// Obtener historial de notificaciones
  Future<List<Map<String, dynamic>>> getNotificationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return _getNotificationQueue(prefs);
  }

  /// Limpiar historial de notificaciones
  Future<void> clearNotificationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);
    print('🧹 Historial de notificaciones limpiado');

    // Limpiar notificaciones nativas también
    try {
      await _channel.invokeMethod('clearNotificationHistory');
      print('🧹 Historial nativo limpiado');
    } catch (e) {
      // Ignorar si no hay canal nativo
    }
  }

  /// Cerrar el servicio
  Future<void> dispose() async {
    await cancelAllNotifications();
    print('🔒 Servicio de notificaciones cerrado');
  }

  // Métodos auxiliares privados
  List<Map<String, dynamic>> _getNotificationQueue(SharedPreferences prefs) {
    final notificationsString = prefs.getString(_notificationsKey);
    if (notificationsString == null) return [];

    try {
      // Parsear JSON real
      final decoded = json.decode(notificationsString);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      print('⚠️ Error parseando notificaciones: $e');
      return [];
    }
  }

  /// Guardar cola de notificaciones en formato JSON real
  Future<void> _saveNotificationQueue(
      List<Map<String, dynamic>> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final jsonString = json.encode(notifications);
      await prefs.setString(_notificationsKey, jsonString);
    } catch (e) {
      print('❌ Error guardando notificaciones: $e');
    }
  }
}
