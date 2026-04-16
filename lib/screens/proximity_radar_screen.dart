import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/real_exploit_service.dart';

class ProximityRadarScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const ProximityRadarScreen({super.key, required this.device});

  @override
  State<ProximityRadarScreen> createState() => _ProximityRadarScreenState();
}

class _ProximityRadarScreenState extends State<ProximityRadarScreen> {
  final RealExploitService _exploitService = RealExploitService();
  int _currentRSSI = -100;
  List<int> _rssiHistory = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _currentRSSI = int.parse(widget.device['rssi'] ?? '-100');
    _startTracking();
  }

  void _startTracking() {
    // Escaneo continuo de baja latencia para actualizar RSSI
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) async {
      final result = await _exploitService.startScan();
      if (result['success']) {
        final List<dynamic> devices = result['devices'];
        final thisDevice = devices.firstWhere(
          (d) => d['address'] == widget.device['address'],
          orElse: () => null,
        );
        
        if (thisDevice != null && mounted) {
          setState(() {
            _currentRSSI = int.parse(thisDevice['rssi']);
            _rssiHistory.add(_currentRSSI);
            if (_rssiHistory.length > 20) _rssiHistory.removeAt(0);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double distance = _calculateDistance(_currentRSSI);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('SIGINT: PROXIMITY RADAR', style: TextStyle(fontFamily: 'monospace', fontSize: 14)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          _buildRadarCircle(distance),
          const SizedBox(height: 40),
          _buildDataPanel(distance),
          const Spacer(),
          _buildHistoryGraph(),
        ],
      ),
    );
  }

  Widget _buildRadarCircle(double distance) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Círculos de fondo
          for (double i = 1; i <= 4; i++)
            Container(
              width: i * 60, height: i * 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.greenAccent.withOpacity(0.2 / i)),
              ),
            ),
          // Punto del objetivo
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: distance),
            duration: const Duration(milliseconds: 500),
            builder: (context, val, child) {
              return Container(
                width: 20, height: 20,
                margin: EdgeInsets.only(bottom: (val * 20).clamp(0, 200)),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent,
                  boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 10, spreadRadius: 2)],
                ),
              );
            },
          ),
          const Icon(Icons.person_pin_circle, color: Colors.blueAccent, size: 32), // Atacante (Tú)
        ],
      ),
    );
  }

  Widget _buildDataPanel(double distance) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('SIGNAL', '$_currentRSSI dBm', Colors.greenAccent),
          _buildStatColumn('EST. DISTANCE', '${distance.toStringAsFixed(1)}m', Colors.cyanAccent),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildHistoryGraph() {
    return Container(
      height: 100,
      width: double.infinity,
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _rssiHistory.map((val) {
          double h = (val + 100) * 2.0;
          return Container(
            width: 8, height: h.clamp(2, 100),
            decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
          );
        }).toList(),
      ),
    );
  }

  /// Friis Transmission Equation - Cálculo REAL de distancia basada en RSSI
  /// d = 10 ^ ((MeasuredPower - RSSI) / (10 * n))
  /// - MeasuredPower: RSSI esperado a 1 metro (típicamente -59 dBm)
  /// - n: Exponente de pérdida de trayectoria (2.0 = espacio libre, 2.7-4.0 = interiores)
  double _calculateDistance(int rssi) {
    const int measuredPower = -59; // RSSI a 1 metro (calibrado para BLE)
    const double n = 2.4; // Exponente de pérdida (interior típico, más preciso que 2.0)
    
    // Calcular usando la ecuación de Friis real
    final exponent = (measuredPower - rssi) / (10.0 * n);
    final distance = math.pow(10.0, exponent) as double;
    
    // Clamp para evitar valores extremos
    return distance.clamp(0.1, 100.0);
  }
}
