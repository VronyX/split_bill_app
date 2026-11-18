// Parser struk murni (tanpa Flutter / ML Kit) supaya bisa dites di unit test.
//
// Dirancang untuk variasi template struk yang umum di Indonesia:
//  - Minimarket (Indomaret, Alfamart, dll):
//      "INDOMIE GRG 2 3,100 6,200"   (nama  qty  harga  total)
//      "HARGA JUAL : 6,200" / "TOTAL BELANJA" / "TUNAI" / "KEMBALI" / "PPN" / "DPP"
//  - Restoran / kafe dengan POS (Moka, Majoo, ESB, Pawoon, Qasir, dll):
//      "Nasi Goreng"            lalu baris "2 x 25.000   50.000"
//      "2 Nasi Goreng 50.000" / "2x Nasi Goreng 50.000" / "Nasi Goreng x2 50.000"
//      "Nasi Goreng @25.000 x 2 50.000" / "Es Teh 25K"
//      Modifier: "+ Extra Keju 5.000", "- Less Sugar"
//      Ringkasan: Subtotal, Diskon/Promo, Service (5%), PB1 / PBJT / PPN / Tax (10%), Total
//  - Format angka: 25.000 | 25,000 | 25.000,00 | 25,000.00 | Rp25.000 | 25.000,- | 25K | 25rb
//    Negatif: -5.000 | (5.000) | 5.000-

import 'dart:math' as math;

import '../models/receipt_item.dart';

/// Satu baris teks hasil OCR beserta geometrinya.
class OcrLine {
  final String text;
  final double centerX;
  final double centerY;
  final double width;
  final double height;

  /// Kemiringan baris dalam radian (0 = datar, positif = turun ke kanan).
  final double angle;

  const OcrLine({
    required this.text,
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
    this.angle = 0,
  });
}

class ReceiptParseResult {
  final List<ReceiptItem> items;

  /// Ada baris pajak/service di struk (dipertahankan untuk kompatibilitas).
  final bool adaBarisPajakTerpisah;

  /// Nilai-nilai ringkasan yang terbaca dari struk (null = tidak ditemukan).
  final int? subtotalStruk;
  final int? totalStruk;
  final int? pajakNominal;
  final double? pajakPersenTertulis;
  final int? serviceNominal;

  /// Diskon level-transaksi (bukan per item; diskon per item sudah
  /// langsung dipotong ke harga item).
  final int diskonTotal;

  /// Harga di struk sudah termasuk pajak (umum di minimarket: PPN/DPP).
  final bool pajakTermasuk;

  /// Saran persen pajak untuk diisi otomatis di layar review, dihitung
  /// supaya nominal pajak sama dengan yang tertera di struk.
  final double pajakPersenSaran;

  /// Saran persen service untuk layar review.
  final double servicePersenSaran;

  /// Pajak dihitung dari (subtotal + service), bukan subtotal saja. Umum di
  /// restoran: PB1 10% dikenakan setelah service charge.
  final bool pajakDenganService;

  /// Baris-baris hasil pengelompokan OCR (berguna untuk debug).
  final List<String> rows;

  ReceiptParseResult({
    required this.items,
    required this.adaBarisPajakTerpisah,
    this.subtotalStruk,
    this.totalStruk,
    this.pajakNominal,
    this.pajakPersenTertulis,
    this.serviceNominal,
    this.diskonTotal = 0,
    this.pajakTermasuk = false,
    this.pajakPersenSaran = 0,
    this.servicePersenSaran = 0,
    this.pajakDenganService = false,
    this.rows = const [],
  });

  int get itemsTotal => items.fold(0, (s, it) => s + it.total);
}

// ---------------------------------------------------------------------------
// 1. Pengelompokan baris OCR menjadi baris struk
// ---------------------------------------------------------------------------

/// Gabungkan potongan teks OCR yang berada di "baris" yang sama.
///
/// ML Kit sering memecah struk jadi kolom (nama di kiri, harga di kanan)
/// sebagai blok terpisah. Di sini kita kelompokkan lagi berdasarkan posisi
/// vertikal, setelah mengoreksi kemiringan foto.
List<String> groupLinesIntoRows(List<OcrLine> lines) {
  final valid = lines.where((l) => l.text.trim().isNotEmpty).toList();
  if (valid.isEmpty) return [];

  // Estimasi kemiringan foto: median sudut baris yang cukup panjang.
  final angles = valid
      .where((l) => l.width > l.height * 3)
      .map((l) => l.angle)
      .toList()
    ..sort();
  var skew = angles.isEmpty ? 0.0 : angles[angles.length ~/ 2];
  const maxSkew = 20 * math.pi / 180;
  if (skew.abs() > maxSkew) skew = 0;
  final cosS = math.cos(skew), sinS = math.sin(skew);

  final heights = valid.map((l) => l.height).toList()..sort();
  final medianHeight = math.max(heights[heights.length ~/ 2], 1.0);

  final projected = valid.map((l) {
    // Putar balik sebesar -skew supaya baris struk jadi horizontal.
    final x = l.centerX * cosS + l.centerY * sinS;
    final y = -l.centerX * sinS + l.centerY * cosS;
    return _ProjectedLine(l.text.trim(), x, y, l.width);
  }).toList()
    ..sort((a, b) => a.y.compareTo(b.y));

  final rows = <_Row>[];
  for (final line in projected) {
    _Row? target;
    // Cek beberapa baris terakhir (bukan cuma satu) karena urutan y bisa
    // sedikit acak antara kolom kiri dan kanan.
    for (var i = rows.length - 1; i >= 0 && i >= rows.length - 3; i--) {
      final row = rows[i];
      if ((line.y - row.meanY).abs() < medianHeight * 0.55 &&
          !row.overlapsHorizontally(line)) {
        target = row;
        break;
      }
    }
    if (target == null) {
      rows.add(_Row()..add(line));
    } else {
      target.add(line);
    }
  }

  rows.sort((a, b) => a.meanY.compareTo(b.meanY));
  return rows
      .map((r) {
        r.lines.sort((a, b) => a.x.compareTo(b.x));
        return r.lines.map((l) => l.text).join(' ').trim();
      })
      .where((t) => t.isNotEmpty)
      .toList();
}

