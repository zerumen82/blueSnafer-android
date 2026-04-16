#!/bin/bash

# Script para corregir errores de compilación en el proyecto BlueSnafer

echo "Corrigiendo errores de compilación..."

# 1. Copiar el archivo de clases faltantes al directorio correcto
cp fix_errors.kt android/app/src/main/kotlin/com/bluesnafer_pro/

# 2. Corregir errores en GattConnectionManager.kt
sed -i 's/withTimeout(timeoutMs, block)/kotlinx.coroutines.withTimeout(timeoutMs, block)/g' android/app/src/main/kotlin/com/bluesnafer_pro/GattConnectionManager.kt
sed -i 's/TimeoutCancellationException/kotlinx.coroutines.TimeoutCancellationException/g' android/app/src/main/kotlin/com/bluesnafer_pro/GattConnectionManager.kt

# 3. Corregir errores en StatsManager.kt
sed -i 's/val totalExploits = globalStats\["totalExploits"\] as Int/val totalExploits = (globalStats["totalExploits"] as? Int) ?: 0/g' android/app/src/main/kotlin/com/bluesnafer_pro/StatsManager.kt
sed -i 's/val successfulExploits = globalStats\["successfulExploits"\] as Int/val successfulExploits = (globalStats["successfulExploits"] as? Int) ?: 0/g' android/app/src/main/kotlin/com/bluesnafer_pro/StatsManager.kt
sed -i 's/val failedExploits = globalStats\["failedExploits"\] as Int/val failedExploits = (globalStats["failedExploits"] as? Int) ?: 0/g' android/app/src/main/kotlin/com/bluesnafer_pro/StatsManager.kt
sed -i 's/val totalDevices = globalStats\["totalDevices"\] as Int/val totalDevices = (globalStats["totalDevices"] as? Int) ?: 0/g' android/app/src/main/kotlin/com/bluesnafer_pro/StatsManager.kt
sed -i 's/val executionTimes = globalStats\["executionTimes"\] as List<Long>/val executionTimes = (globalStats["executionTimes"] as? List<Long>) ?: emptyList()/g' android/app/src/main/kotlin/com/bluesnafer_pro/StatsManager.kt
sed -i 's/val exploitTypes = globalStats\["exploitTypes"\] as Map<String, Int>/val exploitTypes = (globalStats["exploitTypes"] as? Map<String, Int>) ?: emptyMap()/g' android/app/src/main/kotlin/com/bluesnafer_pro/StatsManager.kt
sed -i 's/val cveDetection = globalStats\["cveDetection"\] as Map<String, Int>/val cveDetection = (globalStats["cveDetection"] as? Map<String, Int>) ?: emptyMap()/g' android/app/src/main/kotlin/com/bluesnafer_pro/StatsManager.kt
sed -i 's/val securityLevels = globalStats\["securityLevels"\] as Map<String, Int>/val securityLevels = (globalStats["securityLevels"] as? Map<String, Int>) ?: emptyMap()/g' android/app/src/main/kotlin/com/bluesnafer_pro/StatsManager.kt

# 4. Corregir errores en ExploitIntegration.kt
sed -i 's/appContext ?: context/appContext ?: throw Exception("Context not available")/g' android/app/src/main/kotlin/com/bluesnafer_pro/ExploitIntegration.kt

echo "Correcciones aplicadas. Intente compilar nuevamente."
