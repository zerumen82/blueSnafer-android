import 'package:flutter/material.dart';

class CommandCategoryPanel extends StatelessWidget {
  final String category;
  final List<Map<String, String>> commands;
  final Function(String) onCommandSelected;
  final bool isLoading;
  final String connectionType;

  const CommandCategoryPanel({
    super.key,
    required this.category,
    required this.commands,
    required this.onCommandSelected,
    required this.isLoading,
    required this.connectionType,
  });

  @override
  Widget build(BuildContext context) {
    // Determinar el color según la categoría
    Color categoryColor;
    switch (category) {
      case '📡 Conexión': categoryColor = Colors.blue; break;
      case '🔍 Escaneo': categoryColor = Colors.green; break;
      case '📂 Archivos': categoryColor = Colors.amber; break;
      case '⚡ BLE': categoryColor = Colors.purple; break;
      case '📱 Control': categoryColor = Colors.cyan; break;
      case '🛠️ Avanzado': categoryColor = Colors.deepOrange; break;
      default: categoryColor = Colors.grey;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la categoría
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            category,
            style: TextStyle(
              color: categoryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Grid de comandos
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.2,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: commands.length,
          itemBuilder: (context, index) {
            final cmd = commands[index];
            return ElevatedButton(
              onPressed: isLoading ? null : () => onCommandSelected(cmd['cmd']!),
              style: ElevatedButton.styleFrom(
                backgroundColor: categoryColor.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              child: Text(
                cmd['desc']!,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ],
    );
  }
}