import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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
    _controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initFuture = _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final file = await _controller!.takePicture();
    if (!mounted) return;
    Navigator.of(context).pop(file.path);
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
                  // Grid 3x3 bantu perataan struk.
                  IgnorePointer(child: CustomPaint(painter: _GridPainter())),
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
                            color: Colors.white,
                            border: Border.all(color: AppColors.stamp, width: 4),
                          ),
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

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1;

    for (int i = 1; i < 3; i++) {
      final x = size.width / 3 * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      final y = size.height / 3 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}