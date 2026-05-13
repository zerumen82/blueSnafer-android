package com.bluesnafer_pro

import android.bluetooth.*
import android.content.Context
import android.util.Log
import java.io.*
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

object ObexBleTransfer {
    private val OBEX_SERVICE_UUID = UUID.fromString("00001106-0000-1000-8000-00805F9B34FB")
    private val OBEX_CHAR_UUID = UUID.fromString("00001106-0000-1000-8000-00805F9B34FB")
    private const val TAG = "ObexBleTransfer"

    /**
     * Extrae archivos del dispositivo objetivo vía OBEX over BLE GATT.
     * Intenta descargar el archivo especificado por filePath remoto.
     * Retorna mapa con success, file (nombre), size (bytes), path (local), error.
     */
    fun transferFileViaBle(context: Context, device: BluetoothDevice, remoteFilePath: String): Map<String, Any> {
        return try {
            val latch = CountDownLatch(1)
            var result: Map<String, Any> = mapOf("success" to false, "error" to "Timeout")
            var gatt: BluetoothGatt? = null
            val receivedData = ByteArrayOutputStream()
            var fileName = remoteFilePath.substringAfterLast('/').ifEmpty { "unknown" }

            val gattCallback = object : BluetoothGattCallback() {
                override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        Log.d(TAG, "GATT connected, discovering services...")
                        gatt.discoverServices()
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        Log.d(TAG, "GATT disconnected")
                        latch.countDown()
                    }
                }

                override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        Log.d(TAG, "Services discovered")
                        val service = gatt.getService(OBEX_SERVICE_UUID)
                        val characteristic = service?.getCharacteristic(OBEX_CHAR_UUID)
                        if (characteristic != null) {
                            // Enviar paquete OBEX Connect
                            val connectPkt = byteArrayOf(
                                0x80.toByte(),
                                0x00, 0x07,
                                0x10,
                                0x00,
                                0x01, 0x00
                            )
                            characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                            characteristic.value = connectPkt
                            gatt.writeCharacteristic(characteristic)
                        } else {
                            result = mapOf("success" to false, "error" to "OBEX characteristic not found")
                            latch.countDown()
                        }
                    } else {
                        result = mapOf("success" to false, "error" to "Service discovery failed: $status")
                        latch.countDown()
                    }
                }

                override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                    if (characteristic.uuid == OBEX_CHAR_UUID) {
                        if (status == BluetoothGatt.GATT_SUCCESS) {
                            Log.d(TAG, "OBEX connect written, reading response...")
                            gatt.readCharacteristic(characteristic)
                        } else {
                            result = mapOf("success" to false, "error" to "Write failed: $status")
                            latch.countDown()
                        }
                    }
                }

                override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                    if (characteristic.uuid == OBEX_CHAR_UUID && status == BluetoothGatt.GATT_SUCCESS) {
                        val response = characteristic.value
                        if (response != null && response.isNotEmpty()) {
                            when (response[0].toInt() and 0xFF) {
                                0xA0 -> {
                                    Log.d(TAG, "OBEX connect success response received")
                                    // Enviar paquete GET para el archivo
                                    sendGetRequest(gatt, remoteFilePath)
                                }
                                0xA1 -> {
                                    // Continuación de respuesta (datos de archivo)
                                    val data = response.copyOfRange(3, response.size) //.Skip header
                                    receivedData.write(data)
                                    // Solicitar más datos si hay (indicado por último paquete)
                                    if (response.size >= 20) {
                                        // Continuar leyendo
                                        gatt.readCharacteristic(characteristic)
                                    } else {
                                        // Transferencia completa
                                        saveFile(context, fileName, receivedData.toByteArray())
                                        result = mapOf(
                                            "success" to true,
                                            "file" to fileName,
                                            "size" to receivedData.size(),
                                            "path" to "Android/data/com.bluesnafer_pro/files/$fileName"
                                        )
                                        latch.countDown()
                                    }
                                }
                                0xA2 -> {
                                    // Final packet (complete)
                                    if (receivedData.size() > 0) {
                                        saveFile(context, fileName, receivedData.toByteArray())
                                        result = mapOf(
                                            "success" to true,
                                            "file" to fileName,
                                            "size" to receivedData.size(),
                                            "path" to "Android/data/com.bluesnafer_pro/files/$fileName"
                                        )
                                    } else {
                                        result = mapOf("success" to false, "error" to "No data received")
                                    }
                                    latch.countDown()
                                }
                                else -> {
                                    Log.d(TAG, "OBEX response code: ${response[0].toInt() and 0xFF}")
                                    // Intentar leer de todos modos por si hay datos
                                    val data = response.copyOfRange(3, response.size)
                                    receivedData.write(data)
                                    gatt.readCharacteristic(characteristic)
                                }
                            }
                        } else {
                            result = mapOf("success" to false, "error" to "Invalid OBEX response")
                            latch.countDown()
                        }
                    }
                }

                override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
                    // Notificación habilitada - ignorar
                }
            }

            gatt = device.connectGatt(context, false, gattCallback)
            latch.await(30, TimeUnit.SECONDS)
            gatt?.close()

            result
        } catch (e: Exception) {
            Log.e(TAG, "OBEX BLE transfer error", e)
            mapOf("success" to false, "error" to (e.message ?: "unknown error"))
        }
    }

    private fun sendGetRequest(gatt: BluetoothGatt, filePath: String) {
        val fileName = filePath.substringAfterLast('/')
        val nameBytes = fileName.toByteArray(Charsets.UTF_8)
        val pktSize = 7 + nameBytes.size
        val getPkt = ByteArray(pktSize)
        getPkt[0] = 0x83.toByte()  // GET final bit
        getPkt[1] = (pktSize ushr 8).toByte()
        getPkt[2] = (pktSize and 0xFF).toByte()
        getPkt[3] = 0x01  // Name header
        getPkt[4] = ((nameBytes.size + 3) ushr 8).toByte()
        getPkt[5] = ((nameBytes.size + 3) and 0xFF).toByte()
        getPkt[6] = 0x00
        System.arraycopy(nameBytes, 0, getPkt, 7, nameBytes.size)

        val characteristic = gatt.getService(OBEX_SERVICE_UUID)?.getCharacteristic(OBEX_CHAR_UUID)
        if (characteristic != null) {
            characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            characteristic.value = getPkt
            val written = gatt.writeCharacteristic(characteristic)
            Log.d(TAG, "OBEX GET request sent for: $fileName (written: $written)")
        } else {
            Log.e(TAG, "OBEX characteristic not found for GET request")
        }
    }

    private fun saveFile(context: Context, fileName: String, data: ByteArray): File? {
        return try {
            val dir = context.getExternalFilesDir("obex_ble") ?: context.filesDir
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, fileName)
            FileOutputStream(file).use { it.write(data) }
            Log.d(TAG, "File saved: ${file.absolutePath} (${data.size} bytes)")
            file
        } catch (e: Exception) {
            Log.e(TAG, "Error saving file", e)
            null
        }
    }
}