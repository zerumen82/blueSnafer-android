import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/device_utils.dart' as device_utils;

class RealTimeConsoleScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const RealTimeConsoleScreen({super.key, required this.device});

  @override
  State<RealTimeConsoleScreen> createState() => _RealTimeConsoleScreenState();
}

class _RealTimeConsoleScreenState extends State<RealTimeConsoleScreen> {
  static const _eventChannel = EventChannel('exploit_events');
  final List<Map<String, dynamic>> _packets = [];
  final ScrollController _scrollController = ScrollController();
  bool _isAutoScrollEnabled = true;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (mounted) {
        setState(() {
          _packets.add(Map<String, dynamic>.from(event));
          if (_packets.length > 200) _packets.removeAt(0); // Limitar memoria
        });
        
        if (_isAutoScrollEnabled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Text('LIVE SNIFFER: ${device_utils.getDeviceDisplayName(widget.device)}', style: const TextStyle(fontSize: 14, fontFamily: 'monospace')),
        actions: [
          IconButton(
            icon: Icon(_isAutoScrollEnabled ? Icons.arrow_downward : Icons.pause, color: Colors.cyanAccent),
            onPressed: () => setState(() => _isAutoScrollEnabled = !_isAutoScrollEnabled),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: () => setState(() => _packets.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _packets.length,
              itemBuilder: (context, index) {
                final packet = _packets[index];
                return _buildPacketItem(packet);
              },
            ),
          ),
          _buildStatusFooter(),
        ],
      ),
    );
  }

  Widget _buildPacketItem(Map<String, dynamic> packet) {
    final bool isDump = packet['type'] == 'GATT_READ_DUMP';
    final Color accentColor = isDump ? Colors.amberAccent : Colors.cyanAccent;
    final String typeLabel = isDump ? '[MEMORY DUMP]' : '[LIVE TRAFFIC]';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDump ? Colors.amber.withOpacity(0.05) : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$typeLabel UUID: ${packet['uuid'].toString().substring(0, 8)}...',
                style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              Text(
                DateTime.fromMillisecondsSinceEpoch(packet['timestamp']).toString().split(' ').last,
                style: const TextStyle(color: Colors.white30, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            packet['data'],
            style: TextStyle(color: accentColor, fontFamily: 'monospace', fontSize: 12),
          ),
          Text(
            'ASCII: ${packet['ascii']}',
            style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFooter() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.blueGrey[900],
      child: Row(
        children: [
          const Icon(Icons.radio, size: 14, color: Colors.greenAccent),
          const SizedBox(width: 8),
          Text(
            'CAPTURADOS: ${_packets.length} PAQUETES',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          const Text('BÚFER: REAL-TIME', style: TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }
}
