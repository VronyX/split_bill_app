import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_parser_core.dart';

export 'receipt_parser_core.dart' show ReceiptParseResult, parseReceiptRows, groupLinesIntoRows, OcrLine;

/// Ubah hasil OCR ML Kit jadi daftar item + ringkasan pajak/service/diskon.
ReceiptParseResult parseReceipt(RecognizedText recognizedText) {
  final lines = <OcrLine>[];
  for (final block in recognizedText.blocks) {
    for (final line in block.lines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      lines.add(_toOcrLine(text, line));
    }
  }
  return parseReceiptRows(groupLinesIntoRows(lines));
}

OcrLine _toOcrLine(String text, TextLine line) {
  final p = line.cornerPoints;
  if (p.length >= 4) {
    // Urutan corner point ML Kit: kiri-atas, kanan-atas, kanan-bawah, kiri-bawah.
    final dxTop = (p[1].x - p[0].x).toDouble();
    final dyTop = (p[1].y - p[0].y).toDouble();
    final dxSide = (p[3].x - p[0].x).toDouble();
    final dySide = (p[3].y - p[0].y).toDouble();
    final cx = (p[0].x + p[1].x + p[2].x + p[3].x) / 4;
    final cy = (p[0].y + p[1].y + p[2].y + p[3].y) / 4;
    return OcrLine(
      text: text,
      centerX: cx,
      centerY: cy,
      width: math.sqrt(dxTop * dxTop + dyTop * dyTop),
      height: math.max(math.sqrt(dxSide * dxSide + dySide * dySide), 1),
      angle: math.atan2(dyTop, dxTop),
    );
  }
  final box = line.boundingBox;
  return OcrLine(
    text: text,
    centerX: box.left + box.width / 2,
    centerY: box.top + box.height / 2,
    width: box.width,
    height: box.height,
  );
}
