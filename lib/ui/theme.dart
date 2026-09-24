import 'package:flutter/material.dart';

/// Colori dell'app: gli stessi del desktop (ui/Theme.cpp).
class VColors {
  static const background = Color(0xFF0F1115);
  static const surface = Color(0xFF171A21);
  static const surfaceHigh = Color(0xFF1E222C);
  static const control = Color(0xFF232834);
  static const border = Color(0xFF252A35);
  static const borderStrong = Color(0xFF3A4152);
  static const text = Color(0xFFE6E8EE);
  static const muted = Color(0xFF8B93A7);
  static const faint = Color(0xFF5D6475);
  static const accent = Color(0xFF5B8CFF);
  static const accentLight = Color(0xFF8FB0FF);
  static const accentDark = Color(0xFF3F6BE0);
  static const positive = Color(0xFF34D399);
  static const negative = Color(0xFFFF6B6B);
  static const warning = Color(0xFFF5A524);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: VColors.accent,
    onPrimary: Colors.white,
    secondary: VColors.accentLight,
    surface: VColors.surface,
    onSurface: VColors.text,
    error: VColors.negative,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: VColors.background,
    canvasColor: VColors.background,
    splashFactory: InkSparkle.splashFactory,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFF2A2F3A)),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: VColors.text, displayColor: VColors.text),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: VColors.accent, width: 1.4)),
      errorBorder: border.copyWith(borderSide: const BorderSide(color: VColors.negative)),
      hintStyle: const TextStyle(color: VColors.faint),
      labelStyle: const TextStyle(color: VColors.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: VColors.text,
        side: const BorderSide(color: VColors.control),
        backgroundColor: VColors.control,
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: VColors.accentLight,
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: VColors.surface,
      indicatorColor: VColors.accent.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? VColors.text : VColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? VColors.accentLight : VColors.muted),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: VColors.surface,
      showDragHandle: true,
      dragHandleColor: VColors.borderStrong,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerColor: VColors.border,
    dividerTheme: const DividerThemeData(color: VColors.border, thickness: 1),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: VColors.accent,
      foregroundColor: Colors.white,
    ),
  );
}
