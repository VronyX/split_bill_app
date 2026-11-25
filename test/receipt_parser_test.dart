import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/services/receipt_parser_core.dart';

List<String> _rows(String s) =>
    s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

Map<String, List<int>> _summary(ReceiptParseResult r) =>
    {for (final it in r.items) it.nama: [it.qty, it.harga]};

void main() {
  group('format angka', () {
    test('berbagai penulisan rupiah', () {
      final r = parseReceiptRows(_rows('''
        Kopi Susu 25.000
        Teh Tarik 18,000
        Roti Bakar Rp 22.000,00
        Mie Goreng Rp. 30,000.00
        Es Jeruk 15.000,-
        Air Mineral 8K
        Pisang Goreng 1O.5OO
      '''));
      expect(_summary(r), {
        'Kopi Susu': [1, 25000],
        'Teh Tarik': [1, 18000],
        'Roti Bakar': [1, 22000],
        'Mie Goreng': [1, 30000],
        'Es Jeruk': [1, 15000],
        'Air Mineral': [1, 8000],
        'Pisang Goreng': [1, 10500],
      });
    });
  });

  group('minimarket', () {
    test('Indomaret: nama qty harga total, PPN termasuk', () {
      final r = parseReceiptRows(_rows('''
        INDOMARET
        PT. INDOMARCO PRISMATAMA
        JL. RAYA BOGOR KM 30
        NPWP : 01.337.994.6-092.000
        14.11.26-19:20 2.0.33 ABC123/BUDI/01
        INDOMIE GRG 2 3,100 6,200
        AQUA 600ML 1 3,500 3,500
        TEH PUCUK 350 3 4,000 12,000
        PLASTIK BSR 1 200 200
        HARGA JUAL : 21,900
        TOTAL : 21,900
        TUNAI : 50,000
        KEMBALI : 28,100
        PPN : 2,170 DPP : 19,730
        LAYANAN KONSUMEN SMS/WA 0811 1500 280
      '''));
      expect(_summary(r), {
        'INDOMIE GRG': [2, 3100],
        'AQUA 600ML': [1, 3500],
        'TEH PUCUK 350': [3, 4000],
        'PLASTIK BSR': [1, 200],
      });
      expect(r.subtotalStruk, 21900);
      expect(r.totalStruk, 21900);
      expect(r.pajakTermasuk, isTrue);
      expect(r.pajakPersenSaran, 0);
      expect(r.servicePersenSaran, 0);
    });

    test('Alfamart: diskon per item', () {
      final r = parseReceiptRows(_rows('''
        ALFAMART
        Jl. Sudirman No. 5
        Bon 1A2B-3C4D Kasir : SITI
        SUSU ULTRA 1L 2 18.500 37.000
        Disc. Promo -3.000
        SARI ROTI TAWAR 1 15.000 15.000
        Total Item 3
        Total Belanja 49.000
        Total Disc. 3.000
        Tunai 100.000
        Kembalian 51.000
        Anda Hemat 3.000
      '''));
      expect(_summary(r), {
        'SUSU ULTRA 1L': [2, 17000],
        'SARI ROTI TAWAR': [1, 15000],
      });
      expect(r.diskonTotal, 0);
      expect(r.totalStruk, 49000);
      expect(r.itemsTotal, 49000);
    });
  });

  group('restoran / kafe', () {
    test('qty di depan, service + PB1', () {
      final r = parseReceiptRows(_rows('''
        WARUNG MAKAN SEDERHANA
        Jl. Melati No. 12, Jakarta Selatan
        Telp. (021) 7654321
        Meja : 7          Pax : 3
        Kasir : Andi
        14/11/2026 19:45
        --------------------------------
        1 Nasi Goreng Spesial 35.000
        2 Es Teh Manis 16.000
        1x Ayam Bakar 40.000
        --------------------------------
        Subtotal 91.000
        Service 5% 4.550
        PB1 10% 9.555
        Total 105.105
        Tunai 110.000
        Kembali 4.895
        Terima kasih atas kunjungan Anda
      '''));
      expect(_summary(r), {
        'Nasi Goreng Spesial': [1, 35000],
        'Es Teh Manis': [2, 8000],
        'Ayam Bakar': [1, 40000],
      });
      expect(r.subtotalStruk, 91000);
      expect(r.servicePersenSaran, 5);
      expect(r.pajakNominal, 9555);
      expect(r.pajakTermasuk, isFalse);
      // PB1 10% dihitung dari subtotal + service: (91.000 + 4.550) * 10%.
      expect(r.pajakPersenSaran, 10);
      expect(r.pajakDenganService, isTrue);
      expect(r.totalStruk, 105105);
    });

    test('POS (Moka/Majoo): nama lalu baris qty x harga, modifier', () {
      final r = parseReceiptRows(_rows('''
        KOPI KENANGAN SENJA
        Order #A-1023
        Dine In
        Kopi Susu Gula Aren
        2 x 22.000 44.000
          - Less Sugar
          + Extra Shot 6.000
        Croissant Butter
        1 x 28.000 28.000
        Matcha Latte
        @30.000 x 1 30.000
        Sub Total 108.000
        Discount 10% -10.800
        Tax 10% 9.720
        Grand Total 106.920
        QRIS 106.920
      '''));
      expect(_summary(r), {
        'Kopi Susu Gula Aren + Extra Shot': [2, 25000],
        'Croissant Butter': [1, 28000],
        'Matcha Latte': [1, 30000],
      });
      expect(r.diskonTotal, 10800);
      expect(r.pajakPersenSaran, 10);
      expect(r.totalStruk, 106920);
    });

    test('qty di belakang nama & harga satuan + total', () {
      final r = parseReceiptRows(_rows('''
        Bakso Urat x2 50.000
        Es Campur 2 x 15.000 30.000
        Kerupuk 3 2.000 6.000
        Mie Ayam 18.000 36.000
        Jus Alpukat @ 20.000 40.000
      '''));
      expect(_summary(r), {
        'Bakso Urat': [2, 25000],
        'Es Campur': [2, 15000],
        'Kerupuk': [3, 2000],
        'Mie Ayam': [2, 18000],
        'Jus Alpukat': [2, 20000],
      });
    });

    test('harga di baris terpisah dari nama + qty', () {
      final r = parseReceiptRows(_rows('''
        2 Sate Ayam
        60.000
        Lontong x1
        5.000
      '''));
      expect(_summary(r), {
        'Sate Ayam': [2, 30000],
        'Lontong': [1, 5000],
      });
    });
  });

  group('struk asli: Bumi Aki', () {
    String struk(String labelSubtotal) => '''
      Celebrate Happiness
      RM Bumi Aki Cisarua
      Jalan Raya Cisarua No.18 KM 81 Cisarua, Kec. Cis
      arua, Kabupaten Bogor, Jawa Barat 16750
      Date : 07-07-2026 11:47
      Time In : 07-07-2026 11:14
      Info : ka Budi// 081234567890// new
      Server : ISMAIL
      Table : T.6
      Purpose : Dine In
      Pax : 2
      Cashier : TINAH
      Mie Goreng Special
      1x @46.157 46.157
      Nasi Goreng Spesial
      1x @54.964 54.964
      Telur Mata Sapi
      1x @0 0
      Nasi Liwet
      1x @21.628 21.628
      Perkedel Jagung
      1x @29.480 29.480
      Tempe Mendoan
      1x @30.149 30.149
      Pisang Goreng Keju
      1x @40.911 40.911
      Es Teh Tawar
      1x @13.546 13.546
      7 items
      $labelSubtotal 236.835
      SC 7% : 16.578
      TAX : 25.341
      Grand Total : 278.755
      NOT PAID
    ''';

    // "Subtotal" di struk ini pudar, OCR bisa membacanya macam-macam.
    for (final label in ['Subtotal :', 'Subtc tal :', 'Subtctal :', 'Subt tal :', ':']) {
      test('label subtotal "$label"', () {
        final r = parseReceiptRows(_rows(struk(label)));
        expect(r.items.length, 7);
        expect(r.itemsTotal, 236835);
        expect(r.items.any((it) => it.nama.toLowerCase().contains('jawa')), isFalse);
        expect(r.subtotalStruk, 236835);
        expect(r.servicePersenSaran, 7);
        expect(r.pajakPersenSaran, 10);
        expect(r.pajakDenganService, isTrue);
        expect(r.totalStruk, 278755);
      });
    }
  });

  group('struk asli: restoran Jepang, PB1 sudah termasuk', () {
    test('Total Food/Beverage bukan item, PB1 inclusive', () {
      final r = parseReceiptRows(_rows('''
        Loyalty Member : Budi
        Purpose : DINE IN
        Cashier : M027 KASIR 1
        Beef Curry Udon
        1x @71.000 71.000
        Chicken Katsu
        2x @21.000 42.000
        Cold Ocha
        3x @17.000 51.000
        Chicken Katsu Curry Udon
        2x @66.000 132.000
        Ice Lemon Tea
        2x @17.000 34.000
        Total Food 245.000
        Total Beverage 85.000
        9 items
        Grand Total : 330.000
        BRI : 330.000
        Price inclusive of PB1 : 30.000
      '''));
      expect(_summary(r), {
        'Beef Curry Udon': [1, 71000],
        'Chicken Katsu': [2, 21000],
        'Cold Ocha': [3, 17000],
        'Chicken Katsu Curry Udon': [2, 66000],
        'Ice Lemon Tea': [2, 17000],
      });
      expect(r.totalStruk, 330000);
      expect(r.pajakTermasuk, isTrue);
      expect(r.pajakPersenSaran, 0);
      expect(r.servicePersenSaran, 0);
    });
  });

  group('header & diskon transaksi', () {
    test('jam buka tidak terbaca sebagai item, PB1 dalam kurung', () {
      final r = parseReceiptRows(_rows('''
        SOTO BETAWI H. MAMAT
        Pluit Village Lt. 3
        Open 10.00 - 22.00
        Bill No: 00123  Tbl: 12
        Soto Betawi Daging   2   45.000   90.000
        Nasi Putih   2   6.000   12.000
        Sub Total   102.000
        PB1 (10%)   10.200
        Pembulatan   200
        Total   112.400
      '''));
      expect(_summary(r), {
        'Soto Betawi Daging': [2, 45000],
        'Nasi Putih': [2, 6000],
      });
      expect(r.pajakPersenSaran, 10);
    });

    test('diskon member persen dihitung dari seluruh transaksi', () {
      final r = parseReceiptRows(_rows('''
        Rendang 1 x 25.000 25.000
        Ayam Pop 1 x 22.000 22.000
        Nasi 2 x 6.000 12.000
        Teh Telor 1 x 15.000 15.000
        Disc Member 5% 3.700
        Total 70.300
      '''));
      expect(r.itemsTotal, 74000);
      expect(r.diskonTotal, 3700);
      expect(r.totalStruk, 70300);
    });
  });

  group('pengelompokan baris OCR', () {
    test('kolom nama & harga terpisah + foto miring', () {
      const skew = 4 * math.pi / 180;
      OcrLine at(String t, double x, double y, double w) => OcrLine(
            text: t,
            centerX: x * math.cos(skew) - y * math.sin(skew),
            centerY: x * math.sin(skew) + y * math.cos(skew),
            width: w,
            height: 20,
            angle: skew,
          );
      final rows = groupLinesIntoRows([
        // ML Kit mengembalikan kolom kanan sebagai blok terpisah.
        at('Nasi Goreng', 80, 100, 120),
        at('Es Teh', 50, 130, 70),
        at('Total', 40, 170, 60),
        at('35.000', 400, 100, 70),
        at('8.000', 400, 130, 60),
        at('43.000', 400, 170, 70),
      ]);
      expect(rows, ['Nasi Goreng 35.000', 'Es Teh 8.000', 'Total 43.000']);
    });
  });
}
