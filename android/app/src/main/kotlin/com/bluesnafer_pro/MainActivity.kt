package com.bluesnafer_pro

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Inicializar loggers
        AttackLogger.init(applicationContext)
        BluesnaferLogger.init(applicationContext)
        // Inicializar clientes
        RealFileExfiltrationClient.init(applicationContext)
        
        // Registrar ExploitIntegration (canal principal 'exploit_integration')
        val context = applicationContext ?: this
        Log.d("MainActivity", "Context available: ${context != null}, hash: ${context.hashCode()}")
        ExploitIntegration.registerWith(flutterEngine)
        ExploitIntegration.setContext(context)

        // Registrar BluetoothMethodHandler para com.bluesnafer_pro/bluetooth
        BluetoothMethodHandler.registerWith(flutterEngine, applicationContext)

        // Registrar NotificationBridge (canal 'com.bluesnafer_pro/notifications')
        NotificationBridge.registerWith(flutterEngine.dartExecutor.binaryMessenger, applicationContext)

        // Forwarder central: reenvía cada log a todos los canales activos
        BluesnaferLogger.setEventSink(LogForwarder.sink)
        AttackLogger.setEventSink(LogForwarder.sink)

        // EventChannel 'bluetooth_logs': logs crudos (String)
        val logEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "bluetooth_logs")
        logEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                LogForwarder.setRawSink(events)
            }

            override fun onCancel(arguments: Any?) {
                LogForwarder.setRawSink(null)
            }
        })

        // EventChannel 'exploit_events': logs como mapas
        // {'type': 'LOG', 'message': ...} para consumidores Dart que esperan Map.
        val exploitEventsChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "exploit_events")
        exploitEventsChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                LogForwarder.setMapSink(events)
            }

            override fun onCancel(arguments: Any?) {
                LogForwarder.setMapSink(null)
            }
        })
    }
}
