package com.bluesnafer_pro

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.ParcelUuid
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class BluetoothMethodHandler private constructor(
    private val context: Context,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "com.bluesnafer_pro/bluetooth"
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

    private val executor = Executors.newSingleThreadExecutor()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        // Puente unificado: métodos avanzados Dart → implementaciones nativas reales
        if (BluetoothChannelBridge.handle(context, call, result, executor)) return

        when (call.method) {
            "openBluetoothSettings" -> handleOpenBluetoothSettings(result)
            "scanSDPServices" -> handleScanSDPServices(call, result)
            "detectBluetoothVersion" -> handleDetectBluetoothVersion(call, result)
            "detectManufacturer" -> handleDetectManufacturer(call, result)
            "detectSecurityMeasures" -> handleDetectSecurityMeasures(call, result)
            "scanL2CAPPorts" -> handleScanL2CAPPorts(call, result)
            "scanBLEServices" -> handleScanBLEServices(call, result)
            "scanBLECharacteristics" -> handleScanBLECharacteristics(call, result)
            "testProtocol" -> handleTestProtocol(call, result)
            "hasRootAccess" -> result.success(RootUtils.isRootAvailable())
            "getRootStatus" -> result.success(RootUtils.getRootStatus())
            "isHciToolAvailable" -> result.success(RootUtils.isHciToolAvailable())
            else -> ExploitIntegration.handleMethodCall(call, result)
        }
    }

    private fun handleOpenBluetoothSettings(result: MethodChannel.Result) {
        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ContextCompat.startActivity(context, intent, null)
        result.success("Bluetooth settings opened")
    }

    private fun getDeviceOrError(call: MethodCall, result: MethodChannel.Result): BluetoothDevice? {
        val deviceAddress = call.argument<String>("deviceAddress") ?: ""
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null || !adapter.isEnabled) {
            result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
            return null
        }
        if (deviceAddress.isBlank()) {
            result.success(mapOf("success" to false, "error" to "No device address"))
            return null
        }
        return adapter.getRemoteDevice(deviceAddress)
    }

    private fun handleScanSDPServices(call: MethodCall, result: MethodChannel.Result) {
        val device = getDeviceOrError(call, result) ?: return
        executor.submit {
            val sdpResult = MissingClasses.SDPServiceDiscovery.discoverServices(device)
            val services = (sdpResult["services"] as? List<Map<String, Any>>)?.map { svc ->
                mapOf(
                    "uuid" to (svc["uuid"] ?: ""),
                    "name" to (svc["name"] ?: "Unknown"),
                    "rfcommChannel" to 0
                )
            } ?: emptyList<Map<String, Any>>()
            result.success(services)
        }
    }

    private fun handleDetectBluetoothVersion(call: MethodCall, result: MethodChannel.Result) {
        val device = getDeviceOrError(call, result) ?: return
        executor.submit {
            val adapter = BluetoothAdapter.getDefaultAdapter()
            val hasLe = context.packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_BLUETOOTH_LE)
            val version = if (hasLe) "LE Supported (4.0+)" else "Classic Only (Pre-4.0)"
            result.success(mapOf(
                "version" to version,
                "hasLE" to hasLe,
                "isEnabled" to (adapter?.isEnabled == true),
                "deviceAddress" to device.address
            ))
        }
    }

    private fun handleDetectManufacturer(call: MethodCall, result: MethodChannel.Result) {
        val device = getDeviceOrError(call, result) ?: return
        result.success(mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "product" to Build.PRODUCT,
            "hardware" to Build.HARDWARE,
            "brand" to Build.BRAND,
            "deviceAddress" to device.address
        ))
    }

    private fun handleDetectSecurityMeasures(call: MethodCall, result: MethodChannel.Result) {
        val device = getDeviceOrError(call, result) ?: return
        executor.submit {
            val bondState = device.bondState
            val hasEncryption = bondState == BluetoothDevice.BOND_BONDED
            val adapter = BluetoothAdapter.getDefaultAdapter()
            result.success(mapOf(
                "isBonded" to (bondState == BluetoothDevice.BOND_BONDED),
                "isEncrypted" to hasEncryption,
                "isDiscoverable" to (adapter?.scanMode == BluetoothAdapter.SCAN_MODE_CONNECTABLE_DISCOVERABLE),
                "bondState" to bondState,
                "deviceAddress" to device.address
            ))
        }
    }

    private fun handleScanL2CAPPorts(call: MethodCall, result: MethodChannel.Result) {
        val device = getDeviceOrError(call, result) ?: return
        executor.submit {
            val openPorts = mutableListOf<Int>()
            val commonPorts = listOf(1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31)
            for (channel in commonPorts) {
                try {
                    val uuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
                    val socket = device.createInsecureRfcommSocketToServiceRecord(uuid)
                    socket.connect()
                    openPorts.add(channel)
                    socket.close()
                } catch (_: Exception) {}
            }
            result.success(openPorts)
        }
    }

    private fun handleScanBLEServices(call: MethodCall, result: MethodChannel.Result) {
        val device = getDeviceOrError(call, result) ?: return
        executor.submit {
            val services = mutableListOf<Map<String, Any>>()
            val latch = CountDownLatch(1)
            val gatt = device.connectGatt(context, false, object : BluetoothGattCallback() {
                override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        gatt?.services?.forEach { svc ->
                            services.add(mapOf(
                                "uuid" to svc.uuid.toString(),
                                "type" to if (svc.type == android.bluetooth.BluetoothGattService.SERVICE_TYPE_PRIMARY) "primary" else "secondary"
                            ))
                        }
                    }
                    latch.countDown()
                }
                override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        gatt?.discoverServices()
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        latch.countDown()
                    }
                }
            })
            latch.await(10, TimeUnit.SECONDS)
            try { gatt?.close() } catch (_: Exception) {}
            result.success(services)
        }
    }

    private fun handleScanBLECharacteristics(call: MethodCall, result: MethodChannel.Result) {
        val device = getDeviceOrError(call, result) ?: return
        executor.submit {
            val characteristics = mutableListOf<Map<String, Any>>()
            val latch = CountDownLatch(1)
            val gatt = device.connectGatt(context, false, object : BluetoothGattCallback() {
                override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        gatt?.services?.forEach { svc ->
                            svc.characteristics.forEach { char ->
                                characteristics.add(mapOf(
                                    "uuid" to char.uuid.toString(),
                                    "serviceUuid" to svc.uuid.toString(),
                                    "properties" to char.properties,
                                    "readable" to ((char.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0),
                                    "writeable" to ((char.properties and BluetoothGattCharacteristic.PROPERTY_WRITE) != 0),
                                    "notify" to ((char.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0)
                                ))
                            }
                        }
                    }
                    latch.countDown()
                }
                override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        gatt?.discoverServices()
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        latch.countDown()
                    }
                }
            })
            latch.await(10, TimeUnit.SECONDS)
            try { gatt?.close() } catch (_: Exception) {}
            result.success(characteristics)
        }
    }

    private fun handleTestProtocol(call: MethodCall, result: MethodChannel.Result) {
        val device = getDeviceOrError(call, result) ?: return
        val protocol = call.argument<String>("protocol") ?: ""
        executor.submit {
            val uuidMap = mapOf(
                "OBEX" to "00001106-0000-1000-8000-00805F9B34FB",
                "FTP" to "00001106-0000-1000-8000-00805F9B34FB",
                "RFCOMM" to "00001101-0000-1000-8000-00805F9B34FB",
                "L2CAP" to "00001101-0000-1000-8000-00805F9B34FB",
                "AT" to "00001101-0000-1000-8000-00805F9B34FB",
                "HID" to "00001124-0000-1000-8000-00805F9B34FB",
                "PBAP" to "0000112F-0000-1000-8000-00805F9B34FB",
                "A2DP" to "0000110B-0000-1000-8000-00805F9B34FB",
                "MAP" to "00001133-0000-1000-8000-00805F9B34FB",
                "OPP" to "00001105-0000-1000-8000-00805F9B34FB"
            )
            val uuidStr = uuidMap[protocol.uppercase()] ?: "00001101-0000-1000-8000-00805F9B34FB"
            try {
                val socket = device.createInsecureRfcommSocketToServiceRecord(UUID.fromString(uuidStr))
                socket.connect()
                val isConnected = socket.isConnected
                socket.close()
                result.success(isConnected)
            } catch (_: Exception) {
                result.success(false)
            }
        }
    }
}
