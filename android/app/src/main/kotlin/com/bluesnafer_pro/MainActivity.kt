package com.bluesnafer_pro

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothProfile
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "bluetooth_security"
    private val LOG_CHANNEL = "bluetooth_logs"
    private var logSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Inicializar loggers
        AttackLogger.init(applicationContext)
        BluesnaferLogger.init(applicationContext)
        // Inicializar clientes
        RealFileExfiltrationClient.init(applicationContext)
        
        // Registrar ExploitIntegration
        ExploitIntegration.registerWith(flutterEngine)
        ExploitIntegration.setContext(applicationContext)

        // Registrar BluetoothMethodHandler para com.bluesnafer_pro/bluetooth
        BluetoothMethodHandler.registerWith(flutterEngine, applicationContext)

        // Configurar EventChannel para logs
        val logEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, LOG_CHANNEL)
        logEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                logSink = events
                BluesnaferLogger.setEventSink(logSink)
                AttackLogger.setEventSink(logSink)
            }

            override fun onCancel(arguments: Any?) {
                logSink = null
                BluesnaferLogger.setEventSink(null)
                AttackLogger.setEventSink(null)
            }
        })

        // Configurar MethodChannel para comunicación básica
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call,
                result ->
            when (call.method) {
                "getDeviceInfo" -> {
                    try {
                        val deviceAddress = call.argument<String>("deviceAddress") ?: ""
                        val adapter = BluetoothAdapter.getDefaultAdapter()
                        val device = adapter.getRemoteDevice(deviceAddress)
                        
                        val deviceInfo = mapOf(
                            "name" to device.name,
                            "address" to device.address,
                            "type" to device.type
                        )
                        result.success(deviceInfo)
                    } catch (e: Exception) {
                        result.error("DEVICE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
