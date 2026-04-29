# Native Android Dependencies - BlueSnafer Pro

## Overview
The BlueSnafer Pro application relies on native Android (Kotlin) implementations for critical Bluetooth exploitation and system-level operations. These native components are invoked via Flutter MethodChannels and are **required** for the application to function.

## Required Native Implementation Files

### 1. AndroidManifest.xml Permissions
The following permissions must be declared in `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Bluetooth Classic -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />

<!-- Location (required for Bluetooth scanning on Android 12+) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- Storage -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />

<!-- Network -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />

<!-- System -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.DISABLE_KEYGUARD" />

<!-- Root/ADB (optional, for advanced exploits) -->
<uses-permission android:name="android.permission.ACCESS_SUPERUSER" />
```

### 2. MainActivity.kt
Location: `android/app/src/main/kotlin/com/bluesnafer_pro/MainActivity.kt`

Required to handle MethodChannel communication:

```kotlin
package com.bluesnafer_pro

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.bluetooth.*
import android.content.Context
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.bluesnafer_pro/bluetooth"
    private val EXPLOIT_CHANNEL = "exploit_integration"
    private val EVENT_CHANNEL = "exploit_events"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "fuzzSDP" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(fuzzSDPServices(deviceAddress))
                }
                "fuzzBLECharacteristics" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(fuzzBLECharacteristics(deviceAddress))
                }
                "fuzzATCommands" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(fuzzATCommands(deviceAddress))
                }
                "fuzzFileProtocols" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(fuzzFileProtocols(deviceAddress))
                }
                "testBufferOverflows" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(testBufferOverflows(deviceAddress))
                }
                "installBluetoothBackdoor" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(installBluetoothBackdoor(deviceAddress))
                }
                "modifyAutoPairing" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(modifyAutoPairing(deviceAddress))
                }
                "injectBLEService" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(injectBLEService(deviceAddress))
                }
                "createAutoConnectProfile" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(createAutoConnectProfile(deviceAddress))
                }
                "modifyDeviceWhitelist" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(modifyDeviceWhitelist(deviceAddress))
                }
                "executeBlueBorneExploit" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(executeBlueBorneExploit(deviceAddress))
                }
                "executeDoS" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    val duration = call.argument<Int>("duration") ?: 60
                    result.success(executeDoS(deviceAddress, duration))
                }
                "executeOBEXExtract" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(executeOBEXExtract(deviceAddress))
                }
                "executePBAPExtract" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(executePBAPExtract(deviceAddress))
                }
                "executeHIDInject" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    val script = call.argument<String>("script")
                    result.success(executeHIDInject(deviceAddress, script))
                }
                "executeSDPDiscover" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(executeSDPDiscover(deviceAddress))
                }
                "executeBypassQuickConnect" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(executeBypassQuickConnect(deviceAddress))
                }
                "executeMACSpoofTrust" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(executeMACSpoofTrust(deviceAddress))
                }
                "executeOBEXTrustAbuse" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(executeOBEXTrustAbuse(deviceAddress))
                }
                "executeOPPPush" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    val filePath = call.argument<String>("filePath")
                    result.success(executeOPPPush(deviceAddress, filePath))
                }
                "executeGATTFlood" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    val duration = call.argument<Int>("duration") ?: 30
                    result.success(executeGATTFlood(deviceAddress, duration))
                }
                "executeL2CAPFlood" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    val duration = call.argument<Int>("duration") ?: 30
                    result.success(executeL2CAPFlood(deviceAddress, duration))
                }
                "executeMTUCrash" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(executeMTUCrash(deviceAddress))
                }
                "scanOBEXServices" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(scanOBEXServices(deviceAddress))
                }
                "downloadFile" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    val remotePath = call.argument<String>("remotePath")
                    result.success(downloadFile(deviceAddress, remotePath))
                }
                else -> result.notImplemented()
            }
        }
    }
    
    // Native implementation stubs - these must be implemented
    private fun fuzzSDPServices(deviceAddress: String?): Map<String, Any> {
        // TODO: Implement SDP fuzzing using Bluetooth API
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun fuzzBLECharacteristics(deviceAddress: String?): Map<String, Any> {
        // TODO: Implement BLE characteristic fuzzing
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun fuzzATCommands(deviceAddress: String?): Map<String, Any> {
        // TODO: Implement AT command fuzzing
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun fuzzFileProtocols(deviceAddress: String?): Map<String, Any> {
        // TODO: Implement OBEX/FTP fuzzing
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun testBufferOverflows(deviceAddress: String?): Map<String, Any> {
        // TODO: Implement buffer overflow testing
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun installBluetoothBackdoor(deviceAddress: String?): Boolean {
        // TODO: Implement backdoor installation
        return false
    }
    
    private fun modifyAutoPairing(deviceAddress: String?): Boolean {
        // TODO: Implement auto-pairing modification
        return false
    }
    
    private fun injectBLEService(deviceAddress: String?): Boolean {
        // TODO: Implement BLE service injection
        return false
    }
    
    private fun createAutoConnectProfile(deviceAddress: String?): Boolean {
        // TODO: Implement auto-connect profile creation
        return false
    }
    
    private fun modifyDeviceWhitelist(deviceAddress: String?): Boolean {
        // TODO: Implement whitelist modification
        return false
    }
    
    private fun executeBlueBorneExploit(deviceAddress: String?): Map<String, Any> {
        // TODO: Implement BlueBorne exploit
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun executeDoS(deviceAddress: String?, duration: Int): Map<String, Any> {
        // TODO: Implement DoS attacks
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun executeOBEXExtract(deviceAddress: String?): Map<String, Any> {
        // TODO: Implement OBEX file extraction
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun executePBAPExtract(deviceAddress: String?): Map<String, Any> {
        // TODO: Implement PBAP contact extraction
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun executeHIDInject(deviceAddress: String?, script: String?): Map<String, Any> {
        // TODO: Implement HID script injection
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun executeSDPDiscover(deviceAddress: String?): Map<String, Any> {
        // TODO: Implement SDP discovery
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun executeBypassQuickConnect(deviceAddress: String?): Map<String, Any> {
        // TODO: Implement Quick Connect bypass
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun executeMACSpoofTrust(deviceAddress: String?): Map<String, Any> {
        // TODO: Implement MAC spoofing for trust bypass
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun executeOBEXTrustAbuse(deviceAddress: String?): Map<String, Any> {
        // TODO: Implement OBEX trust abuse
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun executeOPPPush(deviceAddress: String?, filePath: String?): Map<String, Any> {
        // TODO: Implement OPP file push
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun executeGATTFlood(deviceAddress: String?, duration: Int): Map<String, Any> {
        // TODO: Implement GATT flood attack
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun executeL2CAPFlood(deviceAddress: String?, duration: Int): Map<String, Any> {
        // TODO: Implement L2CAP flood attack
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun executeMTUCrash(deviceAddress: String?): Map<String, Any> {
        // TODO: Implement MTU crash attack
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun scanOBEXServices(deviceAddress: String?): Map<String, Any> {
        // TODO: Implement OBEX service scanning
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun downloadFile(deviceAddress: String?, remotePath: String?): Map<String, Any> {
        // TODO: Implement file download via Bluetooth
        return mapOf("success" to false, "error" to "Not implemented")
    }
}
```

