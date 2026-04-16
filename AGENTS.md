# BlueSnafer Pro - Documentación para Agentes IA

## Resumen del Proyecto

**BlueSnafer Pro** es una aplicación Flutter/Android para auditoría de seguridad Bluetooth. El objetivo principal es detectar vulnerabilidades en dispositivos Bluetooth cercanos y extraer datos de dispositivos objetivo mediante técnicas de explotación.

**Objetivo Final**: Extraer fotos y demás datos de los dispositivos objetivo mediante un modo automático que ejecuta ataques en secuencia optimizada.

---

## Estructura del Proyecto

```
bluesnafer_pro/
├── lib/
│   ├── main.dart                    # Punto de entrada
│   ├── app.dart                     # Configuración de la app
│   ├── unified_attack_screen.dart   # PANTALLA PRINCIPAL (3670 líneas)
│   │
│   ├── screens/                     # Pantallas de la aplicación
│   │   ├── welcome_screen.dart
│   │   ├── permission_screen.dart
│   │   ├── device_connection_screen.dart
│   │   ├── bluetooth_scanner_screen.dart
│   │   ├── real_exploit_screen.dart
│   │   ├── complete_automated_analysis_screen.dart
│   │   └── ... (otras pantallas)
│   │
│   ├── services/                    # Servicios principales
│   │   ├── real_exploit_service.dart       # Ejecución de exploits reales
│   │   ├── integrated_ai_service.dart       # IA con modelos TFLite
│   │   ├── attack_suggestion_engine.dart    # Motor de sugerencias
│   │   ├── bluetooth_scanner_service.dart   # Escaneo Bluetooth
│   │   ├── permission_handler_service.dart  # Manejo de permisos
│   │   └── tflite_real_service.dart        # Servicio TFLite
│   │
│   ├── models/                      # Modelos de datos
│   │   ├── tflite_models.dart
│   │   └── dynamic_vulnerability_database.dart
│   │
│   ├── ai/                          # Módulos de IA
│   │   ├── adaptive_payload_engine.dart
│   │   ├── smart_recommendation_system.dart
│   │   ├── success_optimizer.dart
│   │   └── ml_vulnerability_predictor.dart
│   │
│   ├── exploits/                    # Gestor de exploits
│   │   ├── exploit_manager.dart
│   │   └── advanced_combination_system.dart
│   │
│   ├── attacks/                     # Implementaciones de ataques
│   │   ├── protocol_downgrade.dart
│   │   └── timing_attack.dart
│   │
│   ├── bluetooth/                   # Utilidades Bluetooth
│   │   ├── bluetooth_file_manager.dart
│   │   └── bluetooth_code_injector.dart
│   │
│   ├── advanced_systems/            # Sistemas avanzados
│   │   ├── intelligent_exfiltration.dart
│   │   ├── enhanced_ml_engine.dart
│   │   ├── zero_day_exploiter.dart
│   │   ├── persistence_engine.dart
│   │   └── multi_vector_attack.dart
│   │
│   ├── reconnaissance/              # Motor de reconocimiento
│   │   └── deep_reconnaissance_engine.dart
│   │
│   ├── evasion/                     # Motor de evasión
│   │   └── advanced_evasion_engine.dart
│   │
│   ├── security/                   # Módulos de seguridad
│   │   ├── file_encryption.dart
│   │   └── auto_destruct.dart
│   │
│   ├── utils/                      # Utilidades
│   │   ├── device_utils.dart       # Utilidades de dispositivo
│   │   ├── advanced_logger.dart
│   │   ├── advanced_error_handler.dart
│   │   ├── dynamic_configuration.dart
│   │   ├── smart_cache.dart
│   │   └── export_manager.dart
│   │
│   ├── widgets/                    # Widgets reutilizables
│   │   ├── smart_suggestion_panel.dart
│   │   ├── attack_combination_executor.dart
│   │   ├── command_search_bar.dart
│   │   └── command_category_panel.dart
│   │
│   └── providers/                  # Proveedores de estado
│       └── bluetooth_provider.dart
│
├── android/                        # Código nativo Android (Kotlin)
│   └── app/src/main/kotlin/...
│
├── assets/                         # Recursos
│   └── models/                     # Modelos TFLite
│
├── pubspec.yaml                    # Dependencias Flutter
├── MEJORAS_MODO_AUTOMATICO.md      # Documentación de mejoras
└── AGENTS.md                       # Este archivo
```

