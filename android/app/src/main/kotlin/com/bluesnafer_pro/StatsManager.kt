package com.bluesnafer_pro

import android.content.Context
import android.os.Environment
import java.io.File
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Gestor de estadísticas y métricas para exploits
 *
 * Este gestor registra y almacena estadísticas de todas las operaciones,
 * permitiendo el análisis posterior y la generación de informes.
 */
object StatsManager {
    private const val TAG = "StatsManager"
    private const val STATS_FILE = "exploit_stats.json"
    private const val MAX_STATS_HISTORY = 1000

    // Estadísticas globales
    private val globalStats = mutableMapOf<String, Any>(
        "totalExploits" to 0,
        "successfulExploits" to 0,
        "failedExploits" to 0,
        "totalDevices" to 0,
        "uniqueDevices" to emptySet<String>(),
        "exploitTypes" to emptyMap<String, Int>(),
        "cveDetection" to emptyMap<String, Int>(),
        "securityLevels" to emptyMap<String, Int>(),
        "executionTimes" to mutableListOf<Long>(),
        "firstRun" to System.currentTimeMillis()
    )

    // Historial de operaciones
    private var operationHistory = mutableListOf<OperationRecord>()

    // Estadísticas por dispositivo
    private var deviceStats = mutableMapOf<String, DeviceStatistics>()

    data class OperationRecord(
        val timestamp: Long = System.currentTimeMillis(),
        val exploitType: String,
        val deviceAddress: String,
        val deviceName: String,
        val success: Boolean,
        val durationMs: Long,
        val vulnerabilitiesFound: Int,
        val cveList: List<String>,
        val securityLevel: String,
        val errorMessage: String? = null
    )

    data class DeviceStatistics(
        val firstSeen: Long = System.currentTimeMillis(),
        val lastSeen: Long = System.currentTimeMillis(),
        val totalTests: Int = 0,
        val successfulTests: Int = 0,
        val failedTests: Int = 0,
        val vulnerabilities: Map<String, Int> = emptyMap(),
        val cveList: Set<String> = emptySet(),
        val securityLevels: Map<String, Int> = emptyMap(),
        val averageExecutionTime: Double = 0.0
    )

    data class StatsSummary(
        val totalExploits: Int,
        val successfulExploits: Int,
        val failedExploits: Int,
        val successRate: Double,
        val totalDevices: Int,
        val uniqueDevices: Int,
        val averageExecutionTime: Double,
        val mostCommonExploit: String,
        val mostCommonCVE: String?,
        val securityLevelDistribution: Map<String, Int>,
        val recentOperations: List<OperationRecord>,
        val deviceStats: Map<String, DeviceStatistics>
    )

    /**
     * Obtener estadísticas de exfilración
     */
    fun getExfiltrationStats(): Map<String, Any> {
        val exfilOps = synchronized(operationHistory) {
            operationHistory.filter { it.exploitType == "exfiltration" }
        }
        
        val totalFiles = exfilOps.size
        val successCount = exfilOps.count { it.success }
        val totalBytes = exfilOps.sumOf { it.durationMs.toInt() } // Using durationMs to store bytes transferred
        
        return mapOf(
            "filesTransferred" to totalFiles,
            "bytesTransferred" to totalBytes,
            "failedTransfers" to (totalFiles - successCount),
            "averageSpeed" to if (totalFiles > 0) totalBytes.toDouble() / totalFiles else 0.0
        )
    }
    
    /**
     * Registrar una operación de exfilración
     */
    fun recordExfiltration(deviceAddress: String, fileName: String, bytes: Int, success: Boolean) {
        val record = OperationRecord(
            exploitType = "exfiltration",
            deviceAddress = deviceAddress,
            deviceName = fileName,
            success = success,
            durationMs = 0,
            vulnerabilitiesFound = 0,
            cveList = emptyList(),
            securityLevel = if (success) "exfiltration_success" else "exfiltration_failed"
        )
        
        synchronized(operationHistory) {
            operationHistory.add(record)
            if (operationHistory.size > MAX_STATS_HISTORY) {
                operationHistory.removeAt(0)
            }
        }
        
        updateGlobalStats(record)
        updateDeviceStats(deviceAddress, record)
        
        BluesnaferLogger.d(TAG, "Exfilración registrada: $fileName to $deviceAddress - ${if (success) "Success" else "Failed"} ($bytes bytes)")
    }
    
