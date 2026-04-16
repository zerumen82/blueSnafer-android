import 'package:flutter/material.dart';

class MinimalistTheme {
  // Colores minimalistas
  static const Color primaryColor = Colors.blue;
  static const Color secondaryColor = Colors.blueAccent;
  static const Color accentColor = Colors.blue;
  static const Color backgroundColor = Colors.white;
  static const Color textColor = Colors.black87;
  static const Color textSecondaryColor = Colors.black54;

  // Estilos de texto minimalistas
  static const TextStyle titleStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: textColor,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 14,
    color: textSecondaryColor,
  );

  static const TextStyle buttonStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  static const TextStyle logStyle = TextStyle(
    fontSize: 12,
    color: textSecondaryColor,
    fontFamily: 'monospace',
  );

  // Temas minimalistas
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        titleTextStyle: titleStyle.copyWith(color: Colors.white),
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: titleStyle,
        bodyLarge: TextStyle(fontSize: 16, color: textColor),
        bodyMedium: subtitleStyle,
      ),
    );
  }

  // Widgets minimalistas
  static Widget buildMinimalistAppBar(String title) {
    return AppBar(
      title: Text(title),
    );
  }

  static Widget buildMinimalistButton(String text, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(text),
    );
  }

  static Widget buildMinimalistCard(Widget child) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  static Widget buildMinimalistLogView(String logText) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        child: Text(
          logText,
          style: logStyle,
        ),
      ),
    );
  }
}
