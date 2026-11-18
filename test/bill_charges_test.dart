import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/models/bill_charges.dart';

void main() {
  test('struk Bumi Aki: service 7%, pajak 10% dari subtotal + service', () {
    const charges = BillCharges(pajakPersen: 10, servicePersen: 7, pajakDenganService: true);
    final r = charges.hitung(236835, subtotalSemua: 236835);
    expect(r.service.round(), 16578);
    expect(r.pajak.round(), 25341);
    expect(r.total.round(), 278755);
  });

  test('diskon & biaya dibagi proporsional per orang', () {
    const charges = BillCharges(pajakPersen: 10, servicePersen: 5, diskonTotal: 10000);
    final a = charges.hitung(60000, subtotalSemua: 100000);
    final b = charges.hitung(40000, subtotalSemua: 100000);
    final semua = charges.hitung(100000, subtotalSemua: 100000);
    expect(a.diskon, 6000);
    expect(b.diskon, 4000);
    expect(a.total + b.total, closeTo(semua.total, 0.001));
  });

  test('format rupiah', () {
    expect(formatRupiah(278755), 'Rp 278.755');
    expect(formatRupiah(500), 'Rp 500');
    expect(formatRupiah(-1200), '-Rp 1.200');
  });
}
