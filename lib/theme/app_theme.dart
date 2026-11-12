import 'package:flutter/material.dart';

import '../widgets/motion.dart';

const _headingFont = 'Lexend';
const _bodyFont = 'SourceSans3';

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF1D5BD8),
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFDCE7FB),
  onPrimaryContainer: Color(0xFF0B2A6B),
  secondary: Color(0xFF0B1F44),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFD4EDFB),
  onSecondaryContainer: Color(0xFF07405E),
  tertiary: Color(0xFF0E7A55),
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFD2F2E4),
  onTertiaryContainer: Color(0xFF06402C),
  error: Color(0xFFC22F2F),
  onError: Colors.white,
  errorContainer: Color(0xFFFFE1DE),
  onErrorContainer: Color(0xFF6B1210),
  surface: Color(0xFFF3F7FD),
  onSurface: Color(0xFF0B1F44),
  onSurfaceVariant: Color(0xFF4A5A78),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFFFFFFF),
  surfaceContainer: Color(0xFFE9EFF9),
  surfaceContainerHigh: Color(0xFFE1E9F6),
  surfaceContainerHighest: Color(0xFFD8E2F2),
  outline: Color(0xFF6F7E99),
  outlineVariant: Color(0xFFD9E1EE),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF9DBEFF),
  onPrimary: Color(0xFF0A1E4A),
  primaryContainer: Color(0xFF1F4BA8),
  onPrimaryContainer: Color(0xFFDCE7FB),
  secondary: Color(0xFFDCE7FB),
  onSecondary: Color(0xFF0B1F44),
  secondaryContainer: Color(0xFF0E4A6E),
  onSecondaryContainer: Color(0xFFD4EDFB),
  tertiary: Color(0xFF6FDDB0),
  onTertiary: Color(0xFF00382A),
  tertiaryContainer: Color(0xFF0D5A40),
  onTertiaryContainer: Color(0xFFD2F2E4),
  error: Color(0xFFFFA9A3),
  onError: Color(0xFF5B0E0C),
  errorContainer: Color(0xFF7A1F1C),
  onErrorContainer: Color(0xFFFFE1DE),
  surface: Color(0xFF0B1426),
  onSurface: Color(0xFFEEF3FB),
  onSurfaceVariant: Color(0xFFAAB8D3),
  surfaceContainerLowest: Color(0xFF14203A),
  surfaceContainerLow: Color(0xFF14203A),
  surfaceContainer: Color(0xFF1A2846),
  surfaceContainerHigh: Color(0xFF213152),
  surfaceContainerHighest: Color(0xFF283A5E),
  outline: Color(0xFF7D8BA8),
  outlineVariant: Color(0xFF2A3B5E),
);

abstract final class AppTheme {
  static ThemeData light() => _build(_lightScheme);
  static ThemeData dark() => _build(_darkScheme);

  static ThemeData _build(ColorScheme scheme) {
    final radius = BorderRadius.circular(14);
    final text = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _bodyFont,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.iOS: AppPageTransitionsBuilder(),
          TargetPlatform.windows: AppPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    TextStyle heading(double size, FontWeight weight, double height) =>
        TextStyle(
          fontFamily: _headingFont,
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        );

    TextStyle body(double size, FontWeight weight, double height) => TextStyle(
          fontFamily: _bodyFont,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: scheme.onSurface,
        );

    return TextTheme(
      displaySmall: heading(34, FontWeight.w700, 1.15),
      headlineMedium: heading(28, FontWeight.w700, 1.2),
      headlineSmall: heading(24, FontWeight.w600, 1.25),
      titleLarge: heading(20, FontWeight.w600, 1.3),
      titleMedium: heading(17, FontWeight.w600, 1.3),
      titleSmall: heading(15, FontWeight.w500, 1.3),
      bodyLarge: body(17, FontWeight.w400, 1.45),
      bodyMedium: body(16, FontWeight.w400, 1.45),
      bodySmall: body(14, FontWeight.w400, 1.4),
      labelLarge: body(16, FontWeight.w600, 1.2),
      labelMedium: body(14, FontWeight.w600, 1.2),
      labelSmall: body(13, FontWeight.w600, 1.2),
    );
  }
}
