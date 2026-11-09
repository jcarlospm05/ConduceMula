import 'package:flutter/material.dart';

import 'mule_tokens.dart';

/// INTERFAZ_MULEAGENT_V1 — one flat design system for both roles.
ThemeData muleTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? MulePalette.deepBlue : MulePalette.lightSurface;
  final background = dark ? MulePalette.navy : MulePalette.lightBackground;
  final foreground = dark ? MulePalette.darkText : MulePalette.navy;
  final secondary = dark
      ? MulePalette.darkSecondaryText
      : MulePalette.lightSecondaryText;
  final border = dark ? MulePalette.darkBorder : MulePalette.lightBorder;
  final primary = dark ? MulePalette.cyan : MulePalette.navy;
  final primaryInk = dark ? MulePalette.navy : Colors.white;
  final scheme = ColorScheme.fromSeed(
    seedColor: MulePalette.cyan,
    brightness: brightness,
  ).copyWith(
    primary: primary,
    onPrimary: primaryInk,
    surface: surface,
    onSurface: foreground,
    outline: border,
    error: MulePalette.pending,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: MuleTypography.family,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        color: foreground,
        fontSize: MuleTypography.titleSize,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: foreground,
        fontSize: MuleTypography.sectionSize,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: foreground,
        fontSize: MuleTypography.bodySize,
      ),
      bodyMedium: TextStyle(
        color: foreground,
        fontSize: MuleTypography.secondarySize,
      ),
      bodySmall: TextStyle(
        color: secondary,
        fontSize: MuleTypography.auxiliarySize,
      ),
    ),
    cardColor: surface,
    dividerColor: border,
    iconTheme: IconThemeData(color: foreground),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      labelStyle: TextStyle(color: secondary),
      hintStyle: TextStyle(color: secondary),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MuleMetrics.fieldRadius),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MuleMetrics.fieldRadius),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MuleMetrics.fieldRadius),
        borderSide: const BorderSide(color: MulePalette.cyan, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(
          double.infinity,
          MuleMetrics.primaryMinHeight,
        ),
        backgroundColor: primary,
        foregroundColor: primaryInk,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        textStyle: const TextStyle(
          fontFamily: MuleTypography.family,
          fontSize: MuleTypography.primaryButtonSize,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MuleMetrics.buttonRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, MuleMetrics.secondaryMinHeight),
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MuleMetrics.cardRadius),
        ),
        textStyle: const TextStyle(
          fontFamily: MuleTypography.family,
          fontSize: MuleTypography.secondarySize,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
