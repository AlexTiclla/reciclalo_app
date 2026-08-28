import 'package:flutter/material.dart';

/// Paleta del design system de EcoRecicla (tokens exportados desde Stitch).
///
/// Los nombres siguen los del design system para que sea directo contrastar
/// una pantalla contra su diseño.
abstract final class EcoColors {
  static const primary = Color(0xFF0F5238);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF2D6A4F);
  static const onPrimaryContainer = Color(0xFFA8E7C5);

  static const secondary = Color(0xFF2B694D);
  static const secondaryContainer = Color(0xFFB0F1CC);
  static const onSecondaryContainer = Color(0xFF327053);
  static const onSecondaryFixedVariant = Color(0xFF0C5136);

  static const leafDark = Color(0xFF1B4332);
  static const mintLight = Color(0xFFD8F3DC);

  static const surface = Color(0xFFF8F9FA);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF3F4F5);
  static const surfaceContainer = Color(0xFFEDEEEF);
  static const surfaceContainerHigh = Color(0xFFE7E8E9);
  static const surfaceVariant = Color(0xFFE1E3E4);
  static const onSurface = Color(0xFF191C1D);
  static const onSurfaceVariant = Color(0xFF404943);

  static const outline = Color(0xFF707973);
  static const outlineVariant = Color(0xFFBFC9C1);

  static const statusBlue = Color(0xFF457B9D);
  static const warningAmber = Color(0xFFFCBF49);
  static const dangerRed = Color(0xFFE63946);
  static const error = Color(0xFFBA1A1A);

  /// Verde y verde oscuro de marca de WhatsApp, usados en el botón de contacto.
  static const whatsapp = Color(0xFF25D366);
  static const whatsappDark = Color(0xFF075E54);
}

/// Espaciados del design system basados estrictamente en escala de 8 px.
/// Mantiene el ritmo vertical y consistencia según la guía de IHC.
abstract final class EcoSpacing {
  static const double element = 8;     // 8px  - Pequeña separación
  static const double stack = 16;      // 16px - Contenido relacionado
  static const double container = 24;  // 24px - Entre grupos
  static const double section = 32;    // 32px - Entre secciones

  /// Alto mínimo de un objetivo táctil (guía de accesibilidad de Material).
  static const double touchTarget = 48; // Múltiplo de 8 (8 x 6)
}

abstract final class EcoRadius {
  static const double lg = 8;
  static const double xl = 12;
  static const double x2l = 16;
  static const Radius full = Radius.circular(999);
}

/// Sombras suaves y verdosas del diseño, en lugar de la elevación por defecto.
abstract final class EcoShadows {
  static const ambient = [
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const raised = [
    BoxShadow(color: Color(0x330F5238), blurRadius: 16, offset: Offset(0, 8)),
  ];

  static const sheet = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, -8)),
  ];
}

/// Escala tipográfica del design system (tamaños, alturas y tracking de Stitch).
const _textTheme = TextTheme(
  headlineLarge: TextStyle(
    fontSize: 26,
    height: 32 / 26,
    letterSpacing: -0.52,
    fontWeight: FontWeight.w700,
    color: EcoColors.onSurface,
  ),
  headlineMedium: TextStyle(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
    color: EcoColors.onSurface,
  ),
  bodyLarge: TextStyle(fontSize: 18, height: 28 / 18, color: EcoColors.onSurface),
  bodyMedium: TextStyle(fontSize: 16, height: 24 / 16, color: EcoColors.onSurface),
  bodySmall: TextStyle(fontSize: 14, height: 20 / 14, color: EcoColors.onSurfaceVariant),
  labelLarge: TextStyle(
    fontSize: 14,
    height: 16 / 14,
    letterSpacing: 0.14,
    fontWeight: FontWeight.w600,
  ),
  labelMedium: TextStyle(
    fontSize: 14,
    height: 16 / 14,
    letterSpacing: 0.14,
    fontWeight: FontWeight.w600,
  ),
  labelSmall: TextStyle(
    fontSize: 12,
    height: 14 / 12,
    letterSpacing: 0.24,
    fontWeight: FontWeight.w500,
  ),
);

ThemeData buildEcoTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: EcoColors.primary,
    primary: EcoColors.primary,
    onPrimary: EcoColors.onPrimary,
    primaryContainer: EcoColors.primaryContainer,
    onPrimaryContainer: EcoColors.onPrimaryContainer,
    secondary: EcoColors.secondary,
    secondaryContainer: EcoColors.secondaryContainer,
    onSecondaryContainer: EcoColors.onSecondaryContainer,
    surface: EcoColors.surface,
    onSurface: EcoColors.onSurface,
    onSurfaceVariant: EcoColors.onSurfaceVariant,
    outline: EcoColors.outline,
    outlineVariant: EcoColors.outlineVariant,
    error: EcoColors.error,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: EcoColors.surface,
    textTheme: _textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: EcoColors.surface,
      foregroundColor: EcoColors.onSurfaceVariant,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w700,
        color: EcoColors.primary,
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: EcoColors.surfaceContainerLowest,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(EcoRadius.xl)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: EcoColors.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(EcoRadius.lg)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: EcoColors.primary,
        foregroundColor: EcoColors.onPrimary,
        minimumSize: const Size.fromHeight(EcoSpacing.touchTarget),
        textStyle: _textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EcoRadius.lg),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: EcoColors.onSurfaceVariant,
        minimumSize: const Size.fromHeight(EcoSpacing.touchTarget),
        textStyle: _textTheme.labelLarge,
        side: const BorderSide(color: EcoColors.outlineVariant, width: 2),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(EcoRadius.full),
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: EcoColors.surfaceVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: EcoColors.leafDark,
    ),
  );
}