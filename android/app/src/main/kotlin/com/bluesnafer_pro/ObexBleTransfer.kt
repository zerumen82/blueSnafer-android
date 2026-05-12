package com.bluesnafer_pro

import android.bluetooth.*
import android.content.Context
import android.util.Log
import java.io.File
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

object ObexBleTransfer {
    private val OBEX_SERVICE_UUID = UUID.fromString("00001106-0000-1000-8000-00805F9B34FB")
    private val OBEX_CHAR_UUID = UUID.fromString("00001106-0000-1000-8000-00805F9B34FB")
    private const val TAG = "ObexBleTransfer"

    fun transferFileViaBle(context: Context, device: BluetoothDevice, filePath: String): Map<String, Any> {
        return try {
            val latch = CountDownLatch(1)
            var result = mapOf("success" to false, "error" to "Timeout")
            var gatt: BluetoothGatt? = null

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
                        if (response != null && response.isNotEmpty() && (response[0].toInt() and 0xFF) == 0xA0) {
                            Log.d(TAG, "OBEX connect success response received")
                            transferFileChunks(gatt, filePath)
                        } else {
                            result = mapOf("success" to false, "error" to "Invalid OBEX response")
                            latch.countDown()
                        }
                    }
                }
            }

            gatt = device.connectGatt(context, false, gattCallback)
            latch.await(30, java.util.concurrent.TimeUnit.SECONDS)
            gatt?.close()

            return result
        } catch (e: Exception) {
            return mapOf("success" to false, "error" to (e.message ?: "unknown error"))
        }
    }

    private fun transferFileChunks(gatt: BluetoothGatt, filePath: String) {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                return
            }

            val fileBytes = file.readBytes()
            val chunkSize = 20
            var offset = 0

            Log.d(TAG, "Starting transfer of ${fileBytes.size} bytes")

            while (offset < fileBytes.size) {
                val chunkSizeActual = minOf(chunkSize, fileBytes.size - offset)
                val chunk = ByteArray(chunkSizeActual + 3)

                chunk[0] = 0x02
                chunk[1] = (chunkSizeActual + 3).toByte()
                chunk[2] = 0

                fileBytes.copyInto(chunk, 3, offset, offset + chunkSizeActual)

                gatt.writeCharacteristic(gatt.getService(OBEX_SERVICE_UUID)?.getCharacteristic(OBEX_CHAR_UUID)?.also { it.value = chunk })
                Thread.sleep(10)
                offset += chunkSizeActual
            }

            Log.d(TAG, "Transfer completed")
        } catch (e: Exception) {
            Log.e(TAG, "Transfer error", e)
        }
    }
}