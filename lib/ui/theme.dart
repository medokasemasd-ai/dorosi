import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF14213D);
  static const muted = Color(0xFF5B6478);
  static const ground = Color(0xFFF3F5F9);
  static const card = Colors.white;
  static const line = Color(0xFFE3E7EF);
  static const soft = Color(0xFFEEF1F6);
  static const primary = Color(0xFF1E40AF);
  static const primarySoft = Color(0xFFE6ECFB);
  static const navy = Color(0xFF14213D);
  static const navyText = Color(0xFFC9D3E8);

  static const paid = Color(0xFF166534);
  static const paidSoft = Color(0xFFDCFCE7);
  static const unpaid = Color(0xFF9A3412);
  static const unpaidSoft = Color(0xFFFFEDD5);
  static const partial = Color(0xFF854D0E);
  static const partialSoft = Color(0xFFFEF3C7);
  static const review = Color(0xFF6D28D9);
  static const reviewSoft = Color(0xFFEDE9FE);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.ground,
    onSurface: AppColors.ink,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Plex');
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.ground,
    appBarTheme: const AppBarTheme(
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
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
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
        side: const BorderSide(color: AppColors.line),
        textStyle: const TextStyle(fontFamily: 'Plex', fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: const BorderSide(color: AppColors.line),
      labelStyle: const TextStyle(fontFamily: 'Plex', fontSize: 13, color: AppColors.ink),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primarySoft,
      surfaceTintColor: Colors.white,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: 'Plex',
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted,
          )),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.soft, thickness: 1, space: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
