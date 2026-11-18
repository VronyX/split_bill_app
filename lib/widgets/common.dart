import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Indikator langkah di bawah judul: Struk · Teman · Bagi · Hasil.
class StepIndicator extends StatelessWidget implements PreferredSizeWidget {
  final int current; // 0..3
  const StepIndicator({super.key, required this.current});

  static const _labels = ['Struk', 'Teman', 'Bagi', 'Hasil'];

  @override
  Size get preferredSize => const Size.fromHeight(34);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final done = i < current;
          final active = i == current;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == _labels.length - 1 ? 0 : 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 4,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.accent
                          : done
                              ? AppColors.accent.withValues(alpha: 0.4)
                              : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Lingkaran inisial nama dengan warna khas orang tersebut.
class PersonAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  const PersonAvatar({super.key, required this.name, required this.color, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.42),
      ),
    );
  }
}

/// Bar tombol utama yang menempel di bawah layar.
class BottomActionBar extends StatelessWidget {
  final Widget child;
  final Widget? top;
  const BottomActionBar({super.key, required this.child, this.top});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (top != null) ...[top!, const SizedBox(height: 12)],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotak info/peringatan kecil.
class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool warning;
  const InfoBanner({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.warning = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = warning ? AppColors.warningSoft : AppColors.successSoft;
    final fg = warning ? AppColors.warningInk : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: fg, fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }
}

/// Baris label – nilai untuk rincian biaya.
class AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const AmountRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: AppColors.ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: bold ? style : style.copyWith(color: AppColors.muted))),
          Text(value, style: style.copyWith(color: valueColor ?? AppColors.ink)),
        ],
      ),
    );
  }
}

/// Tombol − angka + untuk jumlah/porsi.
class QtyStepper extends StatelessWidget {
  final int value;
  final int min;
  final ValueChanged<int> onChanged;
  const QtyStepper({super.key, required this.value, required this.onChanged, this.min = 0});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tip, VoidCallback? onTap) => IconButton(
          onPressed: onTap,
          tooltip: tip,
          icon: Icon(icon, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.accentSoft,
            foregroundColor: AppColors.accent,
            disabledBackgroundColor: AppColors.fill,
            disabledForegroundColor: AppColors.muted,
            minimumSize: const Size(36, 36),
            fixedSize: const Size(36, 36),
            padding: EdgeInsets.zero,
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.remove, 'Kurangi', value > min ? () => onChanged(value - 1) : null),
        SizedBox(
          width: 34,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        btn(Icons.add, 'Tambah', () => onChanged(value + 1)),
      ],
    );
  }
}