### 3. ExploitIntegration.kt
Location: `android/app/src/main/kotlin/com/bluesnafer_pro/ExploitIntegration.kt`

Handles exploit execution and event broadcasting:

```kotlin
package com.bluesnafer_pro

import android.bluetooth.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class ExploitIntegration: FlutterActivity() {
    private val CHANNEL = "exploit_integration"
    private val EVENT_CHANNEL = "exploit_events"
    private var eventSink: EventChannel.EventSink? = null
    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup event channel for real-time exploit events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "executeAttack" -> {
                    val type = call.argument<String>("type")
                    val deviceAddress = call.argument<String>("deviceAddress")
                    val params = call.argument<Map<String, Any>>("params")
                    result.success(executeAttack(type, deviceAddress, params))
                }
                "scanOBEXServices" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(scanOBEXServices(deviceAddress))
                }
                "pbapExtract" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(pbapExtract(deviceAddress))
                }
                "downloadFile" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    val remotePath = call.argument<String>("remotePath")
                    result.success(downloadFile(deviceAddress, remotePath))
                }
                "executeDoS" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    val duration = call.argument<Int>("duration") ?: 60
                    result.success(executeDoS(deviceAddress, duration))
                }
                "sdpDiscover" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(sdpDiscover(deviceAddress))
                }
                "injectHIDScript" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    val script = call.argument<String>("script")
                    result.success(injectHIDScript(deviceAddress, script))
                }
                "bypassQuickConnect" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    result.success(bypassQuickConnect(deviceAddress))
                }
                "oppPush" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    val filePath = call.argument<String>("filePath")
                    result.success(oppPush(deviceAddress, filePath))
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun executeAttack(type: String?, deviceAddress: String?, params: Map<String, Any>?): Map<String, Any> {
        sendEvent("attack_started", mapOf("type" to type, "device" to deviceAddress))
        
        return try {
            val success = when (type) {
                "blueborne" -> executeBlueBorne(deviceAddress)
                "dos" -> executeDoSAttack(deviceAddress, params)
                "obex_extract" -> executeOBEXExtraction(deviceAddress)
                "pbap_extract" -> executePBAPExtraction(deviceAddress)
                "hid_inject" -> executeHIDInjection(deviceAddress, params)
                "mac_spoof" -> executeMACSpoofing(deviceAddress)
                "snoop" -> executeSnooping(deviceAddress)
                else -> false
            }
            
            sendEvent("attack_completed", mapOf("type" to type, "success" to success))
            mapOf("success" to success, "type" to type)
        } catch (e: Exception) {
            sendEvent("attack_failed", mapOf("type" to type, "error" to e.message))
            mapOf("success" to false, "error" to e.message)
        }
    }
    
    private fun executeBlueBorne(deviceAddress: String?): Boolean {
        // TODO: Implement BlueBorne CVE-2017-0781 exploit
        return false
    }
    
    private fun executeDoSAttack(deviceAddress: String?, params: Map<String, Any>?): Boolean {
        // TODO: Implement DoS via L2CAP/GATT flooding
        return false
    }
    
    private fun executeOBEXExtraction(deviceAddress: String?): Boolean {
        // TODO: Implement OBEX FTP file extraction
        return false
    }
    
    private fun executePBAPExtraction(deviceAddress: String?): Boolean {
        // TODO: Implement PBAP contact extraction
        return false
    }
    
    private fun executeHIDInjection(deviceAddress: String?, params: Map<String, Any>?): Boolean {
        // TODO: Implement HID keyboard injection
        return false
    }
    
    private fun executeMACSpoofing(deviceAddress: String?): Boolean {
        // TODO: Implement MAC address spoofing
        return false
    }
    
    private fun executeSnooping(deviceAddress: String?): Boolean {
        // TODO: Implement Bluetooth snooping/sniffing
        return false
    }
    
    private fun scanOBEXServices(deviceAddress: String?): Map<String, Any> {
        // TODO: Scan OBEX services on target device
        return mapOf("services" to emptyList<Any>())
    }
    
    private fun pbapExtract(deviceAddress: String?): Map<String, Any> {
        // TODO: Extract PBAP contacts and call logs
        return mapOf("contacts" to emptyList<Any>(), "calls" to emptyList<Any>())
    }
    
    private fun downloadFile(deviceAddress: String?, remotePath: String?): Map<String, Any> {
        // TODO: Download file via OBEX FTP
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun executeDoS(deviceAddress: String?, duration: Int): Map<String, Any> {
        // TODO: Execute DoS attack
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun sdpDiscover(deviceAddress: String?): Map<String, Any> {
        // TODO: Discover SDP services
        return mapOf("services" to emptyList<Any>())
    }
    
    private fun injectHIDScript(deviceAddress: String?, script: String?): Map<String, Any> {
        // TODO: Inject HID script
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun bypassQuickConnect(deviceAddress: String?): Map<String, Any> {
        // TODO: Bypass Quick Connect authentication
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun oppPush(deviceAddress: String?, filePath: String?): Map<String, Any> {
        // TODO: Push file via OPP
        return mapOf("success" to false, "error" to "Not implemented")
    }
    
    private fun sendEvent(eventType: String, data: Map<String, Any>) {
        eventSink?.success(mapOf(
            "type" to eventType,
            "timestamp" to System.currentTimeMillis(),
            "data" to data
        ))
    }
}
```

