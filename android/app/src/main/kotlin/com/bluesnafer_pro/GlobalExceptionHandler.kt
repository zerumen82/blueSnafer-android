@file:OptIn(kotlin.experimental.ExperimentalTypeInference::class)

package com.bluesnafer_pro

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.os.Environment
import android.util.Log
import java.io.File
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

object GlobalExceptionHandler {
    private const val TAG = "GlobalExceptionHandler"

    private val exceptionLog = mutableListOf<ExceptionRecord>()
    private val maxLogSize = 1000

    data class ExceptionRecord(
        val timestamp: Long = System.currentTimeMillis(),
        val exception: String,
        val stackTrace: String,
        val context: String,
        val deviceAddress: String? = null
    )

    fun logException(exception: Exception, context: Context, contextDesc: String, deviceAddress: String? = null) {
        val record = ExceptionRecord(
            exception = exception.toString(),
            stackTrace = exception.stackTraceToString(),
            context = contextDesc,
            deviceAddress = deviceAddress
        )

        synchronized(exceptionLog) {
            exceptionLog.add(record)

            // Mantener solo las últimas N excepciones
            if (exceptionLog.size > maxLogSize) {
                exceptionLog.removeAt(0)
            }
        }

        // Log inmediato para debugging
        Log.e(TAG, "Exception in $contextDesc: ${exception.message ?: "Unknown error"}", exception)

        // Guardar en archivo si es posible
        saveExceptionToFile(record, context)
    }

    fun getExceptionHistory(limit: Int = 50): List<ExceptionRecord> {
        val recent = synchronized(exceptionLog) {
            exceptionLog.takeLast(limit)
        }

        return recent
    }

    fun clearExceptionHistory() {
        synchronized(exceptionLog) {
            exceptionLog.clear()
        }
    }

    fun getExceptionStats(): Map<String, Any> {
        val result = synchronized(exceptionLog) {
            val recentExceptions = exceptionLog.filter {
                it.timestamp > System.currentTimeMillis() - (24 * 60 * 60 * 1000) // Últimas 24 horas
            }

            val statsByContext = recentExceptions.groupBy { it.context }
                .mapValues { it.value.size }

            mapOf<String, Any>(
                "total_exceptions" to exceptionLog.size,
                "recent_exceptions_24h" to recentExceptions.size,
                "exceptions_by_context" to statsByContext,
                "most_common_context" to (statsByContext.maxByOrNull { it.value }?.key ?: "None")
            )
        }

        return result
    }

    private fun saveExceptionToFile(record: ExceptionRecord, context: Context) {
        try {
            val logDir = File(context.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS), "BlueSnafer_Logs")
            logDir.mkdirs()

            val logFile = File(logDir, "exceptions.log")

            logFile.appendText(
                "[${LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))}] " +
                "Context: ${record.context} | " +
                "Device: ${record.deviceAddress ?: "N/A"} | " +
                "Exception: ${record.exception}\n",
                Charsets.UTF_8
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error saving exception to file", e)
        }
    }
}
