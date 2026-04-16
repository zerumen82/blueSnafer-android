import 'package:flutter/material.dart';
import '../exploits/exploit_manager.dart';

/// Panel de sugerencias inteligentes basado en descubrimientos reales
/// Muestra comandos sugeridos automáticamente según los servicios y archivos encontrados
class SmartSuggestionPanel extends StatelessWidget {
  final Map<String, dynamic> discoveryData;
  final Function(String) onCommandSelected;
  final bool isLoading;
  final Map<String, double> successRates;

  const SmartSuggestionPanel({
    super.key,
    required this.discoveryData,
    required this.onCommandSelected,
    required this.isLoading,
    required this.successRates,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions =
        SmartSuggestionSystem.getSuggestionsBasedOnDiscovery(discoveryData);
    final prioritizedSuggestions =
        SmartSuggestionSystem.prioritizeSuggestions(suggestions, successRates);

    // Mapeo de comandos a descripciones amigables
    final commandDescriptions = {
      'file:enum_real': '📁 Enumerar archivos reales',
      'file:exfiltrate_real': '📤 Exfiltrar archivos reales',
      'image:filter_real': '🖼️ Filtrar imágenes reales',
      'ble:advanced_enum': '📶 Enumeración BLE avanzada',
      'btlejack:scan': '🔍 Escanear dispositivos BLE',
      'btlejack:sniff': '👃 Sniffing BLE',
      'btlejack:hijack': '🎯 Hijacking BLE',
      'btlejack:mitm': '🔄 MITM BLE',
      'btlejack:blesa': '💥 Exploit BLESA',
      'vuln:obex_put': '📤 Exploit OBEX PUT',
      'vuln:ftp_anonymous': '📂 FTP Anonymous',
      'vuln:ble_reconnection': '🔗 Reconexión BLE',
      'vuln:at_command_injection': '💉 Inyección AT',
      'vuln:sdp_information_leak': '📊 Leak SDP',
      'sdp:browse': '🔍 Navegar SDP',
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey[800],
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.blueGrey[900]!,
            Colors.blueGrey[800]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado con IA y descubrimientos
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Colors.cyan[300],
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'SUGERENCIAS INTELIGENTES',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                _buildDiscoveryBadges(),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),

          // Comandos sugeridos
          if (prioritizedSuggestions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Realice descubrimientos para obtener sugerencias',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: prioritizedSuggestions.take(6).map((cmd) {
                    final successRate = successRates[cmd] ?? 0.5;
                    final successColor = _getSuccessRateColor(successRate);

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Tooltip(
                        message:
                            'Tasa de éxito: ${(successRate * 100).toStringAsFixed(1)}%',
                        child: ActionChip(
                          avatar: CircleAvatar(
                            backgroundColor: successColor.withOpacity(0.8),
                            radius: 10,
                            child: Text(
                              '${(successRate * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              commandDescriptions[cmd] ?? cmd,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          backgroundColor: Colors.blueGrey[700],
                          onPressed:
                              isLoading ? null : () => onCommandSelected(cmd),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Combinaciones de ataques
          if (prioritizedSuggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt,
                    color: Colors.orange[300],
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'COMBINACIONES:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ..._buildAttackCombinationChips(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Badges de descubrimientos
  Widget _buildDiscoveryBadges() {
    final badges = <Widget>[];

    if (discoveryData['services'] is List &&
        (discoveryData['services'] as List).isNotEmpty) {
      badges.add(_buildBadge(
          '📡 ${(discoveryData['services'] as List).length}', Colors.blue));
    }

    if (discoveryData['files_found'] != null &&
        discoveryData['files_found'] > 0) {
      badges
          .add(_buildBadge('📁 ${discoveryData['files_found']}', Colors.green));
    }

    if (discoveryData['images_found'] != null &&
        discoveryData['images_found'] > 0) {
      badges.add(
          _buildBadge('🖼️ ${discoveryData['images_found']}', Colors.purple));
    }

    return Row(children: badges);
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Chips de combinaciones de ataques
  List<Widget> _buildAttackCombinationChips() {
    final combinations =
        SmartSuggestionSystem.getAttackCombinations(discoveryData);
    return combinations.take(2).map((combo) {
      return Tooltip(
        message: combo.join(' → '),
        child: Chip(
          label: Text(
            '${combo.length} pasos',
            style: const TextStyle(fontSize: 10, color: Colors.white70),
          ),
          backgroundColor: Colors.orange.withOpacity(0.2),
          side: BorderSide(color: Colors.orange.withOpacity(0.5)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }).toList();
  }

  // Color basado en tasa de éxito
  Color _getSuccessRateColor(double rate) {
    if (rate >= 0.8) return Colors.green;
    if (rate >= 0.6) return Colors.orange;
    return Colors.red;
  }
}