class _ProjectedLine {
  final String text;
  final double x;
  final double y;
  final double width;
  _ProjectedLine(this.text, this.x, this.y, this.width);
}

class _Row {
  final lines = <_ProjectedLine>[];
  double _sumY = 0;
  double get meanY => _sumY / lines.length;

  void add(_ProjectedLine l) {
    lines.add(l);
    _sumY += l.y;
  }

  bool overlapsHorizontally(_ProjectedLine other) {
    for (final l in lines) {
      final overlap = math.min(l.x + l.width / 2, other.x + other.width / 2) -
          math.max(l.x - l.width / 2, other.x - other.width / 2);
      if (overlap > math.min(l.width, other.width) * 0.5) return true;
    }
    return false;
  }
}

// ---------------------------------------------------------------------------
// 2. Kata kunci
// ---------------------------------------------------------------------------

RegExp _re(String pattern) => RegExp(pattern, caseSensitive: false);

final _subtotalRe = _re(
    r'^(sub\s*-?\s*total|sub\s*ttl|harga\s*jual|jumlah(?!\s*(item|barang|qty|bayar|tagihan|pembayaran))|total\s*sebelum)\b');

final _totalRe = _re(
    r'^(grand\s*-?\s*total|g\.?\s*total|total(?!\s*(item|qty|jenis|disc|diskon|potongan|hemat|ppn|pajak|tax|service|barang|kuantitas|pcs))|jumlah\s*(bayar|tagihan)|tagihan|amount\s*due|net\s*total|balance\s*due|harus\s*dibayar|yang\s*harus\s*dibayar)\b');

final _grandRe = _re(r'^(grand|g\.?\s*total|net\s*total)');

final _taxRe = _re(
    r'(\bpb\s*-?\s*1\b|\bpbjt\b|\bppn\b|\bpajak\b|\btax\b|\bvat\b|\bpph\b|\bp\.?\s*b\.?\s*1\b|\bresto\s*tax\b)');

final _taxInclusiveRe = _re(
    r'(\bdpp\b|\bincl\w*|\binclusive\b|termasuk\s*(ppn|pajak|pb1|tax)|sudah\s*termasuk|\bnett?\s*price\b|harga\s*sudah)');

final _serviceRe = _re(
    r'(\bservice\b|\bservis\b|\bsvc\b|\bserv\.?\s*ch|\bs\.\s*c\.?\b|\bsc\b|biaya\s*layanan)');

final _dppRe = _re(r'\bdpp\b');
final _inlineTaxRe = _re(r'\b(ppn|pajak|tax|pb\s*1)\b[^\d]*([\d.,]+)');

final _discountRe = _re(
    r'(\bdisc\w*|\bdiskon\b|\bpotongan\b|\bpromo\w*|\bvoucher\b|\bhemat\b|\bcashback\b|\bpot\.|\bdiscount\b|\bmember\s*disc|\bpotong\b)');

final _globalDiscountRe = _re(r'(\bmember\b|\bbill\b|\btransaksi\b|\bvoucher\b|\bkupon\b|\bcoupon\b|\bsubtotal\b|\bspecial\s*day|\bhappy\s*hour)');

final _discountSummaryRe = _re(
    r'(total\s*(disc\w*|diskon|potongan|hemat)|anda\s*hemat|you\s*save|hemat\s*anda|total\s*promo)');

final _paymentRe = _re(
    r'(\btunai\b|\bcash\b|\bkembali\w*|\bchange\b|\bdebit\b|\bkredit\b|\bcredit\b|\bqris\b|\bgo-?pay\b|\bovo\b|\bdana\b|\bshopee\s*pay\b|\blink\s*aja\b|\bedc\b|\bkartu\b|\bcard\b|\bvisa\b|\bmaster\w*\b|\bflazz\b|\be-?money\b|\btransfer\b|\bbayar\b|\bdibayar\b|\bpayment\b|\bpaid\b|\bpembayaran\b|\bdeposit\b|\buang\b|\bpembulatan\b|\brounding\b|\bdonasi\b)');

