import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Styl inspirowany nowoczesnymi platformami e-commerce: czysto, jasno, spokojnie.
final class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: DesignTokens.white,
      colorScheme: const ColorScheme.light(
        primary: DesignTokens.ink,
        onPrimary: DesignTokens.white,
        secondary: DesignTokens.accent,
        surface: DesignTokens.white,
        onSurface: DesignTokens.ink,
        outline: DesignTokens.line,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: DesignTokens.white,
        foregroundColor: DesignTokens.ink,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: DesignTokens.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: DesignTokens.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          side: const BorderSide(color: DesignTokens.line),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.subtleFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          borderSide: const BorderSide(color: DesignTokens.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          borderSide: const BorderSide(color: DesignTokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          borderSide: const BorderSide(color: DesignTokens.accent, width: 1.1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: DesignTokens.line, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DesignTokens.white,
        indicatorColor: DesignTokens.subtleFill,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? DesignTokens.ink : DesignTokens.mutedText,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? DesignTokens.ink : DesignTokens.mutedText,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: DesignTokens.subtleFill,
        selectedColor: DesignTokens.ink,
        disabledColor: DesignTokens.subtleFill,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(
          color: DesignTokens.ink,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          color: DesignTokens.ink,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: DesignTokens.ink,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: DesignTokens.ink,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          color: DesignTokens.ink,
          height: 1.45,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: DesignTokens.ink,
          height: 1.45,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: DesignTokens.mutedText,
          height: 1.35,
        ),
      ),
    );
  }
}