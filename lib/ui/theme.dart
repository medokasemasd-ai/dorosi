import 'package:flutter/material.dart';

/// The accent colours the user can pick: name and colour.
const accents = [
  ('أزرق', Color(0xFF1E40AF)),
  ('أخضر', Color(0xFF047857)),
  ('بنفسجي', Color(0xFF6D28D9)),
  ('وردي', Color(0xFFBE185D)),
  ('برتقالي', Color(0xFFC2410C)),
  ('تركواز', Color(0xFF0E7490)),
];

/// The app's colours. They change with the chosen accent and light or dark
/// mode, so [apply] runs before the app is built.
class AppColors {
  static Color ink = const Color(0xFF14213D);
  static Color muted = const Color(0xFF5B6478);
  static Color ground = const Color(0xFFF3F5F9);
  static Color card = Colors.white;
  static Color line = const Color(0xFFE3E7EF);
  static Color soft = const Color(0xFFEEF1F6);
  static Color primary = const Color(0xFF1E40AF);
  static Color primarySoft = const Color(0xFFE6ECFB);
  static Color onPrimary = Colors.white;
  static Color onPrimarySoft = const Color(0xFF1E3A8A);
  static Color navy = const Color(0xFF14213D);
  static Color navyText = const Color(0xFFC9D3E8);

  static Color paid = const Color(0xFF166534);
  static Color paidSoft = const Color(0xFFDCFCE7);
  static Color unpaid = const Color(0xFF9A3412);
  static Color unpaidSoft = const Color(0xFFFFEDD5);
  static Color partial = const Color(0xFF854D0E);
  static Color partialSoft = const Color(0xFFFEF3C7);
  static Color review = const Color(0xFF6D28D9);
  static Color reviewSoft = const Color(0xFFEDE9FE);

  static bool dark = false;

  static void apply({required int accent, required bool dark}) {
    final a = accents[accent.clamp(0, accents.length - 1)].$2;
    AppColors.dark = dark;
    if (!dark) {
      ink = const Color(0xFF14213D);
      muted = const Color(0xFF5B6478);
      ground = Color.lerp(const Color(0xFFF3F5F9), a, 0.03)!;
      card = Colors.white;
      line = const Color(0xFFE3E7EF);
      soft = const Color(0xFFEEF1F6);
      primary = a;
      primarySoft = Color.lerp(Colors.white, a, 0.12)!;
      onPrimarySoft = Color.lerp(a, Colors.black, 0.2)!;
      onPrimary = Colors.white;
      navy = Color.lerp(const Color(0xFF14213D), a, 0.25)!;
      navyText = const Color(0xFFC9D3E8);
      paid = const Color(0xFF166534);
      paidSoft = const Color(0xFFDCFCE7);
      unpaid = const Color(0xFF9A3412);
      unpaidSoft = const Color(0xFFFFEDD5);
      partial = const Color(0xFF854D0E);
      partialSoft = const Color(0xFFFEF3C7);
      review = const Color(0xFF6D28D9);
      reviewSoft = const Color(0xFFEDE9FE);
    } else {
      final light = Color.lerp(a, Colors.white, 0.45)!;
      ink = const Color(0xFFE8ECF4);
      muted = const Color(0xFF9AA4B8);
      ground = const Color(0xFF0E131D);
      card = const Color(0xFF181F2C);
      line = const Color(0xFF2B3446);
      soft = const Color(0xFF222A39);
      primary = light;
      primarySoft = Color.lerp(const Color(0xFF181F2C), a, 0.35)!;
      onPrimarySoft = Color.lerp(a, Colors.white, 0.7)!;
      onPrimary = const Color(0xFF0E131D);
      navy = Color.lerp(const Color(0xFF1B2333), a, 0.35)!;
      navyText = const Color(0xFFC9D3E8);
      paid = const Color(0xFF6EE7A0);
      paidSoft = const Color(0xFF173A28);
      unpaid = const Color(0xFFFDBA8C);
      unpaidSoft = const Color(0xFF45261A);
      partial = const Color(0xFFFCD679);
      partialSoft = const Color(0xFF3F3315);
      review = const Color(0xFFC4B5FD);
      reviewSoft = const Color(0xFF2E2350);
    }
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: AppColors.dark ? Brightness.dark : Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    surface: AppColors.card,
    onSurface: AppColors.ink,
    surfaceContainerHighest: AppColors.soft,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Plex');
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.ground,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Plex', fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
    ),
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'Plex', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: AppColors.line),
        textStyle: const TextStyle(fontFamily: 'Plex', fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(color: AppColors.line),
      labelStyle: TextStyle(fontFamily: 'Plex', fontSize: 13, color: AppColors.ink),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.primarySoft,
      surfaceTintColor: AppColors.card,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: 'Plex',
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: AppColors.card),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: AppColors.card),
    popupMenuTheme: PopupMenuThemeData(color: AppColors.card),
    dividerTheme: DividerThemeData(color: AppColors.soft, thickness: 1, space: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
