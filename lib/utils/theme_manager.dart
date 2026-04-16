import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestor de temas (Oscuro/Claro)
class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  static const String _keyThemeMode = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Inicializar tema guardado
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_keyThemeMode);

    if (savedMode != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.toString() == savedMode,
        orElse: () => ThemeMode.dark,
      );
      notifyListeners();
    }
  }

  /// Cambiar tema
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.toString());
  }

  /// Toggle entre oscuro y claro
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  /// Gradiente principal para fondos
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF0F2027), // Dark blue-green
      Color(0xFF203A43), // Medium blue-green
      Color(0xFF2C5364), // Light blue-green
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradiente para tarjetas y elementos destacados
  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0xFF1D1E33), // Dark purple-blue
      Color(0xFF2D2E43), // Medium purple-blue
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradiente para botones principales
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [
      Color(0xFF667eea), // Blue
      Color(0xFF764ba2), // Purple
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Tema oscuro mejorado
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF667eea),
      scaffoldBackgroundColor: const Color(0xFF0A0E21),

      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF667eea),
        secondary: Color(0xFF764ba2),
        surface: Color(0xFF1D1E33),
        background: Color(0xFF0A0E21),
        error: Color(0xFFE57373),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.white,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor: const Color(0xFF667eea).withOpacity(0.3),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF667eea),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1D1E33).withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2D2E43)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color(0xFF667eea);
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color(0xFF667eea).withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.3);
        }),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF667eea),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF2D2E43),
        thickness: 1,
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
        bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
        bodySmall: TextStyle(color: Colors.white60, fontSize: 12),
      ),
    );
  }

  /// Tema claro mejorado
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF667eea),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),

      colorScheme: const ColorScheme.light(
        primary: Color(0xFF667eea),
        secondary: Color(0xFF764ba2),
        surface: Colors.white,
        background: Color(0xFFF8F9FA),
        error: Color(0xFFE57373),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.black87,
        onBackground: Colors.black87,
        onError: Colors.white,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 2,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shadowColor: const Color(0xFF667eea).withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: const Color(0xFF667eea).withOpacity(0.2),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF667eea),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color(0xFF667eea);
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color(0xFF667eea).withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.3);
        }),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF667eea),
      ),

      dividerTheme: const DividerThemeData(
        color: Colors.grey,
        thickness: 1,
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Colors.black87, fontSize: 32, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: Colors.black87, fontSize: 16),
        bodyMedium: TextStyle(color: Colors.black54, fontSize: 14),
        bodySmall: TextStyle(color: Colors.black45, fontSize: 12),
      ),
    );
  }
}


