package com.bluesnafer_pro

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Handles method calls from Flutter for Bluetooth operations.
 * Delegates real implementations to ExploitIntegration.
 */
class BluetoothMethodHandler private constructor(
    private val context: Context,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "bluesnafer_pro/bluetooth"
        @Volatile private var appContext: Context? = null

        fun registerWith(flutterEngine: io.flutter.embedding.engine.FlutterEngine, context: Context) {
            appContext = context
            val binaryMessenger = flutterEngine.dartExecutor.binaryMessenger
            val channel = MethodChannel(binaryMessenger, CHANNEL)
            val handler = BluetoothMethodHandler(context, channel)
            channel.setMethodCallHandler(handler)
        }

        fun initialize(binding: FlutterPlugin.FlutterPluginBinding) {
            appContext = binding.applicationContext
            val binaryMessenger = binding.binaryMessenger
            val channel = MethodChannel(binaryMessenger, CHANNEL)
            val handler = BluetoothMethodHandler(appContext!!, channel)
            channel.setMethodCallHandler(handler)
        }

        fun getAppContext(): Context? = appContext
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openBluetoothSettings" -> handleOpenBluetoothSettings(result)
            else -> {
                // Delegar todas las demás llamadas a ExploitIntegration (implementaciones reales)
                ExploitIntegration.handleMethodCall(call, result)
            }
        }
    }

    private fun handleOpenBluetoothSettings(result: MethodChannel.Result) {
        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ContextCompat.startActivity(context, intent, null)
        result.success("Bluetooth settings opened")
    }
}
