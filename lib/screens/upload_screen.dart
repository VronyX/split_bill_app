import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../theme/app_theme.dart';
import '../theme/app_route.dart';
import '../services/receipt_parser.dart';
import 'camera_capture_screen.dart';
import 'review_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedImage;
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

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    await _processImage(pickedFile.path);
  }

  Future<void> _processImage(String path) async {
    // 1. Crop dulu, biar user bisa fokus ke bagian item & harga.
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Sesuaikan Area Struk',
          toolbarColor: AppColors.ink,
          toolbarWidgetColor: AppColors.paper,
          lockAspectRatio: false,
        ),
      ],
    );
    if (croppedFile == null) return; // user batal crop

    setState(() {
      _selectedImage = File(croppedFile.path);
      _isProcessing = true;
    });

    // 2. Jalankan OCR.
    final inputImage = InputImage.fromFile(_selectedImage!);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    // 3. Parsing jadi list item.
    final result = parseReceipt(recognizedText);

    setState(() => _isProcessing = false);
    if (!mounted) return;

    // 4. Pindah ke screen Review.
    Navigator.of(context).push(
      slideRoute(
        ReviewScreen(
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
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
                    onPressed: _isProcessing ? null : _openCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _pickFromGallery,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.stamp),
              SizedBox(height: 12),
              Text('Membaca struk...', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity),
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