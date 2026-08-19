import 'package:flutter/material.dart';

class SonoritizPalette {
  // Brand Colors (Coral Red base)
  static const Color coral50 = Color(0xFFFFF0EE);
  static const Color coral100 = Color(0xFFFFD9D1);
  static const Color coral300 = Color(0xFFFFA18E);
  static const Color coral500 = Color(0xFFFF5E5B); // Primary Brand
  static const Color coral700 = Color(0xFFD33D39);
  static const Color coral900 = Color(0xFF9C1F1C);

  // Secondary (Peach/Orange base)
  static const Color peach300 = Color(0xFFFFCBB8);
  static const Color peach500 = Color(0xFFFFAC93);

  // Neutrals - Dark (Backgrounds)
  static const Color grey900 = Color(0xFF0A0A0A); // Deep Background
  static const Color grey850 = Color(0xFF141414); // Surface
  static const Color grey800 = Color(0xFF1F1F1F); // Surface Elevated
  static const Color grey700 = Color(0xFF2E2E2E); // Borders / Dividers

  // Neutrals - Light
  static const Color grey50 = Color(0xFFFAFAFA); // Light Background
  static const Color grey100 = Color(0xFFF5F5F5); // Light Surface
  static const Color grey200 = Color(0xFFE5E5E5); // Light Surface Elevated
  static const Color grey300 = Color(0xFFD4D4D4); // Light Borders
  
  // Semantic Neutrals (Text)
  static const Color white = Color(0xFFFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color white40 = Color(0x66FFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color black70 = Color(0xB3000000);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFE53935);
}

class AppColors {
  // =========================================================================
  // LEGACY COLORS (Garder pour la rétrocompatibilité pendant la refonte)
  // TODO: Les supprimer une fois tous les écrans migrés vers Theme.of(context).colorScheme
  // =========================================================================
  static const Color primary = SonoritizPalette.coral500;
  static const Color secondary = SonoritizPalette.peach500;
  static const Color background = SonoritizPalette.grey900;
  static const Color surface = SonoritizPalette.grey850;
  static const Color surfaceLight = SonoritizPalette.grey800;
  static const Color textPrimary = SonoritizPalette.white;
  static const Color textSecondary = SonoritizPalette.white70;
  static const Color textMuted = SonoritizPalette.white40;
  static const Color error = SonoritizPalette.error;
  static const Color success = SonoritizPalette.success;
  static const Color cardBorder = Color(0x1FFFFFFF);

  // =========================================================================
  // SEMANTIC COLOR SCHEMES (Pour la nouvelle architecture UI)
  // =========================================================================
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: SonoritizPalette.coral500,
    onPrimary: SonoritizPalette.white,
    primaryContainer: SonoritizPalette.coral900,
    onPrimaryContainer: SonoritizPalette.coral100,
    secondary: SonoritizPalette.peach500,
    onSecondary: SonoritizPalette.grey900,
    secondaryContainer: SonoritizPalette.grey800,
    onSecondaryContainer: SonoritizPalette.peach300,
    surface: SonoritizPalette.grey850,
    onSurface: SonoritizPalette.white,
    surfaceContainerHighest: SonoritizPalette.grey800, // ex surfaceVariant
    onSurfaceVariant: SonoritizPalette.white70,
    error: SonoritizPalette.error,
    onError: SonoritizPalette.white,
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    outline: SonoritizPalette.grey700,
  );

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: SonoritizPalette.coral500,
    onPrimary: SonoritizPalette.white,
    primaryContainer: SonoritizPalette.coral100,
    onPrimaryContainer: SonoritizPalette.coral900,
    secondary: SonoritizPalette.coral700,
    onSecondary: SonoritizPalette.white,
    secondaryContainer: SonoritizPalette.coral50,
    onSecondaryContainer: SonoritizPalette.coral900,
    surface: SonoritizPalette.grey50,
    onSurface: SonoritizPalette.black,
    surfaceContainerHighest: SonoritizPalette.grey100,
    onSurfaceVariant: SonoritizPalette.black70,
    error: SonoritizPalette.error,
    onError: SonoritizPalette.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    outline: SonoritizPalette.grey300,
  );
}
