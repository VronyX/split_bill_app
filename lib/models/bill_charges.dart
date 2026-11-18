import 'dart:math' as math;

/// Biaya tambahan tagihan: diskon, service, dan pajak.
///
/// Urutan hitung mengikuti struk restoran Indonesia pada umumnya:
///   subtotal - diskon -> + service (persen) -> + pajak (persen), dengan
///   pajak (PB1/PPN) boleh dihitung dari subtotal + service.
class BillCharges {
  final double pajakPersen;
  final double servicePersen;
  final bool pajakDenganService;
  final int diskonTotal;

  const BillCharges({
    this.pajakPersen = 0,
    this.servicePersen = 0,
    this.pajakDenganService = true,
    this.diskonTotal = 0,
  });

  /// Rincian biaya untuk [subtotal] tertentu. [subtotalSemua] = subtotal
  /// seluruh tagihan, dipakai untuk membagi diskon secara proporsional.
  ChargeBreakdown hitung(double subtotal, {required double subtotalSemua}) {
    final diskonTagihan = math.min(math.max(diskonTotal, 0).toDouble(), subtotalSemua);
    final diskon = subtotalSemua <= 0 ? 0.0 : diskonTagihan * subtotal / subtotalSemua;
    final dasar = subtotal - diskon;
    final service = dasar * servicePersen / 100;
    final pajak = (dasar + (pajakDenganService ? service : 0)) * pajakPersen / 100;
    return ChargeBreakdown(subtotal: subtotal, diskon: diskon, service: service, pajak: pajak);
  }
}

class ChargeBreakdown {
  final double subtotal;
  final double diskon;
  final double service;
  final double pajak;

  const ChargeBreakdown({
    required this.subtotal,
    required this.diskon,
    required this.service,
    required this.pajak,
  });

  double get total => subtotal - diskon + service + pajak;
}

/// Format rupiah dengan pemisah ribuan: 278755 -> "Rp 278.755".
String formatRupiah(num value) {
  final n = value.round();
  final digits = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${n < 0 ? '-' : ''}Rp ${buf.toString()}';
}
