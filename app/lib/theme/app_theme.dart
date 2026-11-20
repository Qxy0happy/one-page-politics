import 'package:material_ui/material_ui.dart';

class AppColors {
  const AppColors._();

  static const lightBackground = Color(0xFFF7F5F0);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF1E1E1E);
  static const lightMuted = Color(0xFF6B7280);

  static const darkBackground = Color(0xFF0D0D0D);
  static const darkCard = Color(0xFF18181B);
  static const darkText = Color(0xFFE6E6E6);
  static const darkMuted = Color(0xFF9CA3AF);

  static const amber = Color(0xFFD97706);
  static const amberSoft = Color(0xFFFEF3C7);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0xFFFEE2E2);
  static const green = Color(0xFF16A34A);
  static const greenSoft = Color(0xFFDCFCE7);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFDBEAFE);

  static Color card(Brightness brightness) =>
      brightness == Brightness.dark ? darkCard : lightCard;

  static Color background(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : lightBackground;

  static Color text(Brightness brightness) =>
      brightness == Brightness.dark ? darkText : lightText;

  static Color muted(Brightness brightness) =>
      brightness == Brightness.dark ? darkMuted : lightMuted;
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final background = AppColors.background(brightness);
  final card = AppColors.card(brightness);
  final text = AppColors.text(brightness);
  final muted = AppColors.muted(brightness);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.amber,
        brightness: brightness,
      ).copyWith(
        surface: background,
        onSurface: text,
        primary: AppColors.amber,
        onPrimary: Colors.white,
        secondary: AppColors.blue,
        error: AppColors.red,
        surfaceContainerHighest: card,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    cardColor: card,
    dividerColor: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E1D8),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      indicatorColor: AppColors.amber.withValues(alpha: isDark ? 0.28 : 0.18),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: muted),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: card,
      selectedColor: AppColors.amber.withValues(alpha: isDark ? 0.32 : 0.18),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      labelStyle: TextStyle(fontSize: 13, color: text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    textTheme: TextTheme(
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: text,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: text),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: text),
      bodySmall: TextStyle(fontSize: 12, height: 1.45, color: muted),
      labelMedium: TextStyle(fontSize: 12, color: muted),
    ),
  );
}
