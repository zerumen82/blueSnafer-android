import 'package:flutter/material.dart';
import '../exploits/exploit_manager.dart';

/// Widget para ejecutar combinaciones de ataques automáticamente
/// Permite ejecutar secuencias de comandos con un solo clic
class AttackCombinationExecutor extends StatefulWidget {
  final ExploitManager exploitManager;
  final String deviceAddress;
  final Map<String, dynamic> discoveryData;

  const AttackCombinationExecutor({
    super.key,
    required this.exploitManager,
    required this.deviceAddress,
    required this.discoveryData,
  });

  @override
  State<AttackCombinationExecutor> createState() => _AttackCombinationExecutorState();
}

class _AttackCombinationExecutorState extends State<AttackCombinationExecutor> {
  bool _isExecuting = false;
  Map<String, dynamic> _executionResults = {};
  List<String> _currentCombination = [];

  @override
  Widget build(BuildContext context) {
    final combinations = SmartSuggestionSystem.getAttackCombinations(widget.discoveryData);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(
                  Icons.playlist_play,
                  color: Colors.cyan[300],
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'EJECUCIÓN AUTOMÁTICA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (_isExecuting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.cyan,
                    ),
                  ),
              ],
            ),
          ),
          
          // Combinaciones disponibles
          if (combinations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: combinations.map((combination) {
                  return Tooltip(
                    message: combination.join(' → '),
                    child: ActionChip(
                      avatar: const Icon(Icons.play_arrow, size: 14, color: Colors.white),
                      label: Text(
                        'Ejecutar ${combination.length} pasos',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                      backgroundColor: Colors.blue[700],
                      onPressed: _isExecuting ? null : () => _executeCombination(combination),
                    ),
                  );
                }).toList(),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                'Realice descubrimientos para ver combinaciones',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          
          // Resultados de ejecución
          if (_executionResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RESULTADOS:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._buildResultWidgets(),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  // Ejecutar una combinación de comandos
  Future<void> _executeCombination(List<String> combination) async {
    final currentContext = context; // Almacenar contexto antes de operaciones asíncronas

    setState(() {
      _isExecuting = true;
      _currentCombination = combination;
      _executionResults = {};
    });

    try {
      final results = await SmartCommandExecutor.executeCommandChain(
        combination,
        widget.deviceAddress,
        widget.exploitManager,
      );

      setState(() {
        _executionResults = results;
        _isExecuting = false;
      });

      // Mostrar resumen de ejecución
      _showExecutionSummary(results);
    } catch (e) {
      setState(() {
        _isExecuting = false;
      });

      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('Error en ejecución: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Widgets de resultados
  List<Widget> _buildResultWidgets() {
    return _executionResults.entries.map((entry) {
      final result = entry.value;
      final isSuccess = result['success'] == true;
      
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSuccess ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSuccess ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              size: 14,
              color: isSuccess ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${entry.key}: ${result['message'] ?? 'Completado'}',
                style: TextStyle(
                  color: isSuccess ? Colors.green : Colors.red,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
  
  // Mostrar resumen de ejecución
  void _showExecutionSummary(Map<String, dynamic> results) {
    final successful = results.values.where((result) => result['success'] == true).length;
    final total = results.length;

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ejecución Completada'),
          content: Text(
            'Comandos exitosos: $successful/$total\n\n'
            'Combinación ejecutada: ${_currentCombination.join(' → ')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}