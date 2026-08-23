package com.bluesnafer_pro

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.SharedPreferences
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONArray
import org.json.JSONObject

/**
 * Puente real de notificaciones Android para el canal
 * `com.bluesnafer_pro/notifications`. Implementación con NotificationManager
 * real (canal, mostrar, cancelar, historial persistido en SharedPreferences).
 */
object NotificationBridge {
    private const val TAG = "NotificationBridge"
    private const val CHANNEL_ID = "bluesnafer_alerts"
    private const val CHANNEL_NAME = "Alertas BlueSnafer Pro"
    private const val PREFS = "bluesnafer_notifications"
    private const val MAX_HISTORY = 100

    private var appContext: Context? = null

    fun registerWith(
        messenger: io.flutter.plugin.common.BinaryMessenger,
        context: Context
    ) {
        appContext = context
        val channel = MethodChannel(messenger, "com.bluesnafer_pro/notifications")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> handleInitialize(call, result)
                "showNotification" -> handleShowNotification(call, result)
                "cancelNotification" -> handleCancelNotification(call, result)
                "cancelAllNotifications" -> handleCancelAll(result)
                "checkNotificationPermission" -> handleCheckPermission(result)
                "requestNotificationPermission" -> handleRequestPermission(result)
                "getNotificationHistory" -> handleGetHistory(result)
                "clearNotificationHistory" -> handleClearHistory(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun getManager(): NotificationManager? {
        val ctx = appContext ?: return null
        return ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager?
    }

    private fun handleInitialize(call: MethodCall, result: Result) {
        try {
            val ctx = appContext ?: run {
                result.success(mapOf("success" to false, "error" to "Context unavailable"))
                return
            }
            val manager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Alertas de operaciones Bluetooth"
            manager.createNotificationChannel(channel)
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            Log.e(TAG, "initialize error: ${e.message}")
            result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown")))
        }
    }

    private fun handleShowNotification(call: MethodCall, result: Result) {
        try {
            val ctx = appContext ?: run {
                result.success(mapOf("success" to false, "error" to "Context unavailable"))
                return
            }
            val title = call.argument<String>("title") ?: "BlueSnafer Pro"
            val body = call.argument<String>("body") ?: ""
            val payload = call.argument<String>("payload") ?: ""
            val notificationId = (call.argument<Int>("id") ?: title.hashCode())

            val notification = android.app.Notification.Builder(ctx, CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(android.R.drawable.stat_sys_warning)
                .setAutoCancel(true)
                .build()

            getManager()?.notify(notificationId, notification)

            saveToHistory(notificationId, title, body, payload)
            result.success(mapOf("success" to true, "id" to notificationId))
        } catch (e: Exception) {
            Log.e(TAG, "showNotification error: ${e.message}")
            result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown")))
        }
    }

    private fun handleCancelNotification(call: MethodCall, result: Result) {
        try {
            val id = call.argument<Int>("id") ?: call.argument<Int>("notificationId") ?: 0
            getManager()?.cancel(id)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun handleCancelAll(result: Result) {
        try {
            getManager()?.cancelAll()
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun handleCheckPermission(result: Result) {
        try {
            val ctx = appContext
            if (ctx == null) {
                result.success("denied")
                return
            }
            val manager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            result.success(
                if (manager.areNotificationsEnabled()) "granted" else "denied"
            )
        } catch (e: Exception) {
            result.success("denied")
        }
    }

    private fun handleRequestPermission(result: Result) {
        try {
            val ctx = appContext ?: run {
                result.success("denied")
                return
            }
            val manager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.areNotificationsEnabled()) {
                result.success("granted")
                return
            }
            // Abrir configuración de la app para que el usuario otorgue el permiso
            ctx.startActivity(
                android.content.Intent(
                    Settings.ACTION_APP_NOTIFICATION_SETTINGS
                ).putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
            )
            result.success("denied")
        } catch (e: Exception) {
            result.success("denied")
        }
    }

    private fun handleGetHistory(result: Result) {
        try {
            val ctx = appContext ?: run {
                result.success(JSONArray().toString())
                return
            }
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val raw = prefs.getString("history", "[]") ?: "[]"
            result.success(raw)
        } catch (e: Exception) {
            result.success(JSONArray().toString())
        }
    }

    private fun handleClearHistory(result: Result) {
        try {
            val ctx = appContext ?: run {
                result.success(false)
                return
            }
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            result.success(prefs.edit().putString("history", "[]").commit())
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun saveToHistory(notificationId: Int, title: String, body: String, payload: String) {
        try {
            val ctx = appContext ?: return
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val raw = prefs.getString("history", "[]") ?: "[]"
            val array = try {
                JSONArray(raw)
            } catch (e: Exception) {
                JSONArray()
            }
            val entry = JSONObject().apply {
                put("id", notificationId)
                put("title", title)
                put("body", body)
                put("payload", payload)
                put("timestamp", System.currentTimeMillis())
            }
            array.put(entry)
            while (array.length() > MAX_HISTORY) {
                array.remove(0)
            }
            prefs.edit().putString("history", array.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "saveToHistory error: ${e.message}")
        }
    }
}
