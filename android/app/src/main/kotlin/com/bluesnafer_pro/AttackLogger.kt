package com.bluesnafer_pro

import android.content.Context
import io.flutter.plugin.common.EventChannel
import java.io.*
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executors

/**
 * Sistema de logs persistente en memoria del dispositivo
 * Guarda logs en:
 * 1. /data/data/com.bluesnafer_pro/files/bluesnafer_logs/ (interno, privado)
 * 2. /storage/emulated/0/Android/data/com.bluesnafer_pro/files/bluesnafer_logs/ (externo, accesible por USB)
 */
object AttackLogger {
    private const val TAG = "AttackLogger"
    private const val LOG_DIR = "bluesnafer_logs"
    private const val MAX_LOG_FILES = 10
    private const val MAX_LOG_SIZE = 5 * 1024 * 1024 // 5MB
    
    private var appContext: Context? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
    private val fileDateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
    private var eventSink: EventChannel.EventSink? = null
    
    fun init(context: Context) {
        appContext = context
        cleanOldLogs()
    }
    
    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }
    
    fun info(tag: String, message: String, details: Map<String, Any>? = null) {
        log("INFO", tag, message, details)
        sendToFlutter("[$tag] INFO: $message")
    }
    
    fun warn(tag: String, message: String, details: Map<String, Any>? = null) {
        log("WARN", tag, message, details)
        sendToFlutter("[$tag] WARN: $message")
    }
    
    fun error(tag: String, message: String, error: Throwable? = null) {
        val details = error?.let { 
            mapOf("error" to (it.message ?: "Unknown error"), "stacktrace" to it.stackTraceToString().take(500))
        }
        log("ERROR", tag, message, details)
        sendToFlutter("[$tag] ERROR: $message - ${error?.message ?: ""}")
    }
    
    fun attackResult(attackType: String, target: String, success: Boolean, details: Map<String, Any>) {
        val message = "Attack $attackType on $target: ${if (success) "SUCCESS" else "FAILED"}"
        log("ATTACK", "ExploitIntegration", message, details)
        sendToFlutter("[$attackType] $message")
    }
    
    private fun sendToFlutter(logMessage: String) {
        try {
            eventSink?.success(logMessage)
        } catch (e: Exception) {
            e.printStackTrace()
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
    
    private fun log(level: String, tag: String, message: String, details: Map<String, Any>? = null) {
        executor.submit {
            try {
                val ctx = appContext ?: run {
                    println("AttackLogger: Context not initialized!")
                    return@submit
                }
                
                // Write to internal storage
                writeLogToFile(File(ctx.filesDir, LOG_DIR), level, tag, message, details)
                
                // Write to external storage (accessible via USB)
                getExternalLogDir()?.let { externalDir ->
                    writeLogToFile(externalDir, level, tag, message, details)
                }
                
            } catch (e: Exception) {
                println("AttackLogger: Failed to write log: ${e.message}")
                e.printStackTrace()
            }
        }
    }
    
    private fun writeLogToFile(logDir: File, level: String, tag: String, message: String, details: Map<String, Any>? = null) {
        try {
            if (!logDir.exists()) {
                logDir.mkdirs()
            }
            
            val today = fileDateFormat.format(Date())
            val logFile = File(logDir, "attack_log_$today.txt")
            
            // Rotar archivo si es muy grande
            if (logFile.length() > MAX_LOG_SIZE) {
                val rotated = File(logDir, "attack_log_${today}_${System.currentTimeMillis()}.txt")
                logFile.renameTo(rotated)
            }
            
            val timestamp = dateFormat.format(Date())
            val logEntry = StringBuilder()
            logEntry.append("[$timestamp] [$level] $tag: $message")
            
            details?.let {
                logEntry.append("\n  Details: ${it.toFormattedString()}")
            }
            
            logEntry.append("\n")
            
            FileOutputStream(logFile, true).use { fos ->
                fos.write(logEntry.toString().toByteArray())
                fos.flush()
            }
            
        } catch (e: Exception) {
            println("AttackLogger: Failed to write log to ${logDir.absolutePath}: ${e.message}")
        }
    }
    
    private fun cleanOldLogs() {
        executor.submit {
            try {
                // Clean internal
                cleanOldLogsFromDir(File(appContext!!.filesDir, LOG_DIR))
                // Clean external
                getExternalLogDir()?.let { cleanOldLogsFromDir(it) }
            } catch (e: Exception) {
                e.printStackTrace()
            }
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
            e.printStackTrace()
        }
    }
    
    fun clearLogs() {
        executor.submit {
            try {
                // Clear internal
                val internalDir = File(appContext!!.filesDir, LOG_DIR)
                if (internalDir.exists()) {
                    internalDir.deleteRecursively()
                    internalDir.mkdirs() // Recreate directory
                }
                // Clear external
                getExternalLogDir()?.let { externalDir ->
                    if (externalDir.exists()) {
                        externalDir.deleteRecursively()
                        externalDir.mkdirs()
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
    
    // ===== Get all logs from external storage for export =====
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
}

/**
 * Extensión para formatear Map a String
 */
private fun Map<String, Any>.toFormattedString(): String {
    return this.entries.joinToString(", ") { "${it.key}=${it.value}" }
}