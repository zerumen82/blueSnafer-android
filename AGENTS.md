# BlueSnafer Pro - Documentación para Agentes IA

## Estado del Proyecto (2026-08-20)

### Resumen
**BlueSnafer Pro** es una aplicación Flutter/Android para auditoría de seguridad Bluetooth. El objetivo principal es detectar vulnerabilidades en dispositivos Bluetooth cercanos y extraer datos de dispositivos objetivo mediante técnicas de explotación.

**Objetivo Final**: Extraer fotos y demás datos de los dispositivos objetivo mediante un modo automático que ejecuta ataques en secuencia optimizada.

### Estado General
- **Sin stubs**: No existe `// TODO`, `// FIXME`, `// STUB`, `UnimplementedError`, ni código simulado/fake/mock en el árbol de código actual.
- **Sin código simulado**: Todas las operaciones delegan a canales nativos Kotlin reales (RFCOMM, OBEX, PBAP, MAP, GATT, root vía `su -c hcitool`).
- **Compilación**: No hay errores de compilación activos en Dart ni Kotlin. El archivo histórico `Stubs.kt` (que causaba errores de `Redeclaration` y `Unresolved reference 'createMockGatt'`) fue eliminado del proyecto.
- **Modo automático**: Completamente implementado (fases -1 a 99), con ejecución paralela/adaptativa, post-procesamiento y reporte.
- **UI**: 2 tabs funcionales (RADAR + DATOS). Sin botones de ataque manual. Todo se ejecuta vía modo automático.

---

## Estructura del Proyecto

```
bluesnafer_pro/
├── lib/
│   ├── main.dart                    # Punto de entrada (78 líneas)
│   ├── app.dart                     # Configuración de la app
│   ├── unified_attack_screen.dart   # PANTALLA PRINCIPAL (5621 líneas) — TODO el modo automático
│   │
│   ├── services/                    # Servicios principales
│   │   ├── real_exploit_service.dart       # Ejecución de exploits reales (MethodChannel bridge)
│   │   ├── heuristic_analysis_service.dart # Motor heurístico (reemplaza TFLite)
│   │   ├── attack_suggestion_engine.dart    # Motor de sugerencias
│   │   ├── bluetooth_scanner_service.dart   # Escaneo Bluetooth
│   │   ├── permission_handler_service.dart  # Manejo de permisos
│   │   └── real_notification_service.dart  # Notificaciones vía canal nativo real
│   │
│   ├── models/                      # Modelos de datos
│   │   └── dynamic_vulnerability_database.dart
│   │
│   ├── exploits/                    # Gestor de exploits
│   │   ├── exploit_manager.dart
│   │   ├── advanced_combination_system.dart
│   │   └── adaptive_payload_engine.dart
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
│   │   ├── strategy_engine.dart
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
│   │   ├── device_utils.dart
│   │   ├── advanced_logger.dart
│   │   ├── advanced_error_handler.dart
│   │   ├── dynamic_configuration.dart
│   │   ├── smart_cache.dart
│   │   ├── export_manager.dart
│   │   ├── smart_recommendation_system.dart
│   │   └── success_optimizer.dart
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
│   └── app/src/main/kotlin/com/bluesnafer_pro/...
│       ├── MainActivity.kt              # Canales + EventChannels
│       ├── ExploitIntegration.kt        # Canal 'exploit_integration'
│       ├── BluetoothMethodHandler.kt    # Canal 'com.bluesnafer_pro/bluetooth'
│       ├── NotificationBridge.kt        # Canal 'com.bluesnafer_pro/notifications'
│       ├── LogForwarder.kt              # Reenvío de logs a EventChannels
│       ├── RealFileExfiltrationClient.kt # OBEX FTP extraction
│       ├── RealATInjection.kt           # AT command injection
│       ├── SapExtractor.kt              # SIM Access Profile extraction
│       ├── GATTImageReader.kt           # GATT image scanning
│       ├── OPPServerMode.kt             # OPP server mode
│       ├── OPPClient.kt                 # OPP client
│       ├── MAPExtractor.kt              # MAP profile extraction
│       ├── MediaStoreHijack.kt          # MediaStore batch extraction
│       ├── MissingClasses.kt            # (vacío — sin stubs)
│       ├── AuthenticationBypasser.kt
│       ├── A2DPSinkRecorder.kt
│       ├── RootExploitExecutor.kt
│       ├── RootUtils.kt
│       ├── OBEXVulnerabilityAnalyzer.kt
│       ├── ModernBleExploits.kt           # BLUR, SweynTooth, BLERP, ShareMe, Quick Share
│       ├── BleFixedChannelsExploit.kt
│       ├── BtlateralMovement.kt
│       └── ...
│
├── pubspec.yaml                    # Dependencias Flutter
├── MEJORAS_MODO_AUTOMATICO.md      # Documentación de mejoras
└── AGENTS.md                       # Este archivo
```

