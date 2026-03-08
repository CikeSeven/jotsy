import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff1e6586),
      surfaceTint: Color(0xff1e6586),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xffc4e7ff),
      onPrimaryContainer: Color(0xff004c6a),
      secondary: Color(0xff4e616d),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffd1e5f4),
      onSecondaryContainer: Color(0xff374955),
      tertiary: Color(0xff615a7c),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffe7deff),
      onTertiaryContainer: Color(0xff494264),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfff6fafe),
      onSurface: Color(0xff181c1f),
      onSurfaceVariant: Color(0xff41484d),
      outline: Color(0xff71787e),
      outlineVariant: Color(0xffc0c7cd),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2c3134),
      inversePrimary: Color(0xff90cef4),
      primaryFixed: Color(0xffc4e7ff),
      onPrimaryFixed: Color(0xff001e2d),
      primaryFixedDim: Color(0xff90cef4),
      onPrimaryFixedVariant: Color(0xff004c6a),
      secondaryFixed: Color(0xffd1e5f4),
      onSecondaryFixed: Color(0xff0a1e28),
      secondaryFixedDim: Color(0xffb6c9d7),
      onSecondaryFixedVariant: Color(0xff374955),
      tertiaryFixed: Color(0xffe7deff),
      onTertiaryFixed: Color(0xff1d1736),
      tertiaryFixedDim: Color(0xffcbc1e9),
      onTertiaryFixedVariant: Color(0xff494264),
      surfaceDim: Color(0xffd7dadf),
      surfaceBright: Color(0xfff6fafe),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff0f4f8),
      surfaceContainer: Color(0xffebeef3),
      surfaceContainerHigh: Color(0xffe5e8ed),
      surfaceContainerHighest: Color(0xffdfe3e7),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff003b52),
      surfaceTint: Color(0xff1e6586),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff317496),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff263844),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff5d707c),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff383252),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff70688c),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff740006),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffcf2c27),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff6fafe),
      onSurface: Color(0xff0d1215),
      onSurfaceVariant: Color(0xff30373c),
      outline: Color(0xff4c5359),
      outlineVariant: Color(0xff676e73),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2c3134),
      inversePrimary: Color(0xff90cef4),
      primaryFixed: Color(0xff317496),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff0b5b7c),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff5d707c),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff455763),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff70688c),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff575072),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffc3c7cb),
      surfaceBright: Color(0xfff6fafe),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff0f4f8),
      surfaceContainer: Color(0xffe5e8ed),
      surfaceContainerHigh: Color(0xffd9dde2),
      surfaceContainerHighest: Color(0xffced2d6),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff003044),
      surfaceTint: Color(0xff1e6586),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff004f6d),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff1c2e39),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff394c57),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff2e2847),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff4b4566),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff600004),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff98000a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff6fafe),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff262d32),
      outlineVariant: Color(0xff434a4f),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2c3134),
      inversePrimary: Color(0xff90cef4),
      primaryFixed: Color(0xff004f6d),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff00374d),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff394c57),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff223540),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff4b4566),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff352e4e),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffb5b9bd),
      surfaceBright: Color(0xfff6fafe),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffedf1f5),
      surfaceContainer: Color(0xffdfe3e7),
      surfaceContainerHigh: Color(0xffd1d5d9),
      surfaceContainerHighest: Color(0xffc3c7cb),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xff90cef4),
      surfaceTint: Color(0xff90cef4),
      onPrimary: Color(0xff00344a),
      primaryContainer: Color(0xff004c6a),
      onPrimaryContainer: Color(0xffc4e7ff),
      secondary: Color(0xffb6c9d7),
      onSecondary: Color(0xff20333e),
      secondaryContainer: Color(0xff374955),
      onSecondaryContainer: Color(0xffd1e5f4),
      tertiary: Color(0xffcbc1e9),
      onTertiary: Color(0xff322c4c),
      tertiaryContainer: Color(0xff494264),
      onTertiaryContainer: Color(0xffe7deff),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff0f1417),
      onSurface: Color(0xffdfe3e7),
      onSurfaceVariant: Color(0xffc0c7cd),
      outline: Color(0xff8b9297),
      outlineVariant: Color(0xff41484d),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdfe3e7),
      inversePrimary: Color(0xff1e6586),
      primaryFixed: Color(0xffc4e7ff),
      onPrimaryFixed: Color(0xff001e2d),
      primaryFixedDim: Color(0xff90cef4),
      onPrimaryFixedVariant: Color(0xff004c6a),
      secondaryFixed: Color(0xffd1e5f4),
      onSecondaryFixed: Color(0xff0a1e28),
      secondaryFixedDim: Color(0xffb6c9d7),
      onSecondaryFixedVariant: Color(0xff374955),
      tertiaryFixed: Color(0xffe7deff),
      onTertiaryFixed: Color(0xff1d1736),
      tertiaryFixedDim: Color(0xffcbc1e9),
      onTertiaryFixedVariant: Color(0xff494264),
      surfaceDim: Color(0xff0f1417),
      surfaceBright: Color(0xff353a3d),
      surfaceContainerLowest: Color(0xff0a0f12),
      surfaceContainerLow: Color(0xff181c1f),
      surfaceContainer: Color(0xff1c2023),
      surfaceContainerHigh: Color(0xff262b2e),
      surfaceContainerHighest: Color(0xff313539),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffb6e2ff),
      surfaceTint: Color(0xff90cef4),
      onPrimary: Color(0xff00293b),
      primaryContainer: Color(0xff5998bb),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffcbdfee),
      onSecondary: Color(0xff152833),
      secondaryContainer: Color(0xff8093a1),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xffe1d7ff),
      onTertiary: Color(0xff272140),
      tertiaryContainer: Color(0xff948cb1),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffd2cc),
      onError: Color(0xff540003),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff0f1417),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffd6dde3),
      outline: Color(0xffacb3b9),
      outlineVariant: Color(0xff8a9197),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdfe3e7),
      inversePrimary: Color(0xff004e6b),
      primaryFixed: Color(0xffc4e7ff),
      onPrimaryFixed: Color(0xff00131e),
      primaryFixedDim: Color(0xff90cef4),
      onPrimaryFixedVariant: Color(0xff003b52),
      secondaryFixed: Color(0xffd1e5f4),
      onSecondaryFixed: Color(0xff01131d),
      secondaryFixedDim: Color(0xffb6c9d7),
      onSecondaryFixedVariant: Color(0xff263844),
      tertiaryFixed: Color(0xffe7deff),
      onTertiaryFixed: Color(0xff120c2b),
      tertiaryFixedDim: Color(0xffcbc1e9),
      onTertiaryFixedVariant: Color(0xff383252),
      surfaceDim: Color(0xff0f1417),
      surfaceBright: Color(0xff404549),
      surfaceContainerLowest: Color(0xff04080b),
      surfaceContainerLow: Color(0xff1a1e21),
      surfaceContainer: Color(0xff24282c),
      surfaceContainerHigh: Color(0xff2f3337),
      surfaceContainerHighest: Color(0xff3a3e42),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffe2f2ff),
      surfaceTint: Color(0xff90cef4),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xff8ccaf0),
      onPrimaryContainer: Color(0xff000d16),
      secondary: Color(0xffe2f2ff),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffb2c5d4),
      onSecondaryContainer: Color(0xff000d16),
      tertiary: Color(0xfff4edff),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffc7bde5),
      onTertiaryContainer: Color(0xff0c0624),
      error: Color(0xffffece9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffaea4),
      onErrorContainer: Color(0xff220001),
      surface: Color(0xff0f1417),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xffeaf1f7),
      outlineVariant: Color(0xffbdc3ca),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdfe3e7),
      inversePrimary: Color(0xff004e6b),
      primaryFixed: Color(0xffc4e7ff),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xff90cef4),
      onPrimaryFixedVariant: Color(0xff00131e),
      secondaryFixed: Color(0xffd1e5f4),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffb6c9d7),
      onSecondaryFixedVariant: Color(0xff01131d),
      tertiaryFixed: Color(0xffe7deff),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xffcbc1e9),
      onTertiaryFixedVariant: Color(0xff120c2b),
      surfaceDim: Color(0xff0f1417),
      surfaceBright: Color(0xff4c5154),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff1c2023),
      surfaceContainer: Color(0xff2c3134),
      surfaceContainerHigh: Color(0xff373c40),
      surfaceContainerHighest: Color(0xff43474b),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true,
    fontFamily: 'HarmonyOSSansSC',
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    textTheme: textTheme.apply(
      fontFamily: 'HarmonyOSSansSC',
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    ),
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: colorScheme.surface,
  );

  List<ExtendedColor> get extendedColors => [];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
