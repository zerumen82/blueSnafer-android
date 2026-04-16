package com.bluesnafer_pro

import android.bluetooth.*
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

/**
 * Gestor de conexiones GATT real para operaciones asíncronas.
 */
object GattConnectionManager {
    private const val TAG = "GattConnectionManager"
    private val activeGatts = ConcurrentHashMap<String, BluetoothGatt>()

    /**
     * Conecta a un dispositivo y descubre sus servicios de forma real.
     */
    suspend fun executeWithRetry(
        context: Context,
        device: BluetoothDevice,
        maxRetries: Int = 2,
        timeoutMs: Long = 15000,
        operation: suspend (BluetoothGatt) -> Map<String, Any>,
        onLog: (String) -> Unit = {}
    ): Map<String, Any>? {
        var lastException: Exception? = null

        for (attempt in 1..maxRetries) {
            try {
                onLog("[GATT] Intento $attempt: Conectando a ${device.address}...")
                val gatt = connect(context, device, timeoutMs, onLog)
                try {
                    onLog("[GATT] Descubriendo servicios...")
                    if (!discoverServices(gatt, timeoutMs)) {
                        throw Exception("Fallo al descubrir servicios")
                    }
                    onLog("[GATT] Servicios descubiertos: ${gatt.services.size}")
                    return operation(gatt)
                } finally {
                    disconnect(gatt, onLog)
                }
            } catch (e: Exception) {
                lastException = e
                onLog("[GATT] Error en intento $attempt: ${e.message}")
                kotlinx.coroutines.delay(2000) // Espera antes de reintentar
            }
        }
        
        onLog("[GATT] Todos los intentos fallaron. Último error: ${lastException?.message}")
        return null
    }

    private suspend fun connect(
        context: Context,
        device: BluetoothDevice,
        timeoutMs: Long,
        onLog: (String) -> Unit
    ): BluetoothGatt = suspendCancellableCoroutine { continuation ->
        val callback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS && newState == BluetoothProfile.STATE_CONNECTED) {
                    onLog("[GATT] Conectado a ${device.address}")
                    if (continuation.isActive) continuation.resume(gatt)
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    onLog("[GATT] Desconectado de ${device.address}")
                    gatt.close()
                    if (continuation.isActive) {
                        continuation.resumeWithException(Exception("Desconectado con status: $status"))
                    }
                }
            }

            override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    val data = characteristic.value
                    val dataHex = data.joinToString("") { String.format("%02X ", it) }
                    
                    ExploitIntegration.sendEvent(mapOf(
                        "type" to "GATT_READ_DUMP",
                        "uuid" to characteristic.uuid.toString(),
                        "data" to dataHex,
                        "ascii" to String(data, Charsets.US_ASCII).replace(Regex("[^\\x20-\\x7E]"), "."),
                        "timestamp" to System.currentTimeMillis()
                    ))
                }
            }

            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                val data = characteristic.value
                val dataHex = data.joinToString("") { String.format("%02X ", it) }
                
                // Enviar al canal de eventos de ExploitIntegration
                ExploitIntegration.sendEvent(mapOf(
                    "type" to "GATT_NOTIFICATION",
                    "uuid" to characteristic.uuid.toString(),
                    "data" to dataHex,
                    "ascii" to String(data, Charsets.US_ASCII).replace(Regex("[^\\x20-\\x7E]"), "."),
                    "timestamp" to System.currentTimeMillis()
                ))
            }
        }

        onLog("[GATT] Iniciando connectGatt...")
        val gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)

        // Manejo de timeout con scope apropiado (no GlobalScope)
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        val timeoutRunnable = Runnable {
            onLog("[GATT] Timeout de conexión superado")
            gatt.disconnect()
            gatt.close()
            if (continuation.isActive) {
                continuation.resumeWithException(Exception("Timeout de conexión"))
            }
        }
        handler.postDelayed(timeoutRunnable, timeoutMs)

        continuation.invokeOnCancellation { _: Throwable? ->
            handler.removeCallbacks(timeoutRunnable)
            gatt.disconnect()
            gatt.close()
        }
    }

    private suspend fun discoverServices(gatt: BluetoothGatt, timeoutMs: Long): Boolean = suspendCoroutine { continuation ->
        val callback = object : BluetoothGattCallback() {
            override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
                // En una implementación real, este callback debería ser el mismo que se pasó a connectGatt
                // Para este ejemplo, simplificamos la lógica de espera.
            }
        }
        
        if (!gatt.discoverServices()) {
            continuation.resume(false)
        } else {
            // Simulación simplificada de espera por servicios para este paso
            // En el siguiente paso consolidaremos los callbacks nativos
            Handler(Looper.getMainLooper()).postDelayed({
                continuation.resume(gatt.services.isNotEmpty())
            }, 3000)
        }
    }

    private fun disconnect(gatt: BluetoothGatt, onLog: (String) -> Unit) {
        try {
            onLog("[GATT] Cerrando conexión...")
            gatt.disconnect()
            gatt.close()
        } catch (e: Exception) {
            onLog("[GATT] Error al cerrar: ${e.message}")
        }
    }
}