---

## Pantalla Principal: unified_attack_screen.dart

**5621 líneas**. Contiene toda la UI y el modo automático.

### Estructura UI

**2 tabs (Bottom TabBar):**
| Tab | Índice | Contenido |
|-----|--------|-----------|
| **RADAR** | 0 | Lista de dispositivos + consola colapsable (`_consoleExpanded`). Botón MODO AUTOMÁTICO en HUD. |
| **DATOS** | 1 | Secciones colapsables (ExpansionTile) que muestran SOLO resultados recolectados. Sin botones de ataque manual. |

### Componentes UI Clave
- `_buildTargetHud()`: HUD con dispositivo seleccionado, fabricante, MAC, guía rápida y botón de modo automático (verde INICIAR / rojo DETENER). Deshabilitado sin objetivo.
- `_buildHomeTab()`: Tab RADAR con lista de dispositivos, botón escanear, consola colapsable.
- `_buildAiTab()`: Tab DATOS con secciones colapsables para SDP, PBAP, identidad, galería, extracción moderna, transferencia, dashboard, vulnerability assessment.
- `_buildCollapsibleSection()`: Widget genérico para ExpansionTile con título, icono y contenido.
- `_buildAutoRunCard()` / `_buildAutoRunAction()`: Tarjetas informativas que indican qué se ejecuta automáticamente.
- `_buildGalleryPanel()`: Panel de thumbnails para fotos extraídas.
- `_extractPhotos()`: Card `📸 EXTRAER FOTOS` en sección GALERÍA DEL OBJETIVO.
- `_navigateToSuggestion()`: Navega al tab DATOS (índice 1).
- AppBar PopupMenuButton: Opciones de configuración del modo automático.

### Variables de Estado del Modo Automático

```dart
// Configuración global
bool _enableParallelExecution = true;      // Ejecución paralela
bool _enableAdaptiveIntelligence = true;   // Análisis heurístico adaptativo
bool _enablePatternAnalysis = true;        // Análisis de patrones
bool _enableNetworkAnalysis = true;        // Análisis de red
bool _enablePersistence = false;           // Persistencia/backdoors (deshabilitado por defecto)
bool _stealthMode = false;                 // Modo sigiloso

// Variables de tracking
bool _isUnattendedRunning = false;
Map<String, double> _attackProbabilities = {};
List<Map<String, dynamic>> _installedBackdoors = [];
Map<String, dynamic> _networkAnalysis = {};
Map<String, dynamic> _automatedReport = {};
Map<String, dynamic> _extractedImages = {};
```

---

## Modo Automático: Fases y Estado

### Flujo General
`_startUnattendedMode()` (línea ~2551) inicia el flujo:
1. Root status check
2. Log de configuración activa
3. Loop por cada dispositivo objetivo
4. Ejecución de fases -1 a 8
5. Post-procesamiento (network, patterns, persistence, stealth)
6. Generación de reporte
7. Reset de `_isUnattendedRunning` al finalizar (tanto éxito como cancelación)