### 4. TFLite Model Integration

The AI service expects TFLite models in `android/app/src/main/assets/models/`:

- `pin_bypass_predictor.tflite` - PIN bypass prediction model
- `attack_success_predictor.tflite` - Attack success probability model
- `device_classifier.tflite` - Device classification model
- `java_exploit_generator.tflite` - Exploit code generation model

### 5. Required Android SDK Configuration

`android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
        // ...
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}

dependencies {
    implementation 'androidx.core:core-ktx:1.12.0'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.10.0'
    // Bluetooth dependencies
    implementation 'androidx.core:core-splashscreen:1.0.1'
}
```

## Implementation Priority

### Critical (Required for basic functionality):
1. SDP discovery and service enumeration
2. OBEX FTP file operations
3. PBAP contact extraction
4. HID script injection
5. DoS attack implementation

### High Priority:
6. BlueBorne exploit (CVE-2017-0781)
7. MAC spoofing and trust bypass
8. Quick Connect authentication bypass
9. OBEX trust abuse

### Medium Priority:
10. BLE characteristic fuzzing
11. AT command injection
12. Buffer overflow exploits
13. Backdoor installation

### Low Priority:
14. L2CAP/GATT flooding
15. MTU crash attacks
16. Persistence mechanisms

## Security Considerations

