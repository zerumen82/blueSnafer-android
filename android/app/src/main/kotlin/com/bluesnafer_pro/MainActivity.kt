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

        // Configurar EventChannel para logs
        val logEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "bluetooth_logs")
        logEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                BluesnaferLogger.setEventSink(events)
                AttackLogger.setEventSink(events)
            }

            override fun onCancel(arguments: Any?) {
                BluesnaferLogger.setEventSink(null)
                AttackLogger.setEventSink(null)
            }
        })
    }
}