---

## Pantalla Principal: unified_attack_screen.dart

Esta es la pantalla principal que contiene todo el modo automático. Tiene **3670 líneas** de código.

### Métodos Clave del Modo Automático

| Método | Línea | Descripción |
|--------|-------|-------------|
| `_startUnattendedMode()` | ~1110 | Inicia el modo automático mejorado |
| `_unattendedOBEXExtract()` | ~1603 | Extrae archivos via OBEX FTP |
| `_unattendedPBAPExtract()` | ~1746 | Extrae contactos via PBAP |
| `_executeWithRetry()` | ~789 | Ejecuta con backoff exponencial |
| `_analyzeExtractedPatterns()` | ~429 | Analiza patrones en datos |
| `_extractAppData()` | ~517 | Extrae datos de apps Android |
| `_extractNetworkInfo()` | ~556 | Extrae información de red |
| `_installPersistenceMechanism()` | ~618 | Instala persistencia/backdoor |
| `_predictVulnerabilities()` | ~661 | Predice vulnerabilidades con IA |
| `_executeStealthMode()` | ~695 | Modo sigiloso |
| `_generateAutomatedReport()` | ~726 | Genera reporte automático |
| `_showAutomatedReport()` | ~961 | Muestra reporte en UI |
| `_getOptimizedAttackSequence()` | ~385 | Estrategias por tipo de dispositivo |

### Variables de Estado del Modo Automático

```dart
// Configuración global
bool _enableParallelExecution = true;    // Ejecución paralela
bool _enableAdaptiveIntelligence = true;   // IA adaptativa
bool _enablePatternAnalysis = true;        // Análisis de patrones
bool _enableNetworkAnalysis = true;        // Análisis de red
bool _enablePersistence = false;           // Persistencia/backdoors
bool _stealthMode = false;                 // Modo sigiloso

// Variables de tracking
bool _isUnattendedRunning = false;
Map<String, double> _attackProbabilities = {};
List<Map<String, dynamic>> _installedBackdoors = [];
Map<String, dynamic> _networkAnalysis = {};
Map<String, dynamic> _automatedReport = {};
```

---

## Fases del Modo Automático

### FASE 0: Predicción con IA (NUEVO)
- Analiza vulnerabilidades del dispositivo
- Calcula probabilidad de éxito
- Genera recomendaciones priorizadas

### FASE 1: Reconocimiento
- SDP Discovery Protocol
- OBEX FTP Extraction (archivos, fotos)

### FASE 2: Extracción de Datos
- PBAP (contactos + llamadas)
- Datos de apps Android (NUEVO)
- AT Injection
- OPP File Push

### FASE 3: Ataques BLE
- BTLEJack: scan, sniff, hijack, mitm

### FASE 4: Inyección
- HID Scripts: notepad, wifi, terminal
- HID Inject

### FASE 5: Ataques Avanzados
- Mirror Profile
- BlueBorne
- Full Vulnerability Scan
- BT Spoofing
- Download File

### FASE 6: Auth Bypass
- Quick Connect Race
- MAC Spoof Trust
- OBEX Trust Abuse

### FASE 7: DoS (Opcional)
- GATT Flood
- L2CAP Flood
- MTU Crash

### POST-PROCESAMIENTO (NUEVO)
- Análisis de patrones en datos extraídos
- Extracción de información de red
- Instalación de persistencia/backdoors

### REPORTE FINAL
- Estadísticas completas
- Análisis de patrones
- Recomendaciones

---

## Estrategias por Tipo de Dispositivo

