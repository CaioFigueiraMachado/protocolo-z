import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identidade visual (prancha "Projeto Z"):
/// Cobalto #2A3CF0 · Amarelo sinal #FFC52E · Tinta #0F1226 · Papel #F4F5FA
/// Títulos: Archivo ExtraBold · Textos: Instrument Sans
class AppColors {
  // Marca
  static const cobalt = Color(0xFF2A3CF0);
  static const cobaltLight = Color(0xFF8F99FF); // cobalto legível sobre fundo escuro
  static const signal = Color(0xFFFFC52E); // amarelo sinal (ação principal)
  static const ink = Color(0xFF0F1226);
  static const paper = Color(0xFFF4F5FA);

  // Tema escuro derivado da Tinta
  static const background = ink;
  static const surface = Color(0xFF161A33);
  static const surfaceHigh = Color(0xFF1E2340);
  static const outline = Color(0xFF2C3252);
  static const text = Color(0xFFE8EAF4);
  static const textMuted = Color(0xFF9AA0BC);

  // Estados
  static const success = Color(0xFF3A9A5B);
  static const danger = Color(0xFFE5484D); // horda / erro
  static const warning = Color(0xFFFF8A3D);

  static const gold = Color(0xFFFFC52E);
  static const silver = Color(0xFFCFD8DC);
  static const bronze = Color(0xFFD7A26B);

  static Color intensity(String intensity) => switch (intensity) {
        'alta' => danger,
        'media' => warning,
        _ => signal,
      };
}

class AppText {
  static TextStyle display({double size = 28, Color? color, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.archivo(fontSize: size, fontWeight: weight, letterSpacing: 0.5, color: color, height: 1.05);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.signal,
        onPrimary: AppColors.ink,
        secondary: AppColors.cobaltLight,
        onSecondary: AppColors.ink,
        tertiary: AppColors.cobalt,
        error: AppColors.danger,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        surfaceContainerHighest: AppColors.surfaceHigh,
        outline: AppColors.outline,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    final body = GoogleFonts.instrumentSansTextTheme(base.textTheme);
    TextStyle? d(TextStyle? s, {FontWeight w = FontWeight.w800}) =>
        s == null ? null : GoogleFonts.archivo(textStyle: s, fontWeight: w);

    return base.copyWith(
      textTheme: body
          .copyWith(
            displayLarge: d(body.displayLarge),
            displayMedium: d(body.displayMedium),
            displaySmall: d(body.displaySmall),
            headlineLarge: d(body.headlineLarge),
            headlineMedium: d(body.headlineMedium),
            headlineSmall: d(body.headlineSmall),
            titleLarge: d(body.titleLarge, w: FontWeight.w700),
          )
          .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.archivo(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.signal, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.archivo(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.cobalt.withValues(alpha: 0.55),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.instrumentSans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.signal,
        foregroundColor: AppColors.ink,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceHigh,
        selectedColor: AppColors.cobalt.withValues(alpha: 0.6),
        side: const BorderSide(color: AppColors.outline),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.outline),
    );
  }
}