### Fases Implementadas

| Fase | Descripción | Ejecución | Estado |
|------|-------------|-----------|--------|
| **-1** | Proactive reconnaissance (SDP) | — | ✅ Implementado |
| **0** | Heuristic analysis (adaptive intelligence) | — | ✅ Implementado |
| **0.5** | Unified advanced system | — | ✅ Implementado |
| **1** | SDP discover + enumerate | Paralelo (max 2) | ✅ Implementado |
| **2** | Data extraction: OBEX, PBAP, AT identity, SAP, galería, MediaStore Enhanced, GATT image, OPP server, MAP | Paralelo (max 2) | ✅ Implementado |
| **3** | BLE exploits: BTLEJack, BLUR, SweynTooth, BLERP, BlueBorne, pairing, GATT, L2CAP, A2DP, HFP + ShareMe credential extraction + Quick Share discovery | Paralelo (max 2) | ✅ Implementado |
| **4** | Injection: AT, HID, RFCOMM | Secuencial | ✅ Implementado |
| **5** | Auth bypass: SMP, Quick Connect, MAC spoof, OBEX trust, PIN brute, FastPair | Paralelo (max 2) | ✅ Implementado |
| **6** | Advanced: Mirror, Spoofing, Ghost Relay, Lateral Scan | Paralelo (max 2) | ✅ Implementado |
| **8** | Deep analysis: full_scan, heartbleed, app_data, network, wifi | Secuencial | ✅ Implementado |
| **8** | DoS: GATT flood, L2CAP flood | Opcional | ✅ Implementado |
| **99** | OPP push fallback | Final | ✅ Implementado |

### Secuencia Adaptativa por Tipo de Dispositivo

`_getAdaptiveAttackSequence(deviceType)` genera la secuencia optimizada según el tipo:
- **smartphone**: Énfasis en extracción de datos (OBEX, PBAP, AT, imágenes)
- **iot**: Énfasis en GATT, BLE exploits, firmware
- **car**: Énfasis en HFP, A2DP, GATT
- **audio**: Énfasis en A2DP, HFP, OPP
- **unknown**: Secuencia genérica completa

### Ejecución de Ataques

`_attack()` (línea ~3000):
- Timeout configurable por tipo de ataque (`_attackConfigs`)
- Retry con backoff exponencial: `delay = baseDelay * 2^attempt`
- Pre-check de root cuando es necesario
- Colección de resultados
- Cancelación respeta `_isUnattendedRunning`

`_executeParallelAttacks()` (línea ~504):
- Agrupa ataques por fase
- Ejecuta batches de hasta 2 ataques en paralelo
- Respeta `_enableParallelExecution`

### Extracción de Imágenes (4 alternativas)

Todas integradas en FASE 2 del modo automático y en la pestaña DATOS:

| Alternativa | Canal Kotlin | Método | Descripción |
|-------------|--------------|--------|-------------|
| **OBEX FTP** | `extract_images` | `RealFileExfiltrationClient.extractImages()` | Walk recursivo DCIM/Pictures/WhatsApp/Telegram, máx. 30 imágenes / 3 niveles |
| **MediaStore Enhanced** | `mediastore_enhanced` | `MediaStoreHijack.extractAllImages()` | content:// URIs, batch sin OBEX |
| **GATT Image Read** | `gatt_image_read` | `GATTImageReader` | Escanea characteristics para magic bytes de imagen |
| **OPP Server Mode** | `opp_server_mode` | `OPPServerMode` | Espera push del target |
| **MAP Image Extract** | `map_image_extract` | `MAPExtractor.extractImageAttachments()` | Adjuntos WhatsApp/Telegram vía MAP |

---

## Análisis de UI y Modo Automático

