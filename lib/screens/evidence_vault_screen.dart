import 'package:flutter/material.dart';
import '../services/real_database_service.dart';
import 'dart:convert';

class EvidenceVaultScreen extends StatefulWidget {
  const EvidenceVaultScreen({super.key});

  @override
  State<EvidenceVaultScreen> createState() => _EvidenceVaultScreenState();
}

class _EvidenceVaultScreenState extends State<EvidenceVaultScreen> {
  final RealDatabaseService _dbService = RealDatabaseService();
  List<Map<String, dynamic>> _evidences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvidences();
  }

  Future<void> _loadEvidences() async {
    final data = await _dbService.getEvidences();
    setState(() {
      _evidences = data.reversed.toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('LOOT & EVIDENCE VAULT', style: TextStyle(fontFamily: 'monospace', fontSize: 14, color: Colors.greenAccent)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.cyanAccent), onPressed: _loadEvidences),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
        : _evidences.isEmpty 
          ? _buildEmptyState()
          : ListView.builder(
              itemCount: _evidences.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) => _buildEvidenceCard(_evidences[index]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white10),
          SizedBox(height: 16),
          Text('VAULT EMPTY', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold)),
          Text('Launch a mission to collect data.', style: TextStyle(color: Colors.white10, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard(Map<String, dynamic> evidence) {
    final String type = evidence['type'] ?? 'DATA';
    final IconData icon = _getIconForType(type);
    final Color color = _getColorForType(type);

    return Card(
      color: const Color(0xFF16213E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.3))),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(type, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        subtitle: Text('Target: ${evidence['target']} • ${evidence['timestamp'].toString().substring(0, 16)}', 
          style: const TextStyle(color: Colors.white54, fontSize: 10)),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.black,
            child: Text(
              evidence['data'].toString(),
              style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    if (type.contains('OBEX')) return Icons.image;
    if (type.contains('GATT')) return Icons.memory;
    if (type.contains('AT')) return Icons.contact_phone;
    return Icons.description;
  }

  Color _getColorForType(String type) {
    if (type.contains('OBEX')) return Colors.greenAccent;
    if (type.contains('GATT')) return Colors.amberAccent;
    if (type.contains('AT')) return Colors.redAccent;
    return Colors.cyanAccent;
  }
}
