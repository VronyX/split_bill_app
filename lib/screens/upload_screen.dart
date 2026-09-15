import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_cropper/image_cropper.dart';
import '../services/receipt_parser.dart';
import 'review_screen.dart';
import '../theme/app_theme.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedImage;
  bool _isProcessing = false;
  String? _rawText; // hasil teks mentah dari OCR, sementara ditampilkan dulu

  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void dispose() {
    _textRecognizer.close(); // wajib ditutup supaya tidak bocor resource
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Sesuaikan Area Struk',
          toolbarColor: AppColors.ink,
          toolbarWidgetColor: AppColors.paper,
          lockAspectRatio: false,
        ),
      ],
    );
    if (croppedFile == null) return;

    setState(() {
      _selectedImage = File(croppedFile.path);
      _isProcessing = true;
      _rawText = null;
    });

    final inputImage = InputImage.fromFile(_selectedImage!);
    final RecognizedText recognizedText =
    await _textRecognizer.processImage(inputImage);

    final result = parseReceipt(recognizedText);

    setState(() {
      _isProcessing = false;
    });

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          items: result.items,
          adaBarisPajakTerpisah: result.adaBarisPajakTerpisah,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yuk Hitung-hitungan Kita'),
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.paperDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(child: _buildPreview()),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.image),
                    label: const Text('Galeri'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_isProcessing) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.stamp),
        ),
      );
    }

    if (_rawText != null) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_selectedImage!, height: 160, fit: BoxFit.cover, width: double.infinity),
              ),
            const SizedBox(height: 12),
            const Text('Hasil bacaan OCR (mentah):',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(
              _rawText!.isEmpty ? '(tidak ada teks terdeteksi)' : _rawText!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: Text(
          'Foto atau upload struk untuk mulai',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}