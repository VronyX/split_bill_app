import 'package:flutter/material.dart';

// Kumpulan warna & style terpusat, sesuai tema "kertas struk" dari prototype.
class AppColors {
  static const paper = Color(0xFFFAF6EC);
  static const paperDark = Color(0xFFF3EEE0);
  static const background = Color(0xFFEDE7D9);
  static const ink = Color(0xFF2B2621);
  static const stamp = Color(0xFFC1440E); // warna aksen utama (tombol, highlight)
  static const money = Color(0xFF4B7B5B); // warna untuk angka uang/positif
  static const muted = Color(0xFF8C8370);
  static const border = Color(0xFFD9D2BE);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.stamp,
        primary: AppColors.stamp,
        surface: AppColors.paper,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.ink),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.stamp,
          foregroundColor: AppColors.paper,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}