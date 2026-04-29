package com.bluesnafer_pro

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "bluetooth_security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Registrar ExploitIntegration
        ExploitIntegration.registerWith(flutterEngine)
        ExploitIntegration.setContext(applicationContext)

        // Registrar BluetoothMethodHandler para com.bluesnafer_pro/bluetooth
        BluetoothMethodHandler.registerWith(flutterEngine)

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
