import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../services/receipt_parser.dart';
import '../theme/app_route.dart';
import '../theme/app_theme.dart';
import 'camera_capture_screen.dart';
import 'review_screen.dart';

/// Beranda: pilih sumber struk (kamera, galeri, atau isi manual).
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isProcessing = false;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _openCamera() async {
    final path = await Navigator.of(context).push<String>(
      slideRoute(const CameraCaptureScreen()),
    );
    if (path == null) return;
    await _processImage(path);
  }

  // Batas ukuran gambar untuk OCR. Foto asli kamera HP sekarang bisa 50-200 MP;
  // gambar sebesar itu bisa membuat ML Kit kehabisan memori dan gagal.
  // 2000 x 4000 px masih jauh lebih dari cukup untuk tulisan struk.
  static const _maxLebar = 2000.0;
  static const _maxTinggi = 4000.0;

  Future<void> _pickFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: _maxLebar,
      maxHeight: _maxTinggi,
      imageQuality: 92,
    );
    if (pickedFile == null) return;
    await _processImage(pickedFile.path);
  }

  void _manualEntry() {
    Navigator.of(context).push(slideRoute(
      ReviewScreen(result: ReceiptParseResult(items: [], adaBarisPajakTerpisah: false)),
    ));
  }

  Future<void> _processImage(String path) async {
    // 1. Crop dulu, biar fokus ke bagian menu sampai total.
    CroppedFile? croppedFile;
    try {
      croppedFile = await ImageCropper().cropImage(
        sourcePath: path,
        maxWidth: _maxLebar.toInt(),
        maxHeight: _maxTinggi.toInt(),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong dari menu sampai Total',
            toolbarColor: AppColors.surface,
            toolbarWidgetColor: AppColors.ink,
            activeControlsWidgetColor: AppColors.accent,
            statusBarLight: true,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Potong dari menu sampai Total',
            aspectRatioLockEnabled: false,
          ),
        ],
      );
    } catch (e, st) {
      _laporkanError('Gambar tidak bisa dibuka untuk dipotong.', e, st);
      return;
    }
    if (croppedFile == null) return;

    setState(() => _isProcessing = true);

    // 2. OCR.
    RecognizedText recognizedText;
    try {
      recognizedText = await _textRecognizer.processImage(InputImage.fromFilePath(croppedFile.path));
    } catch (e, st) {
      if (mounted) setState(() => _isProcessing = false);
      _laporkanError('Aplikasi gagal membaca gambar.', e, st);
      return;
    }

    if (!mounted) return;
    if (recognizedText.text.trim().isEmpty) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tidak ada tulisan yang terbaca. Pastikan struk tidak buram dan tulisannya terlihat jelas.'),
      ));
      return;
    }

    // 3. Parsing. Kalau gagal, tetap lanjut ke Review supaya bisa diisi manual.
    ReceiptParseResult result;
    try {
      result = parseReceipt(recognizedText);
    } catch (e, st) {
      debugPrint('Parser struk gagal: $e\n$st');
      result = ReceiptParseResult(items: [], adaBarisPajakTerpisah: false);
    }

    setState(() => _isProcessing = false);
    Navigator.of(context).push(slideRoute(ReviewScreen(result: result)));
  }

  /// Tampilkan pesan yang jujur + detail teknis yang bisa disalin untuk
  /// dilaporkan (bukan selalu "kurang terang").
  void _laporkanError(String judul, Object error, StackTrace st) {
    debugPrint('$judul $error\n$st');
    if (!mounted) return;
    final detail = '$error'.trim();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(judul),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Coba lagi, atau isi item secara manual. Kalau terus terjadi, salin detail di bawah dan kirim ke pengembang.'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(8)),
              child: SingleChildScrollView(
                child: SelectableText(detail, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: detail)),
            child: const Text('Salin detail'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _manualEntry();
            },
            child: const Text('Isi manual'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 44),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(),
                        const SizedBox(height: 28),
                        const _HowItWorks(),
                        const Spacer(),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _isProcessing ? null : _openCamera,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Foto struk'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isProcessing ? null : _pickFromGallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Pilih dari galeri'),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: _isProcessing ? null : _manualEntry,
                          child: const Text('Isi manual tanpa foto'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_isProcessing) const _ProcessingOverlay(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.receipt_long_rounded, color: AppColors.accent, size: 28),
        ),
        const SizedBox(height: 18),
        Text('Bagi tagihan\ntanpa ribet', style: Theme.of(context).textTheme.headlineSmall?.copyWith(height: 1.15)),
        const SizedBox(height: 8),
        const Text(
          'Foto struknya, pilih siapa makan apa, dan semua langsung tahu harus bayar berapa. '
          'Pajak & service ikut dihitung.',
          style: TextStyle(color: AppColors.muted, fontSize: 14.5, height: 1.4),
        ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (Icons.document_scanner_outlined, 'Foto struk', 'Item, pajak & service terbaca otomatis'),
    (Icons.group_add_outlined, 'Tambah teman', 'Siapa saja yang ikut makan'),
    (Icons.touch_app_outlined, 'Bagi item', 'Ketuk nama di tiap menu'),
    (Icons.send_outlined, 'Kirim hasil', 'Salin ringkasan ke grup chat'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < _steps.length; i++)
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.fill,
                  child: Icon(_steps[i].$1, size: 19, color: AppColors.ink),
                ),
                title: Text(_steps[i].$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(_steps[i].$3, style: const TextStyle(fontSize: 12.5)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(color: AppColors.accent),
                  SizedBox(height: 16),
                  Text('Membaca struk…', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Biasanya cuma beberapa detik', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
