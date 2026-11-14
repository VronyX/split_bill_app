import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;

  Offset? _focusPoint; // posisi tap di layar (buat gambar lingkaran fokus)
  bool _showFocusCircle = false;
  bool _flashOn = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    // Resolusi lebih tinggi = huruf kecil di struk (terutama struk thermal
    // minimarket) lebih terbaca oleh OCR.
    _controller = CameraController(
      backCamera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _initFuture = _controller!.initialize().then((_) async {
      try {
        await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
        await _controller!.setFlashMode(FlashMode.off);
        await _controller!.setFocusMode(FocusMode.auto);
      } catch (_) {
        // tidak semua device support, abaikan
      }
    });
    if (mounted) setState(() {});
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final next = !_flashOn;
    try {
      // Mode torch: lampu nyala terus, membantu di restoran yang redup dan
      // mengurangi bayangan tangan di kertas struk.
      await _controller!.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _flashOn = next);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final file = await _controller!.takePicture();
      if (_flashOn) {
        try {
          await _controller!.setFlashMode(FlashMode.off);
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context).pop(file.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil foto, coba lagi.')),
      );
    }
  }

  Future<void> _onTapFocus(TapUpDetails details, BoxConstraints constraints) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    // Konversi posisi tap (dalam koordinat layar) ke koordinat relatif (0.0 - 1.0)
    // yang diminta oleh setFocusPoint/setExposurePoint.
    final relativeX = details.localPosition.dx / constraints.maxWidth;
    final relativeY = details.localPosition.dy / constraints.maxHeight;
    final point = Offset(relativeX, relativeY);

    setState(() {
      _focusPoint = details.localPosition;
      _showFocusCircle = true;
    });

    try {
      await _controller!.setFocusPoint(point);
      await _controller!.setExposurePoint(point);
      await _controller!.setFocusMode(FocusMode.auto);
    } catch (_) {
      // beberapa device/emulator tidak support, biarkan saja gagal diam-diam
    }

    // Sembunyikan lingkaran fokus setelah sebentar.
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _showFocusCircle = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.stamp))
          : FutureBuilder(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.stamp));
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _onTapFocus(details, constraints),
                    child: CameraPreview(_controller!),
                  ),
                  // Bingkai panduan + grid bantu perataan struk.
                  IgnorePointer(child: CustomPaint(painter: _GuidePainter())),
                  const Positioned(
                    top: 100,
                    left: 24,
                    right: 24,
                    child: IgnorePointer(
                      child: SafeArea(
                        child: Text(
                          'Luruskan struk di dalam bingkai, pastikan cukup terang\n'
                          'dan tulisan tajam. Ketuk layar untuk fokus.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_showFocusCircle && _focusPoint != null)
                    Positioned(
                      left: _focusPoint!.dx - 35,
                      top: _focusPoint!.dy - 35,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _showFocusCircle ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.stamp, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 40,
                    left: 16,
                    child: SafeArea(
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: 16,
                    child: SafeArea(
                      child: IconButton(
                        icon: Icon(
                          _flashOn ? Icons.flash_on : Icons.flash_off,
                          color: _flashOn ? AppColors.stamp : Colors.white,
                          size: 28,
                        ),
                        onPressed: _toggleFlash,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 32,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _capture,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isCapturing ? Colors.white54 : Colors.white,
                            border: Border.all(color: AppColors.stamp, width: 4),
                          ),
                          child: _isCapturing
                              ? const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: AppColors.stamp),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Bingkai vertikal (struk umumnya panjang & sempit).
    final frame = Rect.fromLTRB(
      size.width * 0.08,
      size.height * 0.17,
      size.width * 0.92,
      size.height * 0.84,
    );

    // Gelapkan area di luar bingkai.
    final shade = Paint()..color = Colors.black.withValues(alpha: 0.35);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(12))),
      ),
      shade,
    );

    // Grid 3x3 di dalam bingkai.
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    for (int i = 1; i < 3; i++) {
      final x = frame.left + frame.width / 3 * i;
      canvas.drawLine(Offset(x, frame.top), Offset(x, frame.bottom), grid);
      final y = frame.top + frame.height / 3 * i;
      canvas.drawLine(Offset(frame.left, y), Offset(frame.right, y), grid);
    }

    // Sudut bingkai.
    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 26.0;
    for (final c in [frame.topLeft, frame.topRight, frame.bottomLeft, frame.bottomRight]) {
      final dx = c.dx == frame.left ? len : -len;
      final dy = c.dy == frame.top ? len : -len;
      canvas.drawLine(c, c.translate(dx, 0), corner);
      canvas.drawLine(c, c.translate(0, dy), corner);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
