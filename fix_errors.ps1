# Script para corregir errores de compilación en el proyecto BlueSnafer

Write-Host "Corrigiendo errores de compilación..."

# 1. Copiar el archivo de clases faltantes al directorio correcto
Copy-Item -Path "fix_errors.kt" -Destination "android\app\src\main\kotlin\com\bluesnafer_pro\"

# 2. Corregir errores en GattConnectionManager.kt
$content = Get-Content "android\app\src\main\kotlin\com\bluesnafer_pro\GattConnectionManager.kt" -Raw
$content = $content -replace "withTimeout(timeoutMs, block)", "kotlinx.coroutines.withTimeout(timeoutMs, block)"
$content = $content -replace "TimeoutCancellationException", "kotlinx.coroutines.TimeoutCancellationException"
$content | Set-Content "android\app\src\main\kotlin\com\bluesnafer_pro\GattConnectionManager.kt"

# 3. Corregir errores en StatsManager.kt
$content = Get-Content "android\app\src\main\kotlin\com\bluesnafer_pro\StatsManager.kt" -Raw
$content = $content -replace "val totalExploits = globalStats\[""totalExploits""\] as Int", "val totalExploits = (globalStats[""totalExploits""] as? Int) ?: 0"
$content = $content -replace "val successfulExploits = globalStats\[""successfulExploits""\] as Int", "val successfulExploits = (globalStats[""successfulExploits""] as? Int) ?: 0"
$content = $content -replace "val failedExploits = globalStats\[""failedExploits""\] as Int", "val failedExploits = (globalStats[""failedExploits""] as? Int) ?: 0"
$content = $content -replace "val totalDevices = globalStats\[""totalDevices""\] as Int", "val totalDevices = (globalStats[""totalDevices""] as? Int) ?: 0"
$content = $content -replace "val executionTimes = globalStats\[""executionTimes""\] as List<Long>", "val executionTimes = (globalStats[""executionTimes""] as? List<Long>) ?: emptyList()"
$content = $content -replace "val exploitTypes = globalStats\[""exploitTypes""\] as Map<String, Int>", "val exploitTypes = (globalStats[""exploitTypes""] as? Map<String, Int>) ?: emptyMap()"
$content = $content -replace "val cveDetection = globalStats\[""cveDetection""\] as Map<String, Int>", "val cveDetection = (globalStats[""cveDetection""] as? Map<String, Int>) ?: emptyMap()"
$content = $content -replace "val securityLevels = globalStats\[""securityLevels""\] as Map<String, Int>", "val securityLevels = (globalStats[""securityLevels""] as? Map<String, Int>) ?: emptyMap()"
$content | Set-Content "android\app\src\main\kotlin\com\bluesnafer_pro\StatsManager.kt"

# 4. Corregir errores en ExploitIntegration.kt
$content = Get-Content "android\app\src\main\kotlin\com\bluesnafer_pro\ExploitIntegration.kt" -Raw
$content = $content -replace "appContext \?\: context", "appContext \?\: throw Exception(\"Context not available\")"
$content | Set-Content "android\app\src\main\kotlin\com\bluesnafer_pro\ExploitIntegration.kt"

Write-Host "Correcciones aplicadas. Intente compilar nuevamente."
