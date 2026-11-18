import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/models/bill_charges.dart';
import 'package:split_bill_app/models/receipt_item.dart';
import 'package:split_bill_app/models/split.dart';

void main() {
  final items = [
    ReceiptItem(id: 1, nama: 'Mie Goreng', qty: 1, harga: 46157),
    ReceiptItem(id: 2, nama: 'Nasi Goreng', qty: 1, harga: 54964),
    ReceiptItem(id: 3, nama: 'Es Teh', qty: 3, harga: 5000),
  ];
  const people = ['Andi', 'Budi', 'Citra'];
  const charges = BillCharges(pajakPersen: 10, servicePersen: 7, pajakDenganService: true);

  test('jumlah per orang sama persis dengan total tagihan', () {
    final s = hitungPembagian(items: items, people: people, charges: charges, portions: {
      1: {'Andi': 1},
      2: {'Budi': 1, 'Citra': 1},
      3: {'Andi': 1, 'Budi': 1, 'Citra': 1},
    });
    final sum = s.people.fold<int>(0, (a, p) => a + p.total);
    expect(sum, s.tagihan.total.round());
    expect(s.unassigned, isEmpty);
  });

  test('porsi tidak rata dibagi sesuai perbandingan', () {
    final s = hitungPembagian(items: items, people: people, charges: const BillCharges(), portions: {
      3: {'Andi': 1, 'Budi': 2},
    });
    expect(s.people[0].lines.single.amount, 5000);
    expect(s.people[1].lines.single.amount, 10000);
    expect(s.people[1].lines.single.keterangan, '2 dari 3 porsi');
    expect(s.unassigned.map((e) => e.id), [1, 2]);
  });

  test('teks ringkasan untuk chat', () {
    final s = hitungPembagian(items: items, people: people, charges: const BillCharges(), portions: {
      1: {'Andi': 1},
      2: {'Budi': 1, 'Citra': 1},
      3: {'Andi': 1, 'Budi': 1, 'Citra': 1},
    });
    final teks = ringkasanTeks(s);
    expect(teks, contains('Total tagihan: Rp 116.121'));
    expect(teks, contains('*Andi: Rp 51.157*'));
    expect(teks, contains('• Nasi Goreng (dibagi 2) Rp 27.482'));
  });
}
