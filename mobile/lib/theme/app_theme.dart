import 'package:flutter/material.dart';

/// Minimalistyczny motyw: dużo bieli, czarny akcent, Material 3.
final class AppTheme {
  AppTheme._();
  static const Color _ink = Color(0xFF111111);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _subtleFill = Color(0xFFF4F4F4);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _ink,
        brightness: Brightness.light,
        surface: _surface,
        onSurface: _ink,
        primary: _ink,
        onPrimary: _surface,
        secondary: _muted,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: _surface,
        foregroundColor: _ink,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: _ink,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surface,
        indicatorColor: _subtleFill,
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? _ink : _muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return IconThemeData(color: selected ? _ink : _muted, size: 24);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _subtleFill,
        selectedColor: _ink,
        disabledColor: _subtleFill,
        labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        secondaryLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFEEEEEE), thickness: 1),
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(color: _ink, height: 1.35),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: _ink, height: 1.35),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: _ink,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