### UI: Estado Completo
- **2 tabs funcionales**: RADAR (escaneo + consola) y DATOS (resultados)
- **Sin botones de ataque manual**: Toda la acción se delega al modo automático
- **PopupMenuButton en AppBar**: 8 opciones (6 toggles + 2 acciones)
- **HUD inteligente**: Muestra contexto del dispositivo seleccionado y estado del modo automático
- **Consola colapsable**: Logs en tiempo real con colores, exportar y limpiar
- **Tarjetas informativas**: `_buildAutoRunCard`/`_buildAutoRunAction` indican qué se ejecuta automáticamente

### Modo Automático: Estado Completo
- ✅ Inicio/parada funcional
- ✅ Secuencia adaptativa por tipo de dispositivo
- ✅ Ejecución paralela (max 2 ataques concurrentes)
- ✅ Backoff exponencial en reintentos
- ✅ Timeouts configurables por tipo de ataque
- ✅ Post-procesamiento: análisis de patrones, red, persistencia, stealth
- ✅ Reporte final completo
- ✅ Cancelación respeta flag `_isUnattendedRunning`
- ✅ Reset de flag al finalizar (tanto éxito como error)

### Bugs Corregidos (históricos)
1. `_generateAttackRecommendations()` era async pero debía ser sync
2. `deviceType` sin `.toLowerCase()` causaba mismatch de claves
3. Claves del mapa de estrategias usaban mayúsculas ('Smartphone' vs 'smartphone')
4. `_attack()` loop requería `_isUnattendedRunning` impidiendo ataques manuales
5. `_startUnattendedMode` no reseteaba `_isUnattendedRunning` al completar
6. `_attackConfigs` sin entradas para `at_extract_identity`, `sap_extract`, `extract_images`
7. 4 alternativas modernas de extracción de imágenes añadidas
8. Kotlin compilation fixes para `GATTImageReader.kt` y `OPPServerMode.kt`

---

## Stubs y Código Falso: Informe

### Resultado: NINGUNO ENCONTRADO

| Categoría | Cantidad | Detalle |
|-----------|----------|---------|
| `// TODO` | 0 | No hay marcadores TODO en el código |
| `// FIXME` | 0 | No hay marcadores FIXME |
| `// STUB` | 0 | No hay marcadores STUB |
| `UnimplementedError` | 0 | No hay excepciones de tipo unimplemented |
| `notImplemented()` | 0 en Dart | Los `notImplemented()` encontrados son exclusivamente en Kotlin como fallbacks de `MethodChannel.Result` (no stubs) |
| `fake`/`mock`/`simulated`/`dummy`/`placeholder` | 0 | No hay patrones de código simulado |
| Archivo `Stubs.kt` | No existe | Fue eliminado del árbol de código |

### Nota sobre `notImplemented()` en Kotlin
Los handlers de `MethodChannel.Result` en `BluetoothChannelBridge.kt` y `ExploitIntegration.kt` usan `notImplemented()` como fallback para métodos no reconocidos. Esto es comportamiento estándar de canales nativos, no stubs. Cada método documentado en este AGENTS.md tiene una implementación real en Kotlin.

---

## Errores de Compilación

### Estado Actual: SIN ERRORES

| Tipo | Estado | Detalle |
|------|--------|---------|
| Dart compilation | ✅ Sin errores | `unified_attack_screen.dart` compila correctamente |
| Kotlin compilation | ✅ Sin errores | Todos los archivos Kotlin compilan. `Stubs.kt` eliminado. |
| Deprecation warnings | ⚠️ Existen | Warnings de deprecación de `BluetoothAdapter.getDefaultAdapter()` en archivos legacy — no bloquean compilación |

### Errores Históricos Corregidos
- `GATTImageReader.kt:57`: `valueSize` Int → `.toString()`
- `OPPServerMode.kt:21`: `device.listenUsingInsecureRfcommWithServiceRecord` → `BluetoothAdapter.getDefaultAdapter()?.listenUsingInsecureRfcommWithServiceRecord`
- `OPPServerMode.kt:33`: `await(timeoutSec + 5, ...)` → `await((timeoutSec + 5).toLong(), ...)`
- `OPPServerMode.kt:98-99`: `clientSocket.close()` / `serverSocket.close()` → nullable safe calls
- `unified_attack_screen.dart:3440,3450,3453,3457`: Missing semicolons añadidos

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