⚠️ **WARNING**: This application is designed for authorized security testing only. All native implementations must:

1. Include proper authorization checks
2. Log all operations for audit trails
3. Implement rate limiting to prevent abuse
4. Require explicit user consent for each operation
5. Include safety checks to prevent accidental damage

## Testing Native Implementation

To verify native implementation is working:

```bash
# Check if MethodChannel is responding
adb logcat | grep -E "(MethodChannel|ExploitIntegration|Bluetooth)"

# Test basic Bluetooth operations
adb shell am start -n com.bluesnafer_pro/.MainActivity

# Monitor exploit events
adb logcat | grep "ExploitEvent"
```

## Troubleshooting

### MethodChannel not responding
- Verify MainActivity.kt is properly configured
- Check FlutterEngine initialization
- Ensure method names match between Dart and Kotlin

### Bluetooth operations failing
- Verify all permissions are granted
- Check Bluetooth adapter state
- Ensure location services are enabled (Android 12+)

### TFLite model errors
- Verify models are in `assets/models/`
- Check pubspec.yaml asset declarations
- Ensure model files are not corrupted

## References

- [Android Bluetooth API](https://developer.android.com/guide/topics/connectivity/bluetooth)
- [Bluetooth Classic vs BLE](https://developer.android.com/guide/topics/connectivity/bluetooth/ble-overview)
- [OBEX Protocol](https://www.bluetooth.com/specifications/specs/object-push-profile-1-2/)
- [PBAP Specification](https://www.bluetooth.com/specifications/specs/phone-book-access-profile-1-2/)
- [BlueBorne Vulnerabilities](https://armis.com/blueborne/)
