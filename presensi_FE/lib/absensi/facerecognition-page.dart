import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as myHttp;
import 'package:image/image.dart' as img; // tambahkan: image: ^4.1.7 di pubspec.yaml

class FaceRecognitionPage extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String token;

  const FaceRecognitionPage({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.token,
  }) : super(key: key);

  @override
  State<FaceRecognitionPage> createState() => _FaceRecognitionPageState();
}

class _FaceRecognitionPageState extends State<FaceRecognitionPage>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isFaceDetected = false;
  bool _isDetecting = false;
  bool _isProcessing = false;
  bool _isLoading = false;
  String _statusText = "Posisikan wajah di dalam lingkaran";

  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  XFile? _capturedImage;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableTracking: false,
      enableClassification: false,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _initCamera();
  }

  /* ================= INIT CAMERA ================= */

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() => _isCameraReady = true);
      _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint("❌ Init camera error: $e");
      _setStatus("Gagal membuka kamera");
    }
  }

  /* ================= FACE DETECTION ================= */

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || _isProcessing) return;
    _isDetecting = true;

    try {
      final camera = _cameraController!.description;

      final InputImage inputImage;

      if (Platform.isAndroid) {
        inputImage = InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: _rotationFromSensorOrientation(camera.sensorOrientation),
            format: InputImageFormat.nv21,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );
      } else {
        inputImage = InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.bgra8888,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );
      }

      final faces = await _faceDetector.processImage(inputImage);
      debugPrint("👤 Faces detected: ${faces.length}");

      if (mounted) setState(() => _isFaceDetected = faces.isNotEmpty);

      if (faces.isNotEmpty && !_isProcessing) {
        _isProcessing = true;
        _setStatus("Wajah terdeteksi, mengambil foto...");

        // Beri jeda supaya user lihat lingkaran hijau dulu
        await Future.delayed(const Duration(milliseconds: 800));

        if (!mounted) return;

        await _takePicture();

        if (_capturedImage != null) {
          await _submitPresensi();
        } else {
          _resetAndRetry("Gagal ambil foto, coba lagi");
        }
      }
    } catch (e) {
      debugPrint("❌ Face detection error: $e");
      _isProcessing = false;
    } finally {
      _isDetecting = false;
    }
  }

  /* ================= HELPERS ================= */

  InputImageRotation _rotationFromSensorOrientation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  void _setStatus(String text) {
    debugPrint("📋 Status: $text");
    if (mounted) setState(() => _statusText = text);
  }

  /// Reset semua state dan restart image stream untuk coba ulang
  void _resetAndRetry(String message) {
    debugPrint("🔄 Reset & retry: $message");
    _isProcessing = false;
    _capturedImage = null;
    if (mounted) setState(() => _isFaceDetected = false);
    _setStatus(message);

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted &&
          _cameraController != null &&
          _cameraController!.value.isInitialized &&
          !_cameraController!.value.isStreamingImages) {
        _cameraController!.startImageStream(_processCameraImage);
        _setStatus("Posisikan wajah di dalam lingkaran");
      }
    });
  }

  /* ================= TAKE PICTURE ================= */

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
        // Beri jeda supaya stream benar-benar berhenti
        await Future.delayed(const Duration(milliseconds: 300));
      }

      _capturedImage = await _cameraController!.takePicture();
      debugPrint("📸 Foto diambil: ${_capturedImage!.path}");
    } catch (e) {
      debugPrint("❌ Gagal ambil foto: $e");
      _capturedImage = null;
    }
  }

  /* ================= COMPRESS IMAGE ================= */

  /// Kompres foto agar tidak terlalu besar → cegah timeout
  Future<String> _compressToBase64(String filePath) async {
    final originalBytes = await File(filePath).readAsBytes();
    debugPrint(
        "📦 Ukuran asli: ${(originalBytes.length / 1024).toStringAsFixed(1)} KB");

    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      debugPrint("⚠️ Gagal decode, kirim apa adanya");
      return base64Encode(originalBytes);
    }

    // Resize max 800px lebar, JPEG quality 65%
    final resized = img.copyResize(decoded, width: 800);
    final compressed = img.encodeJpg(resized, quality: 65);

    debugPrint(
        "📦 Setelah kompres: ${(compressed.length / 1024).toStringAsFixed(1)} KB");

    return base64Encode(compressed);
  }

  /* ================= SEND TO API ================= */

  Future<void> _submitPresensi() async {
    if (_capturedImage == null) {
      _resetAndRetry("Foto tidak tersedia");
      return;
    }

    _setStatus("Menyimpan presensi...");
    if (mounted) setState(() => _isLoading = true);

    try {
      final base64Image = await _compressToBase64(_capturedImage!.path);

      debugPrint("🌐 POST ke API...");
      debugPrint("   Lat: ${widget.latitude}, Lng: ${widget.longitude}");

      final response = await myHttp
          .post(
            Uri.parse('http://54.252.215.200/api/save-presensi'),
            headers: {
              "Authorization": "Bearer ${widget.token}",
              "Content-Type": "application/json",
              // ✅ Penting: paksa server return JSON bukan HTML error page
              "Accept": "application/json",
            },
            body: jsonEncode({
              "latitude": widget.latitude,
              "longitude": widget.longitude,
              "foto": base64Image,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception("Timeout 30 detik"),
          );

      // ✅ Log lengkap untuk debug
      debugPrint("📡 Status code: ${response.statusCode}");
      debugPrint("📡 Response: ${response.body}");

      if (!mounted) return;

      // ✅ Tangani response bukan JSON dengan aman (misal HTML 500 error)
      Map<String, dynamic> result;
      try {
        result = jsonDecode(response.body);
      } catch (_) {
        debugPrint("❌ Response bukan JSON valid: ${response.body}");
        _resetAndRetry("Server error (${response.statusCode})");
        return;
      }

      final bool success = result["success"] == true;
      final String message = result["message"] ?? "Terjadi kesalahan";

      showMessage(message);

      if (success) {
        debugPrint("✅ Presensi berhasil disimpan!");
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        debugPrint("❌ Server tolak: $message");
        _resetAndRetry(message);
      }
    } catch (e) {
      debugPrint("❌ Submit error: $e");
      if (mounted) showMessage("Error: ${e.toString()}");
      _resetAndRetry("Gagal koneksi, coba lagi");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ================= MESSAGE ================= */

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /* ================= DISPOSE ================= */

  @override
  void dispose() {
    _animController.dispose();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  /* ================= UI ================= */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ── HEADER ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
                top: 50, left: 20, right: 20, bottom: 20),
            decoration: const BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Clock In",
                      style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      _isFaceDetected ? Icons.check_circle : Icons.face,
                      color: _isFaceDetected ? Colors.greenAccent : Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isLoading
                            ? "Menyimpan presensi..."
                            : _isFaceDetected
                                ? "Wajah terdeteksi ✓"
                                : "Arahkan wajah ke kamera...",
                        style: TextStyle(
                          color: _isFaceDetected
                              ? Colors.greenAccent
                              : Colors.white70,
                          fontWeight: _isFaceDetected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── KAMERA ──
          Expanded(
            child: !_isCameraReady || _cameraController == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_cameraController!),
                      CustomPaint(painter: _OvalOverlayPainter()),
                      Center(
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isFaceDetected ? _pulseAnimation.value : 1.0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 220,
                                height: 280,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _isFaceDetected
                                        ? Colors.greenAccent
                                        : Colors.white54,
                                    width: _isFaceDetected ? 4 : 2.5,
                                  ),
                                  borderRadius: BorderRadius.circular(140),
                                  boxShadow: _isFaceDetected
                                      ? [
                                          BoxShadow(
                                            color: Colors.greenAccent
                                                .withOpacity(0.4),
                                            blurRadius: 20,
                                            spreadRadius: 4,
                                          )
                                        ]
                                      : [],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),

          // ── FOOTER STATUS ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            color: Colors.black,
            child: _isLoading
                ? Column(
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 10),
                      Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  )
                : Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isFaceDetected ? Colors.greenAccent : Colors.white54,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/* ================= OVAL OVERLAY PAINTER ================= */

class _OvalOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.45);

    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 224,
      height: 284,
    );

    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(fullRect)
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}