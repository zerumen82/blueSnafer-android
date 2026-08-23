package com.bluesnafer_pro

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothGattCharacteristic
import java.util.HashMap
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.Executors

object LogicJammerEngine {
    private val executor = Executors.newSingleThreadExecutor()
    private val activeJams = java.util.concurrent.ConcurrentHashMap<String, BluetoothGatt>()

    fun startJam(device: BluetoothDevice): Map<String, Any> {
        val result = HashMap<String, Any>()

        try {
            val latch = CountDownLatch(1)
            val readAttempts = java.util.concurrent.atomic.AtomicInteger(0)
            var jamSuccess = false
            var jamMessage = "Jam attempt failed"

            executor.submit {
                var gatt: BluetoothGatt? = null
                try {
                    val adapter = BluetoothAdapter.getDefaultAdapter()
                    if (adapter == null || !adapter.isEnabled) {
                        jamMessage = "Bluetooth not available"
                        return@submit
                    }

                    val context = ExploitIntegration.getAppContext()
                    if (context == null) {
                        jamMessage = "No context available"
                        return@submit
                    }

                    gatt = device.connectGatt(context, false, object : BluetoothGattCallback() {
                        override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
                            if (newState == BluetoothProfile.STATE_CONNECTED) {
                                gatt?.discoverServices()
                            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                                latch.countDown()
                            }
                        }

                        override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
                            if (status != BluetoothGatt.GATT_SUCCESS || gatt == null) {
                                latch.countDown()
                                return
                            }
                            var issued = 0
                            gatt.services.forEach { service ->
                                service.characteristics.take(5).forEach { char ->
                                    if (char.properties and BluetoothGattCharacteristic.PROPERTY_READ != 0) {
                                        try {
                                            if (gatt.readCharacteristic(char)) issued++
                                        } catch (_: Exception) {}
                                    }
                                }
                            }
                            readAttempts.addAndGet(issued)
                            jamSuccess = issued > 0
                            jamMessage = if (issued > 0) {
                                "Logic jam: $issued lecturas GATT iniciadas"
                            } else {
                                "Logic jam: sin características legibles"
                            }
                            latch.countDown()
                        }
                    }, BluetoothDevice.TRANSPORT_LE)

                    if (gatt != null) {
                        activeJams[device.address] = gatt
                    }
                    latch.await(8, TimeUnit.SECONDS)
                } catch (e: Exception) {
                    jamMessage = "Error: ${e.message}"
                } finally {
                    result["success"] = jamSuccess
                    result["message"] = jamMessage
                    result["readAttempts"] = readAttempts.get()
                }
            }

            latch.await(10, TimeUnit.SECONDS)
            if (!result.containsKey("success")) {
                result["success"] = false
                result["message"] = jamMessage
                result["readAttempts"] = readAttempts.get()
            }
        } catch (e: Exception) {
            result["success"] = false
            result["message"] = "Exception: ${e.message}"
        }

        return result
    }

    fun stopJam(deviceAddress: String): Boolean {
        val gatt = activeJams.remove(deviceAddress) ?: return false
        return try {
            gatt.close()
            true
        } catch (_: Exception) {
            false
        }
    }
}