    /**
     * Registrar una operación completada
     */
    fun recordOperation(
        exploitType: String,
        deviceAddress: String,
        deviceName: String,
        success: Boolean,
        durationMs: Long,
        vulnerabilitiesFound: Int,
        cveList: List<String>,
        securityLevel: String,
        errorMessage: String? = null
    ) {
        // Crear registro de operación
        val record = OperationRecord(
            exploitType = exploitType,
            deviceAddress = deviceAddress,
            deviceName = deviceName,
            success = success,
            durationMs = durationMs,
            vulnerabilitiesFound = vulnerabilitiesFound,
            cveList = cveList,
            securityLevel = securityLevel,
            errorMessage = errorMessage
        )

        // Añadir a historial
        synchronized(operationHistory) {
            operationHistory.add(record)

            // Mantener solo las últimas N operaciones
            if (operationHistory.size > MAX_STATS_HISTORY) {
                operationHistory.removeAt(0)
            }
        }

        // Actualizar estadísticas globales
        updateGlobalStats(record)

        // Actualizar estadísticas por dispositivo
        updateDeviceStats(deviceAddress, record)

        // Log para debugging
        BluesnaferLogger.d(
            TAG,
            "Operación registrada: ${record.exploitType} on ${record.deviceAddress} - ${if (record.success) "Success" else "Failed"} (${record.durationMs}ms)"
        )
    }

    /**
     * Actualizar estadísticas globales
     */
    private fun updateGlobalStats(record: OperationRecord) {
        synchronized(globalStats) {
            // Contadores globales
            globalStats["totalExploits"] = (globalStats["totalExploits"] as Int) + 1
            if (record.success) {
                globalStats["successfulExploits"] = (globalStats["successfulExploits"] as Int) + 1
            } else {
                globalStats["failedExploits"] = (globalStats["failedExploits"] as Int) + 1
            }

            // Dispositivos
            val uniqueDevices = globalStats["uniqueDevices"] as MutableSet<String>
            uniqueDevices.add(record.deviceAddress)
            globalStats["totalDevices"] = (globalStats["totalDevices"] as Int) + 1

            // Tipos de exploit
            val exploitTypes = globalStats["exploitTypes"] as MutableMap<String, Int>
            exploitTypes[record.exploitType] = (exploitTypes[record.exploitType] ?: 0) + 1

            // Detección de CVE
            record.cveList.forEach { cve ->
                val cveDetection = globalStats["cveDetection"] as MutableMap<String, Int>
                cveDetection[cve] = (cveDetection[cve] ?: 0) + 1
            }

            // Niveles de seguridad
            val securityLevels = globalStats["securityLevels"] as MutableMap<String, Int>
            securityLevels[record.securityLevel] = (securityLevels[record.securityLevel] ?: 0) + 1

            // Tiempos de ejecución
            val executionTimes = globalStats["executionTimes"] as MutableList<Long>
            executionTimes.add(record.durationMs)
        }
    }

    /**
     * Actualizar estadísticas por dispositivo
     */
    private fun updateDeviceStats(deviceAddress: String, record: OperationRecord) {
        synchronized(deviceStats) {
            val existingStats = deviceStats[deviceAddress] ?: DeviceStatistics(
                firstSeen = record.timestamp,
                lastSeen = record.timestamp
            )

            // Actualizar tiempos usando copy()
            var stats = existingStats.copy(lastSeen = record.timestamp)

            // Contadores
            stats = stats.copy(totalTests = stats.totalTests + 1)
            if (record.success) {
                stats = stats.copy(successfulTests = stats.successfulTests + 1)
            } else {
                stats = stats.copy(failedTests = stats.failedTests + 1)
            }

            // Vulnerabilidades
            val vulnerabilities = stats.vulnerabilities.toMutableMap()
            vulnerabilities["V${record.vulnerabilitiesFound}"] = (vulnerabilities["V${record.vulnerabilitiesFound}"] ?: 0) + 1
            stats = stats.copy(vulnerabilities = vulnerabilities)

            // CVE
            val cveSet = stats.cveList.toMutableSet()
            cveSet.addAll(record.cveList)
            stats = stats.copy(cveList = cveSet)

            // Niveles de seguridad
            val securityLevels = stats.securityLevels.toMutableMap()
            securityLevels[record.securityLevel] = (securityLevels[record.securityLevel] ?: 0) + 1
            stats = stats.copy(securityLevels = securityLevels)

            // Tiempo promedio
            val totalTime = stats.averageExecutionTime * (stats.totalTests - 1) + record.durationMs
            stats = stats.copy(averageExecutionTime = totalTime / stats.totalTests)

            deviceStats[deviceAddress] = stats
        }
    }