El sistema detecta el tipo de dispositivo y aplica una estrategia optimizada:

| Tipo | Secuencia de Ataques |
|------|---------------------|
| `smartphone` | SDP → PBAP → AT → Mirror → OBEX |
| `iot` | SDP → OBEX → BTLEJack → DoS |
| `laptop` | SDP → OBEX → AT → Spoofing → Scan |
| `car` | SDP → BTLEJack → DoS → Scan |
| `smart lock` | SDP → DoS → BTLEJack |
| `wearable` | SDP → PBAP → OBEX |

---

## UI de Configuración

El modo automático incluye un **PopupMenuButton** en el AppBar con las siguientes opciones:

- ✅ Ejecución paralela (toggle)
- ✅ IA adaptativa (toggle)
- ✅ Análisis de patrones (toggle)
- ✅ Análisis de red (toggle)
- 🎭 Modo sigiloso (toggle)
- 🕵️ Persistencia (toggle)
- 📊 Ver reporte (acción)

---

## Servicios de Explotación

### RealExploitService
Conecta con código nativo Kotlin vía MethodChannel. Métodos clave:
- `executeAttack()` - Ejecuta cualquier ataque
- `scanOBEXServices()` - Escanea servicios OBEX
- `pbapExtract()` - Extrae contactos/llamadas
- `downloadFile()` - Descarga archivos
- `executeDoS()` - Ataques de denegación
- `sdpDiscover()` - Service Discovery
- `injectHIDScript()` - Inyección HID
- `bypassQuickConnect()` - Bypass auth
- `oppPush()` - Envío de archivos

### IntegratedAIService
Utiliza modelos TFLite para:
- Predicción de bypass PIN
- Predicción de éxito de ataques
- Clasificación de dispositivos
- Detección de contramedidas
- Generación de exploits

---

## Errores y Correcciones Aplicadas

### 1. Tipo de retorno incorrecto
```dart
// ANTES (error)
List<String> _generateAttackRecommendations() async { ... }

// CORREGIDO
List<String> _generateAttackRecommendations() { ... }
```

### 2. Mayúsculas/minúsculas en deviceType
```dart
// ANTES (error)
final deviceType = device_utils.detectDeviceType(device);

// CORREGIDO
final deviceType = device_utils.detectDeviceType(device).toLowerCase();
```

### 3. Claves del mapa de estrategias
```dart
// ANTES (error)
final strategies = { 'Smartphone': [...], 'IoT Device': [...] };

// CORREGIDO
final strategies = { 'smartphone': [...], 'iot': [...] };
```

---

## Cómo Ejecutar Pruebas

### Compilar APK
```bash
cd bluesnafer_pro
flutter build apk --debug
```

### Análisis estático
```bash
flutter analyze lib/unified_attack_screen.dart
```

### Verificar sintaxis
```bash
dart analyze lib/unified_attack_screen.dart
```

---

## Notas Importantes para Agentes

1. **Sin código simulado**: El proyecto NO contiene código simulado. Todas las operaciones delegan a canales nativos Kotlin o modelos TFLite reales.

2. **Modo automático configurable**: Cada característica puede habilitarse/deshabilitarse desde la UI.

3. **Persistencia deshabilitada por defecto**: Por seguridad, `_enablePersistence` está en `false`.

4. **Stealth mode**: Incrementa los delays entre ataques (5s vs 3s) para reducir detección.

5. **Backoff exponencial**: Los reintentos usan fórmula: `delay = baseDelay * 2^attempt`

6. **Análisis de patrones**: Extrae emails de trabajo, redes sociales, credenciales potenciales de los datos recopilados.

---

## Dependencias Principales (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  permission_handler: ^11.0.0
  shared_preferences: ^2.2.0
  tflite_flutter: ^0.10.0
  flutter_blue_plus: ^1.32.0
  # ... otras dependencias
```

---

## Fecha de Actualización

Abril 2026 - Implementación completa de mejoras del modo automático.

Versión: BlueSnafer Pro 1.0+
