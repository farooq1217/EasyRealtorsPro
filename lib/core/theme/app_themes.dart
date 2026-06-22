import 'package:flutter/material.dart';

enum ThemeType {
  orangeRust,
  oliveGreen,
  royalBlue,
  crimsonRed,
  magentaPink,
  emeraldGreen,
  purpleViolet,
  goldenAmber,
  tealCyan,
  slateGray,
}

class AppThemes {
  static ThemeData getTheme(ThemeType themeType) {
    switch (themeType) {
      case ThemeType.orangeRust:
        return _orangeRustTheme;
      case ThemeType.oliveGreen:
        return _oliveGreenTheme;
      case ThemeType.royalBlue:
        return _royalBlueTheme;
      case ThemeType.crimsonRed:
        return _crimsonRedTheme;
      case ThemeType.magentaPink:
        return _magentaPinkTheme;
      case ThemeType.emeraldGreen:
        return _emeraldGreenTheme;
      case ThemeType.purpleViolet:
        return _purpleVioletTheme;
      case ThemeType.goldenAmber:
        return _goldenAmberTheme;
      case ThemeType.tealCyan:
        return _tealCyanTheme;
      case ThemeType.slateGray:
        return _slateGrayTheme;
    }
  }

  // ✅ DEFAULT THEME - Orange/Rust (Aapki app ka color)
  static final ThemeData _orangeRustTheme = ThemeData(
    primarySwatch: Colors.orange,
    primaryColor: const Color(0xFFFF6B35),
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFFF6B35),
      secondary: Color(0xFFFF8C42),
      surface: Color(0xFFFFF5F0),
      background: Color(0xFFFFFAF7),
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFF6B35),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
      ),
    ),
  );

  // Olive Green
  static final ThemeData _oliveGreenTheme = ThemeData(
    primarySwatch: Colors.green,
    primaryColor: const Color(0xFF4A7C59),
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF4A7C59),
      secondary: Color(0xFF6B9B7A),
      surface: Color(0xFFF5F9F6),
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4A7C59),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  // Royal Blue
  static final ThemeData _royalBlueTheme = ThemeData(
    primarySwatch: Colors.blue,
    primaryColor: const Color(0xFF2563EB),
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF2563EB),
      secondary: Color(0xFF3B82F6),
      surface: Color(0xFFF0F7FF),
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  // Crimson Red
  static final ThemeData _crimsonRedTheme = ThemeData(
    primarySwatch: Colors.red,
    primaryColor: const Color(0xFFDC2626),
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFDC2626),
      secondary: Color(0xFFEF4444),
      surface: Color(0xFFFDF2F2),
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  // Magenta Pink
  static final ThemeData _magentaPinkTheme = ThemeData(
    primarySwatch: Colors.pink,
    primaryColor: const Color(0xFFDB2777),
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFDB2777),
      secondary: Color(0xFFEC4899),
      surface: Color(0xFFFDF2F8),
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFDB2777),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  // Emerald Green
  static final ThemeData _emeraldGreenTheme = ThemeData(
    primarySwatch: Colors.teal,
    primaryColor: const Color(0xFF059669),
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF059669),
      secondary: Color(0xFF10B981),
      surface: Color(0xFFECFDF5),
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  // Purple Violet
  static final ThemeData _purpleVioletTheme = ThemeData(
    primarySwatch: Colors.purple,
    primaryColor: const Color(0xFF7C3AED),
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF7C3AED),
      secondary: Color(0xFF8B5CF6),
      surface: Color(0xFFF5F3FF),
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  // Golden Amber
  static final ThemeData _goldenAmberTheme = ThemeData(
    primarySwatch: Colors.amber,
    primaryColor: const Color(0xFFD97706),
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFD97706),
      secondary: Color(0xFFF59E0B),
      surface: Color(0xFFFEF3C7),
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  // Teal Cyan
  static final ThemeData _tealCyanTheme = ThemeData(
    primarySwatch: Colors.cyan,
    primaryColor: const Color(0xFF0891B2),
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF0891B2),
      secondary: Color(0xFF06B6D4),
      surface: Color(0xFFECFEFF),
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  // Slate Gray
  static final ThemeData _slateGrayTheme = ThemeData(
    primarySwatch: Colors.blueGrey,
    primaryColor: const Color(0xFF475569),
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF475569),
      secondary: Color(0xFF64748B),
      surface: Color(0xFFF8FAFC),
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF475569),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

class ThemeItem {
  final String name;
  final ThemeType type;
  final IconData icon;
  final Color color;

  ThemeItem({
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });
}

class ThemeList {
  static List<ThemeItem> getThemes() {
    return [
      ThemeItem(
        name: 'Orange Rust',
        type: ThemeType.orangeRust,
        icon: Icons.palette,
        color: const Color(0xFFFF6B35),
      ),
      ThemeItem(
        name: 'Olive Green',
        type: ThemeType.oliveGreen,
        icon: Icons.eco,
        color: const Color(0xFF4A7C59),
      ),
      ThemeItem(
        name: 'Royal Blue',
        type: ThemeType.royalBlue,
        icon: Icons.water_drop,
        color: const Color(0xFF2563EB),
      ),
      ThemeItem(
        name: 'Crimson Red',
        type: ThemeType.crimsonRed,
        icon: Icons.favorite,
        color: const Color(0xFFDC2626),
      ),
      ThemeItem(
        name: 'Magenta Pink',
        type: ThemeType.magentaPink,
        icon: Icons.favorite,
        color: const Color(0xFFDB2777),
      ),
      ThemeItem(
        name: 'Emerald Green',
        type: ThemeType.emeraldGreen,
        icon: Icons.nature,
        color: const Color(0xFF059669),
      ),
      ThemeItem(
        name: 'Purple Violet',
        type: ThemeType.purpleViolet,
        icon: Icons.auto_awesome,
        color: const Color(0xFF7C3AED),
      ),
      ThemeItem(
        name: 'Golden Amber',
        type: ThemeType.goldenAmber,
        icon: Icons.star,
        color: const Color(0xFFD97706),
      ),
      ThemeItem(
        name: 'Teal Cyan',
        type: ThemeType.tealCyan,
        icon: Icons.waves,
        color: const Color(0xFF0891B2),
      ),
      ThemeItem(
        name: 'Slate Gray',
        type: ThemeType.slateGray,
        icon: Icons.layers,
        color: const Color(0xFF475569),
      ),
    ];
  }
}