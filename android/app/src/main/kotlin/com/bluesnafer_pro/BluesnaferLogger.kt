package com.bluesnafer_pro

import android.util.Log
import android.content.Context
import io.flutter.plugin.common.EventChannel
import java.io.*
import java.text.SimpleDateFormat
import java.util.*

/**
 * Logger personalizado que guarda TODOS los logs en memoria del dispositivo
 * automaticamente. Reemplaza a android.util.Log.
 * 
 * Guarda en:
 * 1. /data/data/com.bluesnafer_pro/files/bluesnafer_logs/ (interno, privado)
 * 2. /storage/emulated/0/Android/data/com.bluesnafer_pro/files/bluesnafer_logs/ (externo, accesible por USB)
 */
object BluesnaferLogger {
    private const val TAG = "BluesnaferLogger"
    private const val LOG_DIR = "bluesnafer_logs"
    private const val MAX_LOG_SIZE = 5 * 1024 * 1024 // 5MB
    private const val MAX_LOG_FILES = 10
    
    private var appContext: Context? = null
    private var eventSink: EventChannel.EventSink? = null
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
    private val fileDateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
    
    fun init(context: Context) {
        appContext = context
        cleanOldLogs()
    }
    
    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun getEventSink(): EventChannel.EventSink? = eventSink
    
    // ===== Wrapper methods for Log.d, Log.e, Log.w, Log.i =====
    fun d(tag: String, message: String) {
        Log.d(tag, message)
        writeLog("DEBUG", tag, message)
        sendToFlutter("[$tag] $message")
    }
    
    fun e(tag: String, message: String) {
        Log.e(tag, message)
        writeLog("ERROR", tag, message)
        sendToFlutter("[$tag] ERROR: $message")
    }
    
    fun e(tag: String, message: String, tr: Throwable) {
        Log.e(tag, message, tr)
        val details = mapOf("error" to (tr.message ?: "Unknown"), "stacktrace" to tr.stackTraceToString().take(500))
        writeLog("ERROR", tag, "$message - ${tr.message}", details)
        sendToFlutter("[$tag] ERROR: $message - ${tr.message}")
    }
    
    fun w(tag: String, message: String) {
        Log.w(tag, message)
        writeLog("WARN", tag, message)
        sendToFlutter("[$tag] WARN: $message")
    }
    
    fun i(tag: String, message: String) {
        Log.i(tag, message)
        writeLog("INFO", tag, message)
        sendToFlutter("[$tag] INFO: $message")
    }
    
    private fun sendToFlutter(logMessage: String) {
        try {
            eventSink?.success(logMessage)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send log to Flutter: ${e.message}")
        }
    }
    
    // ===== Get external storage directory (accessible via USB) =====
    private fun getExternalLogDir(): File? {
        return try {
            val externalDir = appContext?.getExternalFilesDir(null)
            File(externalDir, LOG_DIR).also {
                if (!it.exists()) it.mkdirs()
            }
        } catch (e: Exception) {
            null
        }
    }
    
    // ===== Write log to internal and external storage =====
    private fun writeLog(level: String, tag: String, message: String, details: Map<String, Any>? = null) {
        try {
            val ctx = appContext ?: run {
                println("BluesnaferLogger: Context not initialized!")
                return
            }
            
            // Write to internal storage
            writeLogToFile(File(ctx.filesDir, LOG_DIR), level, tag, message, details)
            
            // Write to external storage (accessible via USB)
            getExternalLogDir()?.let { externalDir ->
                writeLogToFile(externalDir, level, tag, message, details)
            }
            
        } catch (e: Exception) {
            println("BluesnaferLogger: Failed to write log: ${e.message}")
            e.printStackTrace()
        }
    }
    
    private fun writeLogToFile(logDir: File, level: String, tag: String, message: String, details: Map<String, Any>? = null) {
        try {
            if (!logDir.exists()) {
                logDir.mkdirs()
            }
            
            val today = fileDateFormat.format(Date())
            val logFile = File(logDir, "all_logs_$today.txt")
            
            // Rotate if too large
            if (logFile.length() > MAX_LOG_SIZE) {
                val rotated = File(logDir, "all_logs_${today}_${System.currentTimeMillis()}.txt")
                logFile.renameTo(rotated)
            }
            
            val timestamp = dateFormat.format(Date())
            val logEntry = StringBuilder()
            logEntry.append("[$timestamp] [$level] $tag: $message")
            
            details?.let {
                logEntry.append("\n  Details: ${it.entries.joinToString(", ") { "${it.key}=${it.value}" }}")
            }
            
            logEntry.append("\n")
            
            FileOutputStream(logFile, true).use { fos ->
                fos.write(logEntry.toString().toByteArray())
                fos.flush()
            }
        } catch (e: Exception) {
            println("BluesnaferLogger: Failed to write log to ${logDir.absolutePath}: ${e.message}")
        }
    }
    
    // ===== Get all logs from external storage =====
    fun getAllLogsExternal(): String {
        return try {
            val externalDir = getExternalLogDir() ?: return "No external storage available"
            val files = externalDir.listFiles { f -> f.name.endsWith(".txt") }
                ?.sortedByDescending { it.lastModified() }
                ?.flatMap { file ->
                    try {
                        file.readLines()
                    } catch (e: Exception) {
                        emptyList()
                    }
                } ?: emptyList()
            files.joinToString("\n")
        } catch (e: Exception) {
            "Error reading external logs: ${e.message}"
        }
    }
    
    // ===== Get all logs from internal storage =====
    fun getAllLogs(): List<String> {
        return try {
            val logDir = File(appContext!!.filesDir, LOG_DIR)
            logDir.listFiles { f -> f.name.endsWith(".txt") }
                ?.sortedByDescending { it.lastModified() }
                ?.flatMap { file ->
                    try {
                        file.readLines()
                    } catch (e: Exception) {
                        emptyList()
                    }
                } ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }
    
    fun getAllLogsAsString(): String {
        return getAllLogs().joinToString("\n")
    }
    
    // ===== Clean old logs from both storages =====
    private fun cleanOldLogs() {
        try {
            // Clean internal
            cleanOldLogsFromDir(File(appContext!!.filesDir, LOG_DIR))
            // Clean external
            getExternalLogDir()?.let { cleanOldLogsFromDir(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clean old logs", e)
        }
    }
    
    private fun cleanOldLogsFromDir(logDir: File) {
        try {
            val files = logDir.listFiles { f -> f.name.endsWith(".txt") }
                ?.sortedByDescending { it.lastModified() }
            
            files?.let {
                if (it.size > MAX_LOG_FILES) {
                    it.drop(MAX_LOG_FILES).forEach { f ->
                        f.delete()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clean old logs from ${logDir.absolutePath}", e)
        }
    }
    
    fun clearAllLogs() {
        try {
            // Clear internal
            val internalDir = File(appContext!!.filesDir, LOG_DIR)
            if (internalDir.exists()) {
                internalDir.deleteRecursively()
                internalDir.mkdirs()
            }
            // Clear external
            getExternalLogDir()?.let { externalDir ->
                if (externalDir.exists()) {
                    externalDir.deleteRecursively()
                    externalDir.mkdirs()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clear logs", e)
        }
    }
}
