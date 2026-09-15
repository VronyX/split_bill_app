import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/receipt_item.dart';

final _skipKeywords = RegExp(
  r'(date|time in|table|purpose|cashier|dine in|not paid|sales no|info\s*:|'
  r'offline|^qr|subtotal|grand total|\bpb1\b|\d+\s*items?$|jl\.|no\.\s*\d|'
  r'jakarta|pluit|penjaringan|taiwan street|emporium)',
  caseSensitive: false,
);

final _pajakServiceKeywords = RegExp(
  r'(\bpb1\b|\bppn\b|\btax\b|\bservice\b|\bsvc\b|service charge)',
  caseSensitive: false,
);

final _qtyPrefixPattern = RegExp(r'^(\d+)\s*[xX]');
final _numberPattern = RegExp(r'[\d]+(?:[.,]\d+)*');
final _pureNumberPattern = RegExp(r'^[\d.,@]+$');

class ReceiptParseResult {
  final List<ReceiptItem> items;
  final bool adaBarisPajakTerpisah;
  ReceiptParseResult({required this.items, required this.adaBarisPajakTerpisah});
}

ReceiptParseResult parseReceipt(RecognizedText recognizedText) {
  // 1. Kumpulkan semua baris + posisi (Y tengah, X kiri).
  final lines = <_PositionedLine>[];
  for (final block in recognizedText.blocks) {
    for (final line in block.lines) {
      final box = line.boundingBox;
      lines.add(_PositionedLine(
        text: line.text.trim(),
        centerY: box.top + box.height / 2,
        left: box.left,
        lineHeight: box.height.toDouble(),
      ));
    }
  }

  lines.sort((a, b) => a.centerY.compareTo(b.centerY));

  final avgLineHeight = lines.isEmpty
      ? 12.0
      : lines.map((l) => l.lineHeight).reduce((a, b) => a + b) / lines.length;
  final threshold = avgLineHeight * 0.45;
  final rows = <List<_PositionedLine>>[];
  for (final line in lines) {
    if (rows.isNotEmpty &&
        (line.centerY - rows.last.first.centerY).abs() < threshold) {
      rows.last.add(line);
    } else {
      rows.add([line]);
    }
  }

  var rowTexts = rows.map((row) {
    row.sort((a, b) => a.left.compareTo(b.left));
    return row.map((l) => l.text).join(' ').trim();
  }).where((t) => t.isNotEmpty).toList();

  // 2. Gabungkan baris "qty x @harga" yang totalnya kepisah ke baris berikutnya
  //    (misal: "4x @39.000" lalu baris terpisah "156.000").
  final merged = <String>[];
  for (int i = 0; i < rowTexts.length; i++) {
    var text = rowTexts[i];
    final hasQty = _qtyPrefixPattern.hasMatch(text);
    final numCount = _numberPattern.allMatches(text).length;
    if (hasQty && numCount == 1 && i + 1 < rowTexts.length) {
      final next = rowTexts[i + 1];
      if (_pureNumberPattern.hasMatch(next)) {
        text = '$text $next';
        i++; // baris berikutnya sudah dipakai, lewati
      }
    }
    merged.add(text);
  }

  // 3. Pasangkan baris nama dengan baris angka (qty/harga), toleran
  //    terhadap baris angka yang tidak diawali "Nx" (qty default 1).
  final items = <ReceiptItem>[];
  int idCounter = 1;
  String? pendingName;
  bool adaBarisPajak = false;

  for (final text in merged) {
    if (_pajakServiceKeywords.hasMatch(text)) adaBarisPajak = true;

    if (_skipKeywords.hasMatch(text)) {
      pendingName = null;
      continue;
    }

    final qtyMatch = _qtyPrefixPattern.firstMatch(text);
    final isNumericRow = qtyMatch != null || _looksNumeric(text);
    final numbers = _numberPattern.allMatches(text).toList();

    if (isNumericRow && numbers.isNotEmpty) {
      if (pendingName == null) continue; // angka tanpa nama, tidak bisa dipasangkan

      final qty = qtyMatch != null ? int.tryParse(qtyMatch.group(1)!) ?? 1 : 1;
      final total = _parseRupiah(numbers.last.group(0)!);
      if (total == 0) {
        pendingName = null;
        continue;
      }
      final hargaSatuan = qty > 0 ? (total / qty).round() : total;

      items.add(ReceiptItem(
        id: idCounter++,
        nama: pendingName!,
        qty: qty,
        harga: hargaSatuan,
      ));
      pendingName = null;
    } else {
      pendingName = text;
    }
  }

  return ReceiptParseResult(items: items, adaBarisPajakTerpisah: adaBarisPajak);
}

/// Baris dianggap "baris angka" kalau diawali digit/@, atau proporsi
/// karakter digitnya cukup tinggi (bukan nama item yang kebetulan ada angka).
bool _looksNumeric(String text) {
  if (text.isEmpty) return false;
  if (RegExp(r'^[\d@]').hasMatch(text)) return true;
  final digitCount = text.replaceAll(RegExp(r'[^\d]'), '').length;
  return digitCount / text.length > 0.35;
}

int _parseRupiah(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[.,]'), '');
  return int.tryParse(cleaned) ?? 0;
}

class _PositionedLine {
  final String text;
  final double centerY;
  final double left;
  final double lineHeight;
  _PositionedLine({
    required this.text,
    required this.centerY,
    required this.left,
    required this.lineHeight,
  });
}