### Verificación de build
- `flutter build apk --debug` debe completar sin errores (solo warnings de deprecación).
- No hay errores de compilación Dart ni Kotlin conocidos en este momento.

---

## Notas Importantes para Agentes

1. **Sin código simulado**: El proyecto NO contiene código simulado. Las operaciones delegan a canales nativos Kotlin reales (RFCOMM, OBEX, PBAP, MAP, GATT, root vía `su -c hcitool`). La antigua capa de "IA" (modelos TFLite entrenados con ruido aleatorio) fue eliminada y reemplazada por un motor heurístico honesto basado en hechos reales del dispositivo (`heuristic_analysis_service.dart`).

2. **Modo automático configurable**: Cada característica puede habilitarse/deshabilitarse desde la UI (PopupMenuButton).

3. **Persistencia deshabilitada por defecto**: Por seguridad, `_enablePersistence` está en `false`.

4. **Stealth mode**: Incrementa los delays entre ataques (5s vs 3s) para reducir detección.

5. **Backoff exponencial**: Los reintentos usan fórmula: `delay = baseDelay * 2^attempt`

6. **Análisis de patrones**: Extrae emails de trabajo, redes sociales, credenciales potenciales de los datos recopilados.

7. **Canales activos Kotlin**:
   - `com.bluesnafer_pro/bluetooth` (métodos)
   - `exploit_integration` (métodos, incluye `at_extract_identity`, `sap_extract`, `extract_images`, `mediastore_enhanced`, `gatt_image_read`, `opp_server_mode`, `map_image_extract`)
   - `com.bluesnafer_pro/notifications` (notificaciones reales)
   - EventChannels: `bluetooth_logs` (String) y `exploit_events` (mapas) reenviados por `LogForwarder`
   - No usar canales no listados aquí.

8. **Sin pantallas separadas**: `PermissionScreen`, `WelcomeScreen`, etc. están embebidas dentro de `unified_attack_screen.dart` (líneas 25-230). No hay archivos `welcome_screen.dart`, `permission_screen.dart`, etc. como archivos independientes.

9. **Motor heurístico honesto**: `HeuristicAnalysisService` reemplazó la capa TFLite fabricada. Deriva scores exclusivamente de hechos reales del dispositivo (SDP services, bonding state, Bluetooth version, RSSI) y los reporta como heurísticas, no como salidas de modelo.

10. **Extracción de imágenes — límites reales**:
    - OBEX FTP solo funciona en dispositivos legacy/feature phones con OBEX abierto o tras bonding con fallback a socket seguro.
    - Android 6+/iOS exigen autorización en pantalla del objetivo para OBEX.
    - Android 10+ bloquea acceso a fotos por scoped storage.
    - `mediastore_enhanced` es SOLO local (ContentResolver del dispositivo atacante).
    - `gatt_image_read` es para dispositivos IoT con características BLE personalizadas.

---

## Dependencias Principales (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  permission_handler: ^12.0.1
  shared_preferences: ^2.5.3
  flutter_blue_plus: ^2.1.0
```

---

## Fecha de Actualización

**2026-08-20** — Auditoría completa del proyecto: 0 stubs encontrados, 0 código falso, modo automático completamente implementado (fases -1 a 99), UI consolidada en 2 tabs, sin errores de compilación. Actualizado `AGENTS.md` con líneas reales de `unified_attack_screen.dart` (5621 líneas). **Cambios de esta versión**: fase 0.5 protegida con timeout de 90 s para evitar cuelgues en `_runAdvancedSystemPhase`; extracción de imágenes priorizada en fase 1.5; motor de recomendaciones actualizado a `num` para reconocer fase 1.5.

Versión: BlueSnafer Pro 1.0.1
