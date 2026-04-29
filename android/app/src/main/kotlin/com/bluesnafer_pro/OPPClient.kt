package com.bluesnafer_pro

import android.bluetooth.*
import android.util.Log
import java.io.*
import java.util.*

/**
 * Real OPP (Object Push Profile) client
 * Pushes files to target device via OBEX
 */
object OPPClient {
    private const val TAG = "OPPClient"
    private val OPP_UUID = UUID.fromString("00001105-0000-1000-8000-00805F9B34FB")
    
    /**
     * Push file via OPP - REAL implementation
     */
    fun pushFile(device: BluetoothDevice, filePath: String, onLog: (String) -> Unit = {}): Map<String, Any> {
        Log.d(TAG, "OPP push - file: $filePath to ${device.address}")
        onLog("[OPP] Pushing file: $filePath")
        
        return try {
            val file = File(filePath)
            if (!file.exists()) {
                onLog("[OPP] ✗ File not found: $filePath")
                return mapOf("success" to false, "file" to filePath, "message" to "File not found")
            }
            
            val socket = device.createInsecureRfcommSocketToServiceRecord(OPP_UUID)
            socket.connect()
            onLog("[OPP] ✓ Connected to OPP service")
            
            val input = socket.inputStream
            val output = socket.outputStream
            
            // OBEX CONNECT
            val connectPacket = byteArrayOf(
                0x80.toByte(), // Connect
                0x00, 0x07, // Length: 7
                0x10, // OBEX version 1.0
                0x00, // Flags
                0x20, 0x00 // Max packet length: 8192
            )
            
            output.write(connectPacket)
            output.flush()
            
            val connectResponse = ByteArray(1024)
            val connBytes = input.read(connectResponse)
            
            if (connBytes > 0 && (connectResponse[0].toInt() and 0xFF) == 0xA0) {
                onLog("[OPP] ✓ OBEX connected, pushing file...")
                
                // OBEX PUT with file
                val fileName = file.name
                val fileBytes = file.readBytes()
                
                // Build PUT packet with name header and file data
                val nameBytes = fileName.toByteArray(Charsets.UTF_8)
                val headerLength = 3 + nameBytes.size + 3 // Name header + data
                val packetLength = 3 + headerLength + fileBytes.size
                
                val putPacket = ByteArray(packetLength)
                var offset = 0
                
                // OBEX PUT opcode
                putPacket[offset++] = 0x02 // Put
                putPacket[offset++] = ((packetLength shr 8) and 0xFF).toByte()
                putPacket[offset++] = (packetLength and 0xFF).toByte()
                
                // Name header
                putPacket[offset++] = 0x01 // Name header
                putPacket[offset++] = ((headerLength shr 8) and 0xFF).toByte()
                putPacket[offset++] = (headerLength and 0xFF).toByte()
                putPacket[offset++] = 0x00 // Null terminator for name
                System.arraycopy(nameBytes, 0, putPacket, offset, nameBytes.size)
                offset += nameBytes.size
                
                // End of headers (0x49 = End-of-Body or 0x48 = Body)
                if (fileBytes.size > 0) {
                    putPacket[offset++] = 0x48 // Body header
                    val bodyLength = fileBytes.size + 3
                    putPacket[offset++] = ((bodyLength shr 8) and 0xFF).toByte()
                    putPacket[offset++] = (bodyLength and 0xFF).toByte()
                    System.arraycopy(fileBytes, 0, putPacket, offset, fileBytes.size)
                } else {
                    putPacket[offset++] = 0x49 // End-of-Body
                    putPacket[offset++] = 0x00
                    putPacket[offset++] = 0x03
                }
                
                output.write(putPacket)
                output.flush()
                
                Thread.sleep(500)
                
                // Read response
                val putResponse = ByteArray(1024)
                val putBytes = input.read(putResponse)
                
                if (putBytes > 0) {
                    val responseCode = putResponse[0].toInt() and 0xFF
                    if (responseCode == 0xA0 || responseCode == 0x60) { // Success or Continue
                        onLog("[OPP] ✓ File pushed successfully: ${file.name} (${file.length()} bytes)")
                        socket.close()
                        return mapOf(
                            "success" to true,
                            "file" to filePath,
                            "size" to file.length(),
                            "name" to file.name
                        )
                    } else {
                        onLog("[OPP] ✗ Push failed: ${responseCode.toString(16)}")
                    }
                }
            } else {
                onLog("[OPP] ✗ OBEX connect failed")
            }
            
            socket.close()
            mapOf("success" to false, "file" to filePath, "message" to "OPP push failed")
        } catch (e: Exception) {
            Log.e(TAG, "OPP push error: ${e.message}")
            onLog("[OPP] ✗ Error: ${e.message}")
            mapOf("success" to false, "file" to filePath, "message" to (e.message ?: "Unknown error"))
        }
    }
}