final _noiseRe = _re(r'(\bnpwp\b|\btelp?\b\.?|\btlp\b|\bphone\b|\bhp\b\s*[:.]|\bfax\b|\bwa\b\s*[:.]|whatsapp|'
    r'www\.|https?:|\.com\b|\.co\.id\b|\.id\b|@[a-z][\w.]*\.[a-z]|instagram|\big\s*:|'
    r'\bkabupaten\b|\bkecamatan\b|\bkelurahan\b|\bprovinsi\b|\bdesa\b|\bdki\b|\bindonesia\b|\binfo\b\s*:|,.*\b\d{5}\s*$|'
    r'\b(jawa|sumatera|sumatra|kalimantan|sulawesi|papua|nusa\s*tenggara)\s+(barat|timur|tengah|utara|selatan)\b|'
    r'\bjl\b\.?|\bjln\b|\bjalan\b|\bkel\b\.|\bkec\b\.|\bkab\b\.|\bkota\b|\bprov\b|\bruko\b|\blantai\b|\blt\b\.|\bblok\b|\brt\b\s*\d|\brw\b\s*\d|\bkode\s*pos\b|'
    r'\bkasir\b|\bcashier\b|\bwaiter\b|\bwaitress\b|\bserver\b|\bpelayan\b|\boperator\b|\bshift\b|\bcs\b\s*:|\bcust\w*\b|\bpelanggan\b|\bnama\s*:|'
    r'\bmeja\b|\btable\b|\btbl\b|\bpax\b|\bguest\w*\b|\btamu\b|\bcovers?\b|'
    r'\btgl\b|\btanggal\b|\bdate\b|\bjam\b|\btime\b|\bwaktu\b|\bhari\b|'
    r'\bno\.?\s*(struk|nota|bill|meja|trx|transaksi|order|ref|invoice|faktur|antrian|kartu)|\bbill\s*(no|#)|\border\s*(no|#|id|type)|\breceipt\b|\binvoice\b|\bfaktur\b|\btrx\b|\bref\b\s*[:#.]|\bid\s*transaksi|\bantrian\b|\bqueue\b|#\s*\d{3,}|'
    r'\b(open|buka|tutup|close[ds]?)\b\s*:?\s*\d|\d{1,2}[.:]\d{2}\s*-\s*\d{1,2}[.:]\d{2}|terima\s*kasih|thank|selamat\s*datang|\bwelcome\b|kritik|saran|layanan\s*konsumen|\bcall\s*center|\bhubungi\b|\bpassword\b|\bwifi\b|\bwi-fi\b|barang\s*yang\s*sudah|tidak\s*dapat\s*(ditukar|dikembalikan)|\bfollow\b|\bscan\b|'
    r'\bdine\s*-?\s*in\b|\btake\s*-?\s*away\b|\btakeaway\b|\bdelivery\b|\bgo-?food\b|\bgrab\s*-?food\b|\bshopee\s*food\b|\bpick\s*up\b|\bbungkus\b|'
    r'\bpoin\b|\bpoint\w*\b|\bmember\b|\bstamp\b|'
    r'\btotal\s*(item|qty|jenis|barang|kuantitas|pcs)\b|\bjumlah\s*(item|barang|qty)\b|\bitems?\s*[:=]\s*\d|\bqty\s*[:=]\s*\d|^\d+\s*items?$|'
    r'\bnote\w*\b|\bcatatan\b|\bket\b\s*[:.]|\bketerangan\b|'
    r'\b(item|nama\s*barang|description|deskripsi|menu|produk)\b.*\b(qty|jml|harga|price|total|jumlah|amount)\b|'
    r'\bcopy\b|\bcetak\b|\bprinted\b|\breprint\b|\bduplicate\b|\bpos\s*\d|\bterminal\b|\bstation\b|\boutlet\b|\bcabang\b|\bstore\b\s*[:#])');

final _dateTimeRe = RegExp(
    r'(\b\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}\b|\b\d{4}[/\-.]\d{1,2}[/\-.]\d{1,2}\b|\b\d{1,2}:\d{2}(:\d{2})?\b|'
    r'\b\d{1,2}\s+(jan|feb|mar|apr|mei|may|jun|jul|agu|aug|sep|okt|oct|nov|des|dec)\w*\s+\d{2,4}\b)',
    caseSensitive: false);

final _separatorOnlyRe = RegExp(r'^[\s\-=_*#~.:|+]*$');
final _modifierRe = RegExp(r'^[+\-*>•·~]\s*[A-Za-z]');
final _percentRe = RegExp(r'(\d{1,2}(?:[.,]\d{1,2})?)\s*%');
final _lettersRe = RegExp(r'[A-Za-z]');

// ---------------------------------------------------------------------------
// 3. Normalisasi teks & angka
// ---------------------------------------------------------------------------