    /**
     * Obtener resumen de estadísticas
     */
    fun getStatsSummary(): StatsSummary {
        synchronized(globalStats) {
            val totalExploits = globalStats["totalExploits"] as? Int ?: 0
            val successfulExploits = globalStats["successfulExploits"] as? Int ?: 0
            val failedExploits = globalStats["failedExploits"] as? Int ?: 0
            val successRate = if (totalExploits > 0) {
                (successfulExploits.toDouble() / totalExploits) * 100
            } else 0.0

            val totalDevices = globalStats["totalDevices"] as? Int ?: 0
            val uniqueDevices = (globalStats["uniqueDevices"] as? Set<String>)?.size ?: 0

            val executionTimes = globalStats["executionTimes"] as? List<Long> ?: emptyList()
            val averageExecutionTime = if (executionTimes.isNotEmpty()) {
                executionTimes.average()
            } else 0.0

            val exploitTypes = globalStats["exploitTypes"] as? Map<String, Int> ?: emptyMap()
            val mostCommonExploit = exploitTypes.maxByOrNull { it.value }?.key ?: "Unknown"

            val cveDetection = globalStats["cveDetection"] as? Map<String, Int> ?: emptyMap()
            val mostCommonCVE = cveDetection.maxByOrNull { it.value }?.key

            val securityLevels = globalStats["securityLevels"] as? Map<String, Int> ?: emptyMap()

            val recentOperations = synchronized(operationHistory) {
                operationHistory.takeLast(20)
            }

            val deviceStatsCopy = synchronized(deviceStats) {
                deviceStats.toMap()
            }

            return StatsSummary(
                totalExploits = totalExploits,
                successfulExploits = successfulExploits,
                failedExploits = failedExploits,
                successRate = successRate,
                totalDevices = totalDevices,
                uniqueDevices = uniqueDevices,
                averageExecutionTime = averageExecutionTime,
                mostCommonExploit = mostCommonExploit,
                mostCommonCVE = mostCommonCVE,
                securityLevelDistribution = securityLevels,
                recentOperations = recentOperations,
                deviceStats = deviceStatsCopy
            )
        }
    }

    /**
     * Obtener estadísticas de un dispositivo específico
     */
    fun getDeviceStats(deviceAddress: String): DeviceStatistics? {
        return synchronized(deviceStats) {
            deviceStats[deviceAddress]
        }
    }

    /**
     * Obtener historial de operaciones
     */
    fun getOperationHistory(limit: Int = 50): List<OperationRecord> {
        return synchronized(operationHistory) {
            operationHistory.takeLast(limit)
        }
    }

    /**
     * Obtener estadísticas de un tipo de exploit específico
     */
    fun getExploitStats(exploitType: String): Map<String, Any> {
        val allStats = getStatsSummary()

        val exploitOperations = allStats.recentOperations.filter {
            it.exploitType == exploitType
        }

        return mapOf(
            "total" to exploitOperations.size,
            "success" to exploitOperations.count { it.success },
            "failure" to exploitOperations.count { !it.success },
            "successRate" to if (exploitOperations.isNotEmpty()) {
                (exploitOperations.count { it.success }.toDouble() / exploitOperations.size) * 100
            } else 0.0,
            "averageDuration" to if (exploitOperations.isNotEmpty()) {
                exploitOperations.map { it.durationMs }.average()
            } else 0.0,
            "mostCommonCVE" to (exploitOperations.flatMap { it.cveList }.groupBy { it }.maxByOrNull { it.value.size }?.key ?: "None"),
            "securityLevelDistribution" to exploitOperations.groupBy { it.securityLevel }.mapValues { it.value.size }
        )
    }

    /**
     * Guardar estadísticas a archivo en memoria interna
     */
    fun saveStatsToFile(context: Context) {
        try {
            // Use internal storage: /data/data/com.bluesnafer_pro/files/stats/
            val statsDir = File(context.filesDir, "stats")
            statsDir.mkdirs()
            
            val statsFile = File(statsDir, STATS_FILE)
            
            val statsData = mapOf(
                "globalStats" to globalStats,
                "operationHistory" to operationHistory,
                "deviceStats" to deviceStats,
                "exportedAt" to LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
            )
            
            // Guardar como JSON (simplificado)
            val jsonContent = """
                {
                    "globalStats": ${globalStats.toJson()},
                    "operationHistory": ${operationHistory.toJson()},
                    "deviceStats": ${deviceStats.toJson()},
                    "exportedAt": "${LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)}"
                }
            """.trimIndent()
            
            statsFile.writeText(jsonContent)
            BluesnaferLogger.d(TAG, "Estadísticas guardadas en ${statsFile.absolutePath}")
        } catch (e: Exception) {
            BluesnaferLogger.e(TAG, "Error guardando estadísticas: ${e.message}")
        }
    }

    fun loadStatsFromFile(context: Context): Boolean {
        try {
            val statsDir = File(context.filesDir, "stats")
            val statsFile = File(statsDir, STATS_FILE)

            if (statsFile.exists()) {
                val content = statsFile.readText()

                if (content.isNotBlank()) {
                    BluesnaferLogger.d(TAG, "Stats loaded from ${statsFile.absolutePath}")
                    return true
                }
            }
            return false
        } catch (e: Exception) {
            BluesnaferLogger.e(TAG, "Error cargando estadísticas: ${e.message}")
            return false
        }
    }

    private fun Any?.toJson(): String {
        return when (this) {
            null -> "null"
            is Map<*, *> -> "{" + entries.joinToString(",") { "\"${it.key}\":${it.value?.toJson() ?: "null"}" } + "}"
            is List<*> -> "[" + map { it?.toJson() ?: "null" }.joinToString(",") + "]"
            is String -> "\"$this\""
            is Number -> toString()
            is Boolean -> toString()
            else -> "\"$this\""
        }
    }
}
