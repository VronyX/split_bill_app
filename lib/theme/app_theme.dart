import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Token warna aplikasi. Netral & bersih, satu warna aksen.
class AppColors {
  static const background = Color(0xFFF6F5F2); // latar halaman
  static const surface = Color(0xFFFFFFFF); // kartu
  static const fill = Color(0xFFF0EEE9); // isian / chip tidak aktif
  static const border = Color(0xFFE6E2DA);
  static const ink = Color(0xFF1F1D1A); // teks utama
  static const muted = Color(0xFF77716A); // teks sekunder
  static const accent = Color(0xFFD9480F); // tombol & highlight
  static const accentSoft = Color(0xFFFCE9DF);
  static const success = Color(0xFF2F7D57);
  static const successSoft = Color(0xFFE3F2EA);
  static const danger = Color(0xFFC0392B);
  static const warningSoft = Color(0xFFFFF4DB);
  static const warningInk = Color(0xFF7A5300);

  // Nama lama, dipertahankan supaya kode lain tetap jalan.
  static const stamp = accent;
  static const paper = surface;
  static const paperDark = fill;
  static const money = success;

  /// Warna khas tiap orang (dipakai konsisten di semua layar).
  static const people = [
    Color(0xFFD9480F),
    Color(0xFF2F7D57),
    Color(0xFF2F6DB5),
    Color(0xFF8E44AD),
    Color(0xFFB7791F),
    Color(0xFF0E8C8C),
    Color(0xFFC2185B),
    Color(0xFF5D6D7E),
  ];

  static Color person(int index) => people[index % people.length];
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      surface: AppColors.surface,
    );
    final radius = BorderRadius.circular(14);
    // Pakai tipografi bawaan platform (Roboto di Android, SF di iOS) supaya
    // gaya teks custom di bawah tetap memakai font yang benar.
    final typo = Typography.material2021(platform: defaultTargetPlatform).black;
    TextStyle base(TextStyle? s) => (s ?? const TextStyle()).copyWith(color: null);
    final label = base(typo.labelLarge);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base(typo.titleLarge).copyWith(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.4),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
        bodyLarge: TextStyle(color: AppColors.ink),
        bodyMedium: TextStyle(color: AppColors.ink),
        bodySmall: TextStyle(color: AppColors.muted),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: label.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: label.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.border),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: label.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: label.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.accent : null),
      ),
    );
  }
}