String normalizeRow(String raw) {
  var s = raw
      .replaceAll(RegExp(r'[‐-―−]'), '-')
      .replaceAll('×', 'x')
      .replaceAll('\t', ' ');

  // Hapus "Rp", "Rp.", "IDR" di depan angka.
  s = s.replaceAll(RegExp(r'\b(rp|idr)\s*\.?\s*:?\s*(?=[\d(\-])', caseSensitive: false), ' ');
  // Rp nempel tanpa spasi setelah angka, mis. "25.000Rp" (jarang).
  s = s.replaceAll(RegExp(r'(?<=\d)\s*(rp|idr)\b', caseSensitive: false), '');

  // Perbaiki salah baca OCR di token yang jelas-jelas angka: O->0, l/I->1, dll.
  s = s.split(RegExp(r'\s+')).map(_fixOcrDigits).join(' ');

  // Satukan angka yang terpotong spasi: "25. 000" / "25 .000" -> "25.000".
  s = s.replaceAllMapped(
      RegExp(r'(\d)\s*([.,])\s+(\d{3})(?!\d)'), (m) => '${m[1]}${m[2]}${m[3]}');
  s = s.replaceAllMapped(
      RegExp(r'(\d)\s+([.,])(\d{3})(?!\d)'), (m) => '${m[1]}${m[2]}${m[3]}');

  // Akhiran ",-" atau ".-" : "25.000,-" -> "25.000".
  s = s.replaceAllMapped(RegExp(r'(\d)[.,]-(?=\s|$)'), (m) => m[1]!);

  // Pisahkan penanda qty/harga satuan: "2x" "x2" "@25.000".
  s = s.replaceAllMapped(
      RegExp(r'(?<![A-Za-z\d])(\d{1,3})\s*[xX](?![A-Za-z])'), (m) => '${m[1]} x ');
  s = s.replaceAllMapped(
      RegExp(r'(?<![A-Za-z\d])[xX]\s*(\d)'), (m) => 'x ${m[1]}');
  s = s.replaceAll(RegExp(r'@\s*'), ' @');
  s = s.replaceAll('=', ' ');

  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

final _ocrDigitCandidate = RegExp(r'^[(\-]?[\dOoIl|SB]+(?:[.,][\dOoIl|SB]+)*[)\-]?$');

String _fixOcrDigits(String token) {
  if (!_ocrDigitCandidate.hasMatch(token)) return token;
  final digitCount = RegExp(r'\d').allMatches(token).length;
  if (digitCount == 0) return token;
  final hasSeparator = token.contains('.') || token.contains(',');
  if (!hasSeparator && token.length < 4) return token;
  final letterCount = token.replaceAll(RegExp(r'[^OoIl|SB]'), '').length;
  // Tanpa pemisah ribuan, minta mayoritas karakter sudah berupa digit
  // supaya kata seperti "BOSS" tidak ikut diubah.
  if (!hasSeparator && digitCount <= letterCount) return token;
  return token
      .replaceAll(RegExp(r'[Oo]'), '0')
      .replaceAll(RegExp(r'[Il|]'), '1')
      .replaceAll('S', '5')
      .replaceAll('B', '8');
}

/// Token angka yang sudah diparse.
class _Num {
  final int value;
  final bool negative;

  /// Punya pemisah ribuan / akhiran K / desimal -> hampir pasti nominal uang.
  final bool moneyLike;
  _Num(this.value, {this.negative = false, this.moneyLike = false});

  bool get qtyLike => !moneyLike && !negative && value > 0 && value <= 999;
}

final _amountRe = RegExp(
    r'^(-)?(\()?(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)(\))?(-)?$');
final _kRe = RegExp(r'^(\d+(?:[.,]\d{1,3})?)\s*(k|rb|ribu)$', caseSensitive: false);

_Num? _parseNum(String token) {
  final t = token.replaceAll(RegExp(r'^[:]+|[:]+$'), '');
  if (t.isEmpty) return null;

  final k = _kRe.firstMatch(t);
  if (k != null) {
    final v = double.tryParse(k[1]!.replaceAll(',', '.'));
    if (v == null) return null;
    return _Num((v * 1000).round(), moneyLike: true);
  }

  final m = _amountRe.firstMatch(t);
  if (m == null) return null;
  final parens = m[2] != null && m[4] != null;
  if ((m[2] != null) != (m[4] != null)) return null; // kurung tidak seimbang
  var body = m[3]!;
  // Pemisah ribuan (bukan sekadar desimal ".00") -> hampir pasti nominal.
  final moneyLike = RegExp(r'\d[.,]\d{3}').hasMatch(body);
  if (parens && !moneyLike) return null; // "(021)" dsb -> bukan nominal

  // Buang bagian desimal (",00" / ".00") kalau ada.
  final dec = RegExp(r'[.,]\d{1,2}$').firstMatch(body);
  if (dec != null) body = body.substring(0, dec.start);
  final value = int.tryParse(body.replaceAll(RegExp(r'[.,]'), ''));
  if (value == null) return null;
  final negative = m[1] != null || m[5] != null || parens;
  return _Num(value, negative: negative, moneyLike: moneyLike);
}

bool _isPlausibleMoney(_Num n) => n.moneyLike || n.value >= 1000;

// ---------------------------------------------------------------------------
// 4. Interpretasi baris item
// ---------------------------------------------------------------------------

class _Tok {
  final String raw;
  final _Num? num;
  final bool isX;
  final bool isAt;
  _Tok(this.raw, this.num, {this.isX = false, this.isAt = false});
  bool get isNumeric => num != null || isX || isAt;
}

class _ParsedRow {
  final String name;
  final int? qty;
  final int? total;
  _ParsedRow(this.name, this.qty, this.total);
  bool get hasName => _lettersRe.allMatches(name).length >= 2;
}

List<_Tok> _tokenize(String row) {
  final out = <_Tok>[];
  for (final raw in row.split(' ')) {
    if (raw.isEmpty) continue;
    final lower = raw.toLowerCase();
    if (lower == 'x') {
      out.add(_Tok(raw, null, isX: true));
    } else if (raw.startsWith('@')) {
      final n = raw.length > 1 ? _parseNum(raw.substring(1)) : null;
      out.add(_Tok('@', null, isAt: true));
      if (n != null) out.add(_Tok(raw.substring(1), n));
    } else if (raw == ':' || raw == '-' || raw == '|') {
      out.add(_Tok(raw, null)); // tanda baca, dibuang nanti
    } else {
      out.add(_Tok(raw, _parseNum(raw)));
    }
  }
  return out;
}

_ParsedRow _parseItemRow(String row) {
  var toks = _tokenize(row)..removeWhere((t) => t.raw == '|');

  // Qty di depan: "2 Nasi Goreng ..." / "2 x Nasi Goreng ...".
  int? prefixQty;
  if (toks.length >= 2 && toks[0].num != null && toks[0].num!.qtyLike && toks[0].num!.value <= 99) {
    var next = 1;
    if (toks[next].isX && toks.length > 2) next++;
    if (!toks[next].isNumeric && _lettersRe.hasMatch(toks[next].raw)) {
      prefixQty = toks[0].num!.value;
      toks = toks.sublist(next);
    }
  }

  // Ekor numerik dari kanan.
  var tailStart = toks.length;
  while (tailStart > 0) {
    final t = toks[tailStart - 1];
    if (t.isNumeric || t.raw == ':' || t.raw == '-') {
      tailStart--;
    } else {
      break;
    }
  }
  var nameToks = toks.sublist(0, tailStart);
  var tail = toks.sublist(tailStart).where((t) => t.isNumeric).toList();

  // Jangan biarkan "x" / "@" nyangkut di awal ekor tanpa angka sebelumnya
  // memisahkan nama: ok. Bersihkan tanda baca di nama.
  String nameOf(List<_Tok> ts) => _cleanName(ts.map((t) => t.raw).join(' '));

  // Coba interpretasi; kalau gagal, geser angka terdepan ke nama.
  while (tail.isNotEmpty) {
    final r = _interpretTail(tail, prefixQty);
    if (r != null) {
      return _ParsedRow(nameOf(nameToks), r.$1, r.$2);
    }
    // Pindahkan token terdepan ekor ke nama (mis. "TEH PUCUK 350 1 4.000 4.000").
    nameToks = [...nameToks, tail.first];
    tail = tail.sublist(1);
  }
  return _ParsedRow(nameOf(nameToks), prefixQty, null);
}

/// Mengembalikan (qty, total). total boleh null (baris hanya berisi qty).
(int, int?)? _interpretTail(List<_Tok> tail, int? prefixQty) {
  final xIdx = tail.indexWhere((t) => t.isX);
  final atIdx = tail.indexWhere((t) => t.isAt);
  final nums = tail.where((t) => t.num != null).map((t) => t.num!).toList();
  if (nums.isEmpty) return null;
  if (nums.any((n) => n.negative)) return null;

  int? qty;
  int? price;
  int? total;

  _Num? numAt(int i) => (i >= 0 && i < tail.length) ? tail[i].num : null;

  if (xIdx >= 0) {
    final left = numAt(xIdx - 1);
    var rightIdx = xIdx + 1;
    var rightIsAt = false;
    if (rightIdx < tail.length && tail[rightIdx].isAt) {
      rightIdx++;
      rightIsAt = true;
    }
    final right = numAt(rightIdx);
    final leftIsAt = xIdx - 2 >= 0 && tail[xIdx - 2].isAt;

    final used = <_Num>{};
    if (left != null && right != null) {
      if (rightIsAt || (left.qtyLike && !right.qtyLike && !leftIsAt)) {
        qty = left.value;
        price = right.value;
      } else if (leftIsAt || (right.qtyLike && !left.qtyLike)) {
        qty = right.value;
        price = left.value;
      } else {
        qty = left.value;
        price = right.value;
      }
      used..add(left)..add(right);
    } else if (right != null && right.qtyLike) {
      qty = right.value;
      used.add(right);
    } else if (left != null && left.qtyLike) {
      qty = left.value;
      used.add(left);
    } else {
      return null;
    }
    final rest = nums.where((n) => !used.contains(n)).toList();
    if (rest.isNotEmpty) total = rest.last.value;
    if (rest.length > 1) return null; // terlalu banyak angka, biar digeser ke nama
    total ??= price != null ? qty * price : null;
    if (qty <= 0 || qty > 999) return null;
    if (total != null && !_isPlausibleMoney(_Num(total)) && price == null) return null;
    return (qty, total);
  }

  if (atIdx >= 0) {
    final p = numAt(atIdx + 1);
    if (p == null) return null;
    price = p.value;
    final before = nums.where((n) => tail.indexWhere((t) => t.num == n) < atIdx).toList();
    final after = nums.where((n) => tail.indexWhere((t) => t.num == n) > atIdx + 1).toList();
    if (before.length > 1 || after.length > 1) return null;
    if (before.isNotEmpty && before.first.qtyLike) qty = before.first.value;
    if (after.isNotEmpty) {
      total = after.first.value;
      if (qty == null && price > 0 && total % price == 0) qty = total ~/ price;
    }
    qty ??= prefixQty ?? 1;
    total ??= qty * price;
    return (qty, total);
  }

  switch (nums.length) {
    case 1:
      final n = nums[0];
      if (!_isPlausibleMoney(n)) {
        // "Nasi Goreng 2" -> qty saja, harga di baris berikutnya.
        if (prefixQty == null && n.qtyLike && n.value <= 99 && tail.length == 1) {
          return (n.value, null);
        }
        return null;
      }
      return (prefixQty ?? 1, n.value);
    case 2:
      final a = nums[0], b = nums[1];
      if (a.qtyLike && a.value <= 99 && _isPlausibleMoney(b)) return (a.value, b.value);
      if (_isPlausibleMoney(a) && _isPlausibleMoney(b)) {
        if (a.value > 0 && b.value >= a.value && b.value % a.value == 0 && b.value ~/ a.value <= 99) {
          return (b.value ~/ a.value, b.value);
        }
        return null; // tidak konsisten -> angka pertama mungkin bagian nama
      }
      if (_isPlausibleMoney(a) && b.qtyLike && b.value <= 99) return (b.value, a.value * b.value);
      // Angka kecil tervalidasi aritmetika, mis. "PLASTIK 1 200" -> tidak bisa dipastikan.
      return null;
    case 3:
      final a = nums[0], b = nums[1], c = nums[2];
      bool approx(int x, int y) => (x - y).abs() <= math.max(y * 0.02, 2);
      if (a.qtyLike && approx(a.value * b.value, c.value)) return (a.value, c.value);
      if (b.qtyLike && approx(a.value * b.value, c.value)) return (b.value, c.value);
      return null;
    default:
      return null;
  }
}

String _cleanName(String raw) {
  var s = raw.trim();
  // Kode barang / barcode di depan atau belakang.
  s = s.replaceAll(RegExp(r'^\d{5,}\s+'), '');
  s = s.replaceAll(RegExp(r'\s+\d{5,}$'), '');
  // Penomoran "1." / "01)" di depan.
  s = s.replaceAll(RegExp(r'^\d{1,2}[.)]\s+'), '');
  // Bullet / tanda baca di awal & akhir.
  s = s.replaceAll(RegExp(r'^[\s\-+*•·>:#|.~]+'), '');
  s = s.replaceAll(RegExp(r'[\s\-*:@|=.xX]+$'), '');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

// ---------------------------------------------------------------------------
// 5. Parser utama
// ---------------------------------------------------------------------------

List<_Num> _amountsIn(String row) {
  final out = <_Num>[];
  for (final raw in row.split(' ')) {
    if (raw.contains('%')) continue;
    final n = _parseNum(raw.replaceAll('@', ''));
    if (n != null) out.add(n);
  }
  return out;
}

double? _percentIn(String row) {
  final m = _percentRe.firstMatch(row);
  if (m == null) return null;
  return double.tryParse(m[1]!.replaceAll(',', '.'));
}

/// Nominal "terakhir" di baris ringkasan (yang biasanya rata kanan).
int? _lastAmount(String row, {bool requireMoney = false}) {
  final nums = _amountsIn(row);
  for (final n in nums.reversed) {
    if (requireMoney && !_isPlausibleMoney(n) && n.value < 100) continue;
    return n.value;
  }
  return null;
}

ReceiptParseResult parseReceiptRows(List<String> rawRows) {
  final items = <ReceiptItem>[];
  var idCounter = 1;

  String? pendingName;
  int? pendingQty;
  ReceiptItem? lastItem;
  var rowsSinceLastItem = 999;

  var inFooter = false;
  var adaBarisPajak = false;
  var pajakTermasuk = false;

  int? subtotal;
  int? total;
  var totalIsGrand = false;
  int? pajakNominal;
  double? pajakPersen;
  int? serviceNominal;
  double? servicePersen;
  var itemDiscount = 0;
  var globalDiscount = 0;
  double? globalDiscountPercent;

  void addItem(String name, int qty, int totalPrice) {
    if (qty <= 0) qty = 1;
    final item = ReceiptItem(
      id: idCounter++,
      nama: name,
      qty: qty,
      harga: (totalPrice / qty).round(),
    );
    items.add(item);
    lastItem = item;
    rowsSinceLastItem = 0;
  }

  final rows = rawRows.map(normalizeRow).toList();

  bool footerAhead(int from) {
    var seen = 0;
    for (var j = from + 1; j < rows.length && seen < 3; j++) {
      final r = rows[j];
      if (r.isEmpty || _separatorOnlyRe.hasMatch(r)) continue;
      seen++;
      final l = canonicalLabel(r.toLowerCase());
      if (_taxRe.hasMatch(l) || _serviceRe.hasMatch(l) || _totalRe.hasMatch(l) ||
          _subtotalRe.hasMatch(l) || _discountRe.hasMatch(l)) {
        return true;
      }
    }
    return false;
  }

  /// Baris "nama + nominal" yang nominalnya sama dengan jumlah semua item
  /// sebelumnya dan diikuti baris pajak/service/total -> itu subtotal yang
  /// labelnya salah terbaca OCR (mis. "Subtc tal"), bukan menu.
  bool looksLikeHiddenSubtotal(int index, String labelText, int qty, int amount) {
    if (items.length < 2 || qty != 1) return false;
    final sum = items.fold(0, (s, it) => s + it.total);
    if ((amount - sum).abs() > math.max(2, sum * 0.002)) return false;
    return labelText.trimRight().endsWith(':') || footerAhead(index);
  }

  for (var ri = 0; ri < rows.length; ri++) {
    final row = rows[ri];
    rowsSinceLastItem++;
    if (row.isEmpty || _separatorOnlyRe.hasMatch(row)) continue;
    final lower = canonicalLabel(row.toLowerCase());

    if (_taxInclusiveRe.hasMatch(lower)) {
      pajakTermasuk = true;
      adaBarisPajak = true;
    }
    if (_dppRe.hasMatch(lower)) {
      // "DPP : 45.455" (dasar pengenaan pajak) -> info saja. Kalau satu baris
      // dengan "PPN 4.545", ambil nominal PPN-nya.
      final ppn = _inlineTaxRe.firstMatch(row);
      if (ppn != null) pajakNominal ??= _parseNum(ppn[2]!)?.value;
      if (items.isNotEmpty) inFooter = true;
      continue;
    }

    // --- Ringkasan / footer -------------------------------------------------
    if (_discountSummaryRe.hasMatch(lower)) {
      // "Total Diskon" / "Anda Hemat": hanya dipakai kalau diskon per item
      // tidak terbaca (supaya tidak dobel).
      final amt = _lastAmount(row);
      if (itemDiscount == 0 && globalDiscount == 0 && amt != null && amt > 0) {
        globalDiscount = amt;
      }
      inFooter = inFooter || items.isNotEmpty;
      continue;
    }

    if (_subtotalRe.hasMatch(lower)) {
      final amt = _lastAmount(row);
      if (amt != null && amt > 0) subtotal ??= amt;
      if (items.isNotEmpty) inFooter = true;
      continue;
    }

    if (_totalRe.hasMatch(lower)) {
      final amt = _lastAmount(row);
      final grand = _grandRe.hasMatch(lower);
      if (amt != null && amt > 0 && (total == null || (grand && !totalIsGrand))) {
        total = amt;
        totalIsGrand = grand;
      }
      if (items.isNotEmpty) inFooter = true;
      continue;
    }

    final isTax = _taxRe.hasMatch(lower);
    final isService = _serviceRe.hasMatch(lower);
    if (isTax || (isService && (items.isNotEmpty || _percentRe.hasMatch(lower)))) {
      adaBarisPajak = true;
      final pct = _percentIn(row);
      final amt = _lastAmount(row);
      if (isTax && isService) {
        // "Tax & Service" satu baris -> anggap pajak.
        pajakNominal ??= amt;
        pajakPersen ??= pct;
      } else if (isTax) {
        if (amt != null && amt > 0) pajakNominal = (pajakNominal ?? 0) + amt;
        pajakPersen ??= pct;
      } else {
        if (amt != null && amt > 0) serviceNominal = (serviceNominal ?? 0) + amt;
        servicePersen ??= pct;
      }
      if (items.isNotEmpty) inFooter = true;
      continue;
    }

    final amounts = _amountsIn(row);
    final isDiscount = _discountRe.hasMatch(lower) ||
        (amounts.isNotEmpty && amounts.last.negative && amounts.last.value > 0);
    if (isDiscount) {
      final amt = amounts.isEmpty ? null : amounts.last.value;
      final pct = _percentIn(row);
      final li = lastItem;
      final itemsSoFar = items.fold(0, (s, it) => s + it.total);
      // Diskon persen yang nominalnya cocok dengan total transaksi (mis.
      // "Disc Member 5% 3.700") -> diskon transaksi, bukan per item.
      final looksGlobal = _globalDiscountRe.hasMatch(lower) ||
          (li != null && pct != null && amt != null && items.length > 1 &&
              (amt - itemsSoFar * pct / 100).abs() < (amt - li.total * pct / 100).abs());
      final perItemDisc = li == null
          ? 0
          : (amt != null && amt > 0)
              ? amt
              : (pct != null ? (li.total * pct / 100).round() : 0);
      if (!inFooter && li != null && rowsSinceLastItem <= 2 && !looksGlobal &&
          perItemDisc > 0 && perItemDisc <= li.total) {
        // Diskon per item -> potong langsung ke harga item sebelumnya.
        li.harga = ((li.total - perItemDisc) / li.qty).round();
        itemDiscount += perItemDisc;
        rowsSinceLastItem = 0; // modifier/diskon berikutnya masih nempel
      } else if (amt != null && amt > 0) {
        globalDiscount += amt;
      } else if (pct != null) {
        globalDiscountPercent ??= pct;
      }
      continue;
    }

    if (_paymentRe.hasMatch(lower)) {
      if (items.isNotEmpty) inFooter = true;
      continue;
    }

    if (inFooter) continue;

    // --- Header / info toko -------------------------------------------------
    if (_noiseRe.hasMatch(lower) || _dateTimeRe.hasMatch(lower)) {
      pendingName = null;
      pendingQty = null;
      continue;
    }

    // --- Modifier / add-on: "+ Extra Keju 5.000", "- Less Sugar" -----------
    if (_modifierRe.hasMatch(row)) {
      final li = lastItem;
      final parsed = _parseItemRow(row);
      if (li != null && parsed.total != null && parsed.total! > 0 && rowsSinceLastItem <= 3) {
        // Harga add-on biasanya sudah total untuk qty item induk.
        final newTotal = li.total + parsed.total!;
        li.nama = '${li.nama} + ${parsed.name}';
        li.harga = (newTotal / li.qty).round();
        rowsSinceLastItem = 0;
      } else if (li != null && rowsSinceLastItem <= 3) {
        rowsSinceLastItem = 0;
      }
      continue;
    }

    // --- Baris item -------------------------------------------------------
    final parsed = _parseItemRow(row);

    if (parsed.total != null && parsed.total! > 0 &&
        looksLikeHiddenSubtotal(
            ri,
            parsed.hasName ? row.split(RegExp(r'\d')).first : (pendingName ?? ''),
            parsed.qty ?? 1,
            parsed.total!)) {
      subtotal ??= parsed.total;
      inFooter = true;
      pendingName = null;
      continue;
    }

    if (parsed.hasName) {
      if (parsed.total != null && parsed.total! > 0) {
        addItem(parsed.name, parsed.qty ?? 1, parsed.total!);
        pendingName = null;
        pendingQty = null;
      } else {
        // Nama saja (harga di baris berikutnya), mungkin dengan qty.
        pendingName = parsed.name;
        pendingQty = parsed.qty;
      }
      continue;
    }

    // Baris angka saja: "2 x 25.000 50.000", "50.000", "@25.000".
    if (parsed.total != null && parsed.total! > 0) {
      final qty = parsed.qty ?? 1;
      if (pendingName != null) {
        addItem(pendingName, qty == 1 && pendingQty != null ? pendingQty : qty, parsed.total!);
        pendingName = null;
        pendingQty = null;
      } else {
        final li = lastItem;
        if (li != null && rowsSinceLastItem <= 2 && qty > 1 &&
            (li.total - parsed.total!).abs() <= 2) {
          // Rincian "2 x 25.000" di bawah item yang sudah ada harganya.
          li.qty = qty;
          li.harga = (parsed.total! / qty).round();
          rowsSinceLastItem = 0;
        }
      }
    }
  }

  // --- Rekonsiliasi ringkasan ---------------------------------------------
  final itemsSum = items.fold(0, (s, it) => s + it.total);
  if (globalDiscount == 0 && globalDiscountPercent != null) {
    globalDiscount = ((subtotal ?? itemsSum) * globalDiscountPercent / 100).round();
  }
  // Kalau "subtotal" ternyata sudah sama dengan total item sebelum diskon
  // per-item, jangan potong dua kali.
  final baseSubtotal = (subtotal != null && (subtotal - itemsSum).abs() > 2 &&
          (subtotal - (itemsSum + itemDiscount)).abs() <= 2)
      ? itemsSum
      : (subtotal ?? itemsSum);
  final base = math.max(baseSubtotal - globalDiscount, 0);

  final serviceNom = (serviceNominal ?? 0) > 0
      ? serviceNominal!
      : (servicePersen != null ? (base * servicePersen / 100).round() : 0);
  final servicePersenSaran = (serviceNom > 0 && base > 0)
      ? _niceRate(serviceNom / base * 100, servicePersen)
      : 0.0;

  // Deteksi harga sudah termasuk pajak dengan mencocokkan ke total struk.
  if (!pajakTermasuk && total != null && (pajakNominal ?? 0) > 0) {
    final tanpaPajak = base + serviceNom;
    final denganPajak = tanpaPajak + pajakNominal!;
    if ((total - tanpaPajak).abs() < (total - denganPajak).abs() &&
        (total - tanpaPajak).abs() <= math.max(total * 0.01, 100)) {
      pajakTermasuk = true;
    }
  }

  // Dasar pajak: subtotal saja, atau subtotal + service. Pilih yang
  // menghasilkan tarif "wajar" (10%, 11%, ...) atau yang cocok dengan total.
  double pajakSaran = 0;
  var pajakDenganService = false;
  if (pajakTermasuk) {
    pajakSaran = 0;
  } else if ((pajakNominal ?? 0) > 0 && base > 0) {
    final r1 = pajakNominal! / base * 100;
    final r2 = serviceNom > 0 ? pajakNominal / (base + serviceNom) * 100 : double.infinity;
    pajakDenganService =
        serviceNom > 0 && _rateScore(r2, pajakPersen) < _rateScore(r1, pajakPersen);
    pajakSaran = _niceRate(pajakDenganService ? r2 : r1, pajakPersen);
  } else if (pajakPersen != null) {
    pajakSaran = pajakPersen;
    if (serviceNom > 0) {
      pajakDenganService = true; // kebiasaan umum restoran di Indonesia
      if (total != null) {
        final tanpa = base + serviceNom + base * pajakPersen / 100;
        final dengan = base + serviceNom + (base + serviceNom) * pajakPersen / 100;
        pajakDenganService = (total - dengan).abs() <= (total - tanpa).abs();
      }
    }
  } else if (adaBarisPajak && pajakNominal == null && serviceNominal == null && servicePersen == null) {
    pajakSaran = 10;
  }
  if (pajakSaran > 30) pajakSaran = pajakPersen ?? 10; // salah baca, fallback

  return ReceiptParseResult(
    items: items,
    adaBarisPajakTerpisah: adaBarisPajak,
    subtotalStruk: subtotal,
    totalStruk: total,
    pajakNominal: pajakNominal,
    pajakPersenTertulis: pajakPersen,
    serviceNominal: serviceNominal,
    diskonTotal: globalDiscount,
    pajakTermasuk: pajakTermasuk,
    pajakPersenSaran: pajakSaran,
    servicePersenSaran: servicePersenSaran,
    pajakDenganService: pajakDenganService,
    rows: rows,
  );
}

const _tarifUmum = [10.0, 11.0, 12.0, 5.0, 2.5, 7.5, 8.0, 7.0, 6.0, 15.0];

/// Seberapa jauh tarif dari tarif yang lazim (makin kecil makin wajar).
double _rateScore(double rate, double? tertulis) {
  if (!rate.isFinite) return double.infinity;
  if (tertulis != null) return (rate - tertulis).abs();
  return _tarifUmum.map((t) => (rate - t).abs()).reduce(math.min);
}

/// Bulatkan tarif kalau dekat angka bulat/setengah (selisih karena pembulatan
/// rupiah di struk); kalau tidak, simpan 2 desimal supaya nominalnya pas.
double _niceRate(double rate, double? tertulis) {
  if (tertulis != null && (rate - tertulis).abs() <= 0.1) return tertulis;
  if ((rate - rate.roundToDouble()).abs() <= 0.05) return rate.roundToDouble();
  final half = (rate * 2).roundToDouble() / 2;
  if ((rate - half).abs() <= 0.03) return half;
  return (rate * 100).round() / 100;
}

/// Kata kunci label ringkasan + toleransi salah huruf (edit distance).
const _labelKeywords = {
  'subtotal': 2,
  'grandtotal': 2,
  'total': 1,
  'service': 1,
  'discount': 1,
  'diskon': 1,
  'pajak': 1,
};

/// Perbaiki label ringkasan yang salah baca OCR di awal baris, mis.
/// "subtc tal :" -> "subtotal :", "grand tota1" -> "grand total", "servlce" -> "service".
String canonicalLabel(String lower) {
  final m = RegExp(r'^([a-z0-9]+)(\s+[a-z0-9]+)?').firstMatch(lower);
  if (m == null) return lower;
  final w1 = m[1]!;
  final w2 = m[2]?.trim();
  if (_labelKeywords.containsKey(w1)) return lower; // sudah benar
  for (final useTwo in [true, false]) {
    if (useTwo && w2 == null) continue;
    final cand = useTwo ? '$w1$w2' : w1;
    if (cand.length < 5 || !RegExp(r'[a-z]').hasMatch(cand)) continue;
    for (final e in _labelKeywords.entries) {
      if ((cand.length - e.key.length).abs() > e.value) continue;
      final d = _levenshtein(cand, e.key);
      if (d <= e.value && d < e.key.length / 3) {
        final label = e.key == 'grandtotal' ? 'grand total' : e.key;
        final consumed = useTwo ? m[0]!.length : w1.length;
        return label + lower.substring(consumed);
      }
    }
  }
  return lower;
}

int _levenshtein(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
    }
    prev = cur;
  }
  return prev[b.length];
}
