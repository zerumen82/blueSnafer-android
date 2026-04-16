import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';

/// Dashboard de estadísticas de ataques
class StatsDashboard extends StatefulWidget {
  const StatsDashboard({super.key});

  @override
  State<StatsDashboard> createState() => _StatsDashboardState();
}

class _StatsDashboardState extends State<StatsDashboard> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  final BluetoothService _bluetoothService = BluetoothService();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);

    try {
      final stats = await _bluetoothService.getStats();
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando estadísticas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('📊 Estadísticas'),
        backgroundColor: const Color(0xFF1D1E33),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmClearStats,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumen general
                  _buildSummaryCard(),
                  const SizedBox(height: 16),
                  
                  // Estadísticas de ataques
                  _buildAttackStatsCard(),
                  const SizedBox(height: 16),
                  
                  // Exploits más exitosos
                  _buildTopExploitsCard(),
                  const SizedBox(height: 16),
                  
                  // Dispositivos atacados
                  _buildDevicesCard(),
                  const SizedBox(height: 16),

                  // CVE detectados
                  _buildCVECard(),
                  const SizedBox(height: 16),

                  // Historial de operaciones recientes
                  _buildRecentOperationsCard(),
                  const SizedBox(height: 16),

                  // Estadísticas por dispositivo
                  _buildDeviceStatsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    final totalExploits = _stats['totalExploits'] as int? ?? 0;
    final successfulExploits = _stats['successfulExploits'] as int? ?? 0;
    final failedExploits = _stats['failedExploits'] as int? ?? 0;
    final successRate = _stats['successRate'] as double? ?? 0.0;

    return Card(
      color: const Color(0xFF1D1E33),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📈 Resumen General',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '⚔️',
                  '$totalExploits',
                  'Ataques',
                  Colors.blue,
                ),
                _buildStatItem(
                  '✅',
                  '$successfulExploits',
                  'Exitosos',
                  Colors.green,
                ),
                _buildStatItem(
                  '❌',
                  '$failedExploits',
                  'Fallidos',
                  Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: successRate / 100,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                successRate > 70 ? Colors.green : 
                successRate > 40 ? Colors.orange : Colors.red,
              ),
              minHeight: 10,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tasa de éxito: ${successRate.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label, Color color) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 32),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAttackStatsCard() {
    final uniqueDevices = _stats['uniqueDevices'] as int? ?? 0;
    final averageExecutionTime = _stats['averageExecutionTime'] as double? ?? 0.0;
    final mostCommonExploit = _stats['mostCommonExploit'] as String? ?? 'N/A';
    final recentOperations = _stats['recentOperations'] as List? ?? [];

    return Card(
      color: const Color(0xFF1D1E33),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚔️ Estadísticas de Ataques',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow('📱 Dispositivos únicos', '$uniqueDevices'),
            _buildStatRow('⏱️ Tiempo promedio', '${averageExecutionTime.toStringAsFixed(1)}s'),
            _buildStatRow('🎯 Mejor exploit', mostCommonExploit),
            _buildStatRow('📅 Último ataque', recentOperations.isNotEmpty ? _formatDate(recentOperations.first['timestamp'] as int?) : 'Nunca'),
          ],
        ),
      ),
    );
  }

  Widget _buildTopExploitsCard() {
    final recentOperations = _stats['recentOperations'] as List? ?? [];

    // Calcular estadísticas de exploits
    final exploitStats = <String, Map<String, dynamic>>{};
    for (final op in recentOperations) {
      final exploitType = op['exploitType'] as String? ?? 'Unknown';
      final success = op['success'] as bool? ?? false;

      if (!exploitStats.containsKey(exploitType)) {
        exploitStats[exploitType] = {'count': 0, 'success': 0};
      }
      exploitStats[exploitType]!['count'] = (exploitStats[exploitType]!['count'] as int) + 1;
      if (success) {
        exploitStats[exploitType]!['success'] = (exploitStats[exploitType]!['success'] as int) + 1;
      }
    }

    final topExploits = exploitStats.entries
        .map((e) {
          final count = e.value['count'] as int;
          final success = e.value['success'] as int;
          return {
            'name': e.key,
            'count': count,
            'success_rate': (success / count) * 100,
          };
        })
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return Card(
      color: const Color(0xFF1D1E33),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🏆 Top Exploits',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (topExploits.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No hay datos disponibles',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              ...List.generate(topExploits.take(5).length, (index) {
                final exploit = topExploits[index];
                return _buildExploitItem(
                  index + 1,
                  exploit['name']?.toString() ?? 'Unknown',
                  (exploit['count'] ?? 0) as int,
                  (exploit['success_rate'] ?? 0.0) as double,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildExploitItem(int rank, String name, int count, double successRate) {
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '  ';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            medal,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$count usos • ${successRate.toStringAsFixed(0)}% éxito',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: successRate > 70 ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${successRate.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesCard() {
    final uniqueDevices = _stats['uniqueDevices'] as int? ?? 0;
    final deviceStats = _stats['deviceStats'] as Map<String, dynamic>? ?? {};

    return Card(
      color: const Color(0xFF1D1E33),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📱 Dispositivos Atacados',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Total único', '$uniqueDevices'),
            _buildStatRow('Más atacado', deviceStats.isNotEmpty ? deviceStats.keys.first : 'N/A'),
            _buildStatRow('Total tests', deviceStats.values.fold(0, (sum, stats) => sum + (stats['totalTests'] as int? ?? 0)).toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildCVECard() {
    final cveDetection = _stats['cveDetection'] as Map<String, dynamic>? ?? {};
    final mostCommonCVE = _stats['mostCommonCVE'] as String? ?? 'N/A';

    return Card(
      color: const Color(0xFF1D1E33),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔍 CVE Detectados',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Total único', '${cveDetection.length}'),
            _buildStatRow('Más común', mostCommonCVE),
            if (cveDetection.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top CVE:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    ...cveDetection.entries.take(3).map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearStats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          '⚠️ Limpiar Estadísticas',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Estás seguro de que quieres eliminar todas las estadísticas? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _bluetoothService.clearStats();
        _loadStats();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Estadísticas eliminadas')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildRecentOperationsCard() {
    final recentOperations = List<Map<String, dynamic>>.from(_stats['recentOperations'] ?? []);

    return Card(
      color: const Color(0xFF1D1E33),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📅 Operaciones Recientes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (recentOperations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No hay operaciones recientes',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              ...recentOperations.take(5).map((op) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.white12,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              op['exploitType']?.toString() ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: op['success'] == true ? Colors.green : Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                op['success'] == true ? 'Éxito' : 'Fallo',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Dispositivo: ${op['deviceName'] ?? 'Unknown'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Fecha: ${_formatDate(op['timestamp'] as int?)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Duración: ${(op['durationMs'] as int? ?? 0) / 1000} segundos',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  String _formatDate(int? timestamp) {
    if (timestamp == null) return 'Nunca';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDeviceStatsCard() {
    final deviceStats = Map<String, dynamic>.from(_stats['deviceStats'] ?? {});

    return Card(
      color: const Color(0xFF1D1E33),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📱 Estadísticas por Dispositivo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (deviceStats.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No hay estadísticas de dispositivos disponibles',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              ...deviceStats.entries.take(3).map((entry) {
                final deviceStats = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.white12,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow('Primer visto', _formatDate(deviceStats['firstSeen'] as int?)),
                        _buildInfoRow('Último visto', _formatDate(deviceStats['lastSeen'] as int?)),
                        _buildInfoRow('Tests totales', '${deviceStats['totalTests']}'),
                        _buildInfoRow('Tests exitosos', '${deviceStats['successfulTests']}'),
                        _buildInfoRow('Tests fallidos', '${deviceStats['failedTests']}'),
                        _buildInfoRow('Tiempo promedio', '${deviceStats['averageExecutionTime']}ms'),
                      ],
                    ),
                  ),
                );
              }).toList(),
            if (deviceStats.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Y ${deviceStats.length - 3} dispositivos más...',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
