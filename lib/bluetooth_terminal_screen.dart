import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/integrated_ai_service.dart';
import 'services/real_exploit_service.dart';

class BluetoothTerminalScreen extends StatefulWidget {
  final String deviceAddress;
  final String deviceName;

  const BluetoothTerminalScreen({
    super.key,
    required this.deviceAddress,
    required this.deviceName,
  });

  @override
  State<BluetoothTerminalScreen> createState() => _BluetoothTerminalScreenState();
}

class _BluetoothTerminalScreenState extends State<BluetoothTerminalScreen> {
  static const platform = MethodChannel('bluetooth_commands');
  final List<String> _output = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final IntegratedAIService _aiService = IntegratedAIService();
  final RealExploitService _exploitService = RealExploitService();
  
  bool _isExecuting = false;
  String _selectedCategory = 'AT';

  final Map<String, List<Map<String, String>>> _commands = {
    'AT': [
      {'cmd': 'AT', 'desc': 'Test'},
      {'cmd': 'AT+NAME', 'desc': 'Nombre'},
      {'cmd': 'AT+ADDR', 'desc': 'MAC'},
      {'cmd': 'AT+VERSION', 'desc': 'Versión'},
      {'cmd': 'AT+RSSI', 'desc': 'Señal'},
    ],
    'Reconocimiento': [
      {'cmd': 'bluetoothctl', 'desc': 'Info Completa'},
      {'cmd': 'sdp:browse', 'desc': 'Servicios'},
      {'cmd': 'sdp:records', 'desc': 'Registros SDP'},
      {'cmd': 'hci:info', 'desc': 'Info HCI'},
      {'cmd': 'l2ping', 'desc': 'Test L2CAP'},
    ],
    'BlueZ': [
      {'cmd': 'info', 'desc': 'Info'},
      {'cmd': 'pair', 'desc': 'Emparejar'},
      {'cmd': 'trust', 'desc': 'Confiar'},
      {'cmd': 'connect', 'desc': 'Conectar'},
      {'cmd': 'disconnect', 'desc': 'Desconectar'},
      {'cmd': 'remove', 'desc': 'Eliminar'},
    ],
    'Exploits': [
      {'cmd': 'exploit:obex', 'desc': 'OBEX Vuln'},
      {'cmd': 'exploit:ftp', 'desc': 'FTP Bypass'},
      {'cmd': 'pair:secure', 'desc': 'Secure Pair'},
    ],
    'BtleJack': [
      {'cmd': 'btlejack:scan', 'desc': 'Escanear BLE'},
      {'cmd': 'btlejack:sniff', 'desc': 'Sniffing'},
      {'cmd': 'btlejack:jam', 'desc': 'Jamming'},
      {'cmd': 'btlejack:hijack', 'desc': 'Hijacking'},
      {'cmd': 'btlejack:mitm', 'desc': 'MITM'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _addOutput('🔷 Terminal Bluetooth');
    _addOutput('📱 ${widget.deviceName}');
    _addOutput('📍 ${widget.deviceAddress}\n');
  }

  void _addOutput(String text) {
    setState(() {
      _output.add(text);
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _handleNaturalCommand(String input) async {
    if (input.trim().isEmpty) return;
    _textController.clear();
    _addOutput('\$ $input');

    setState(() => _isExecuting = true);

    try {
      final aiResponse = await _aiService.processNaturalCommand(input, widget.deviceAddress);
      
      if (aiResponse['action'] != 'UNKNOWN') {
        _addOutput('🤖 AI: ${aiResponse['rationale']}');
        _addOutput('⚡ Ejecutando ${aiResponse['type']}...');

        // Ejecución real según la intención detectada
        if (aiResponse['action'] == 'DOS_ATTACK') {
          final result = await _exploitService.executeDoS(widget.deviceAddress, aiResponse['params']['duration']);
          _addOutput(result['success'] ? '✅ DoS completado con éxito' : '❌ Fallo en el ataque DoS');
        } else if (aiResponse['action'] == 'FILE_EXFILTRATION') {
          final result = await _exploitService.exfiltrateFiles(widget.deviceAddress);
          _addOutput(result['success'] ? '✅ Conexión de archivos establecida' : '❌ Acceso denegado');
        } else if (aiResponse['action'] == 'SNIFFING') {
          _addOutput('📡 Sniffing activado en el canal de datos...');
        }
      } else {
        // Si no es lenguaje natural reconocido, tratarlo como comando técnico manual
        await _executeCommand(input);
      }
    } catch (e) {
      _addOutput('❌ Error IA: $e');
    }

    setState(() => _isExecuting = false);
  }

  Future<void> _executeCommand(String command) async {
    if (command.trim().isEmpty) return;

    _addOutput('\$ $command');
    
    if (command.toLowerCase() == 'clear') {
      setState(() {
        _output.clear();
      });
      return;
    }

    setState(() {
      _isExecuting = true;
    });

    try {
      final result = await platform.invokeMethod('executeCommand', {
        'address': widget.deviceAddress,
        'command': command,
      });
      
      _addOutput(result.toString());
    } catch (e) {
      _addOutput('❌ Error: $e');
    }

    setState(() {
      _isExecuting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName, style: const TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF1D1E33),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              setState(() {
                _output.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 50,
            color: const Color(0xFF1D1E33),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _commands.keys.map((category) {
                final isSelected = _selectedCategory == category;
                Color chipColor;
                switch (category) {
                  case 'AT':
                    chipColor = Colors.green;
                    break;
                  case 'Reconocimiento':
                    chipColor = Colors.blue;
                    break;
                  case 'BlueZ':
                    chipColor = Colors.cyan;
                    break;
                  case 'Exploits':
                    chipColor = Colors.red;
                    break;
                  case 'BtleJack':
                    chipColor = Colors.purple;
                    break;
                  default:
                    chipColor = Colors.grey;
                }
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    selectedColor: chipColor,
                    backgroundColor: Colors.grey[800],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _output.length,
                itemBuilder: (context, index) {
                  final line = _output[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      line,
                      style: TextStyle(
                        color: line.startsWith('\$') ? Colors.green :
                               line.contains('❌') || line.contains('✗') ? Colors.red :
                               line.contains('✓') || line.contains('✅') ? Colors.cyan :
                               line.contains('⚠') ? Colors.orange :
                               line.contains('🔷') || line.contains('📱') ? Colors.blue :
                               Colors.white70,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            color: const Color(0xFF0A0E21),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                if (_isExecuting)
                  const LinearProgressIndicator(color: Colors.blue),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Ej: "Tira la conexión" o comando manual...',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (val) => _handleNaturalCommand(val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: () => _handleNaturalCommand(_textController.text),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _commands[_selectedCategory]?.length ?? 0,
                  itemBuilder: (context, index) {
                    final cmd = _commands[_selectedCategory]![index];
                    return ElevatedButton(
                      onPressed: _isExecuting ? null : () => _executeCommand(cmd['cmd']!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedCategory == 'AT'
                          ? Colors.green[700]
                          : _selectedCategory == 'Reconocimiento'
                          ? Colors.blue[700]
                          : _selectedCategory == 'BlueZ'
                          ? Colors.cyan[700]
                          : _selectedCategory == 'Exploits'
                          ? Colors.red[700]
                          : _selectedCategory == 'BtleJack'
                          ? Colors.purple[700]
                          : Colors.grey[700],
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            cmd['desc']!,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
