import 'bill_charges.dart';
import 'receipt_item.dart';

/// Pembagian item: itemId -> (nama orang -> jumlah porsi).
///
/// Biaya item dibagi sebanding porsinya. Contoh: "Es Teh x3" dengan
/// Andi 1 porsi & Budi 2 porsi -> Andi bayar 1/3, Budi 2/3. Satu item
/// dengan 2 orang masing-masing 1 porsi = patungan rata.
typedef Portions = Map<int, Map<String, int>>;

class PersonLine {
  final String itemName;
  final int portions;
  final int totalPortions;
  final int sharedWith; // jumlah orang di item ini
  final double amount;

  const PersonLine({
    required this.itemName,
    required this.portions,
    required this.totalPortions,
    required this.sharedWith,
    required this.amount,
  });

  String get keterangan {
    if (sharedWith <= 1) return totalPortions > 1 ? '$portions porsi' : '';
    if (portions * sharedWith == totalPortions) return 'dibagi $sharedWith';
    return '$portions dari $totalPortions porsi';
  }
}

class PersonShare {
  final String name;
  final int index;
  final List<PersonLine> lines;
  final ChargeBreakdown rincian;

  /// Total yang harus dibayar, sudah dibulatkan ke rupiah sehingga jumlah
  /// semua orang sama persis dengan total tagihan (tidak selisih Rp1).
  final int total;

  const PersonShare({
    required this.name,
    required this.index,
    required this.lines,
    required this.rincian,
    required this.total,
  });
}

class SplitSummary {
  final List<PersonShare> people;
  final ChargeBreakdown tagihan;
  final List<ReceiptItem> unassigned;

  const SplitSummary({required this.people, required this.tagihan, required this.unassigned});
}

SplitSummary hitungPembagian({
  required List<ReceiptItem> items,
  required List<String> people,
  required Portions portions,
  required BillCharges charges,
}) {
  final subtotalSemua = items.fold<int>(0, (s, it) => s + it.total).toDouble();
  final lines = {for (final p in people) p: <PersonLine>[]};
  final unassigned = <ReceiptItem>[];

  for (final item in items) {
    final map = portions[item.id] ?? const {};
    final active = map.entries.where((e) => e.value > 0 && lines.containsKey(e.key)).toList();
    final total = active.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) {
      unassigned.add(item);
      continue;
    }
    for (final e in active) {
      lines[e.key]!.add(PersonLine(
        itemName: item.qty > 1 ? '${item.nama} x${item.qty}' : item.nama,
        portions: e.value,
        totalPortions: total,
        sharedWith: active.length,
        amount: item.total * e.value / total,
      ));
    }
  }

  final rincian = [
    for (final name in people)
      charges.hitung(lines[name]!.fold<double>(0, (s, l) => s + l.amount), subtotalSemua: subtotalSemua),
  ];
  final bulat = _bulatkanTotal(rincian.map((r) => r.total).toList());

  final shares = <PersonShare>[
    for (var i = 0; i < people.length; i++)
      PersonShare(name: people[i], index: i, lines: lines[people[i]]!, rincian: rincian[i], total: bulat[i]),
  ];

  return SplitSummary(
    people: shares,
    tagihan: charges.hitung(subtotalSemua, subtotalSemua: subtotalSemua),
    unassigned: unassigned,
  );
}

/// Pembulatan "sisa terbesar": tiap angka dibulatkan ke bawah, lalu sisa
/// rupiahnya diberikan ke yang pecahannya paling besar.
List<int> _bulatkanTotal(List<double> values) {
  final target = values.fold<double>(0, (s, v) => s + v).round();
  final floors = values.map((v) => v.floor()).toList();
  var sisa = target - floors.fold<int>(0, (s, v) => s + v);
  final order = List.generate(values.length, (i) => i)
    ..sort((a, b) => (values[b] - floors[b]).compareTo(values[a] - floors[a]));
  for (final i in order) {
    if (sisa <= 0) break;
    floors[i]++;
    sisa--;
  }
  return floors;
}

/// Teks ringkasan untuk ditempel ke chat (WhatsApp, dll).
String ringkasanTeks(SplitSummary s, {String? judul}) {
  final b = StringBuffer();
  b.writeln('*${judul ?? 'Split Bill'}*');
  b.writeln('Total tagihan: ${formatRupiah(s.tagihan.total)}');
  b.writeln();
  for (final p in s.people) {
    b.writeln('*${p.name}: ${formatRupiah(p.total)}*');
    for (final l in p.lines) {
      final ket = l.keterangan.isEmpty ? '' : ' (${l.keterangan})';
      b.writeln('• ${l.itemName}$ket ${formatRupiah(l.amount)}');
    }
    final extra = <String>[
      if (p.rincian.diskon > 0) 'diskon -${formatRupiah(p.rincian.diskon)}',
      if (p.rincian.service > 0) 'service ${formatRupiah(p.rincian.service)}',
      if (p.rincian.pajak > 0) 'pajak ${formatRupiah(p.rincian.pajak)}',
    ];
    if (extra.isNotEmpty) b.writeln('  ${extra.join(', ')}');
    b.writeln();
  }
  return b.toString().trimRight();
}
