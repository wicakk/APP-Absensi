import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as myHttp;

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

class _FaceRecognitionPageState extends State<FaceRecognitionPage> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  bool _isCameraReady = false;
  bool _isFaceDetected = false;
  bool _isDetecting = false;
  bool _isLoading = false;
  bool _isStreamStopped = false; // FIX: flag untuk cegah race condition
  bool _isTakingPicture = false; // FIX: cegah double tap
  XFile? _capturedImage;

  // ML Kit face detector - sensitivitas longgar agar mudah terdeteksi
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,
      enableTracking: true,        // tracking ON agar lebih stabil
      minFaceSize: 0.05,           // diturunkan dari 0.15 → lebih mudah detect
      performanceMode: FaceDetectorMode.accurate, // lebih akurat meski sedikit lebih lambat
    ),
  );

  // Counter untuk stabilisasi: wajah harus terdeteksi beberapa frame berturut-turut
  int _faceDetectedFrameCount = 0;
  static const int _faceStableThreshold = 3; // butuh 3 frame berturut-turut

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();

      final frontCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.yuv420, // FIX: gunakan yuv420 bukan jpeg untuk stream
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() {
        _isCameraReady = true;
        _isStreamStopped = false;
      });

      _cameraController!.startImageStream(_detectFaceFromStream);
    } catch (e) {
      debugPrint("ERROR INIT CAMERA: $e");
      if (mounted) showMessage("Gagal membuka kamera: $e");
    }
  }

  // Deteksi wajah dari stream kamera (realtime)
  Future<void> _detectFaceFromStream(CameraImage image) async {
    // FIX: tambah _isStreamStopped & _isTakingPicture agar tidak bentrok
    if (_isDetecting || _capturedImage != null || _isStreamStopped || _isTakingPicture) return;
    _isDetecting = true;

    try {
      final bytes = Uint8List.fromList(
        image.planes.fold<List<int>>([], (buf, plane) => buf..addAll(plane.bytes)),
      );

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.yuv_420_888,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);

      if (mounted && !_isStreamStopped) {
        if (faces.isNotEmpty) {
          _faceDetectedFrameCount++;
        } else {
          _faceDetectedFrameCount = 0;
        }

        final stable = _faceDetectedFrameCount >= _faceStableThreshold;
        setState(() => _isFaceDetected = stable);

        // AUTO FOTO: setelah wajah stabil terdeteksi, langsung ambil foto
        if (stable && !_isTakingPicture && _capturedImage == null) {
          _takePicture();
        }
      }
    } catch (_) {
      // abaikan error stream
    } finally {
      _isDetecting = false;
    }
  }

  // FIX: Ambil foto dengan penanganan race condition yang benar
  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isTakingPicture || _isStreamStopped) return;

    // Set flag SEBELUM apapun untuk cegah double-tap & stream masuk lagi
    setState(() => _isTakingPicture = true);
    _isStreamStopped = true;

    try {
      // Tunggu frame terakhir selesai diproses
      await Future.delayed(const Duration(milliseconds: 500));

      // Stop stream
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }

      // Tunggu sebentar lagi agar kamera stabil
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      final image = await _cameraController!.takePicture();

      if (mounted) {
        setState(() => _capturedImage = image);
        // AUTO SUBMIT: langsung kirim setelah foto diambil
        _submitPresensi();
      }
    } catch (e) {
      debugPrint("ERROR TAKE PICTURE: $e");
      if (mounted) showMessage("Gagal mengambil foto, coba lagi");

      // Reset dan nyalakan kembali stream
      _isStreamStopped = false;
      if (mounted && _cameraController != null && _cameraController!.value.isInitialized) {
        try {
          _cameraController!.startImageStream(_detectFaceFromStream);
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  // Ulangi — hapus foto dan mulai ulang kamera
  void _retake() {
    setState(() {
      _capturedImage = null;
      _isFaceDetected = false;
      _isStreamStopped = false;
      _isTakingPicture = false;
    });

    try {
      if (_cameraController != null &&
          _cameraController!.value.isInitialized &&
          !_cameraController!.value.isStreamingImages) {
        _cameraController!.startImageStream(_detectFaceFromStream);
      }
    } catch (e) {
      debugPrint("ERROR RESTART STREAM: $e");
      // Jika gagal restart stream, reinit kamera
      _initCamera();
    }
  }

  // Kirim data ke API
  Future<void> _submitPresensi() async {
    if (_capturedImage == null) {
      showMessage("Ambil foto selfie terlebih dahulu");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bytes = await File(_capturedImage!.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await myHttp.post(
        // Uri.parse('http://192.168.187.131:8000/api/save-presensi'),
        Uri.parse('http://3.27.35.240/api/save-presensi'),
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "latitude": widget.latitude,
          "longitude": widget.longitude,
          "foto": base64Image,
        }),
      ).timeout(const Duration(seconds: 30)); // FIX: tambah timeout

      debugPrint("STATUS CODE: ${response.statusCode}");
      debugPrint("BODY: ${response.body}");

      if (!mounted) return;

      final result = jsonDecode(response.body);
      showMessage(result["message"] ?? "Terjadi kesalahan");

      if (result["success"] == true) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      debugPrint("ERROR SIMPAN: $e");
      if (mounted) showMessage("Terjadi kesalahan koneksi: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _isStreamStopped = true;
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
                top: 50, left: 20, right: 20, bottom: 20),
            decoration: const BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
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
                const SizedBox(height: 5),
                const Text(
                  "Langkah 2 dari 2",
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isFaceDetected
                        ? Colors.green.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isFaceDetected ? Colors.greenAccent : Colors.white30,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isFaceDetected
                            ? Icons.face
                            : Icons.face_retouching_off,
                        color: _isFaceDetected
                            ? Colors.greenAccent
                            : Colors.white54,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isFaceDetected
                            ? "Wajah terdeteksi ✓"
                            : "Arahkan wajah ke kamera...",
                        style: TextStyle(
                          color: _isFaceDetected
                              ? Colors.greenAccent
                              : Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // KAMERA / PREVIEW FOTO
          Expanded(
            child: _buildCameraArea(),
          ),

          // TOMBOL BAWAH
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(20),
            child: _capturedImage != null
                ? _buildAfterCaptureButtons()
                : _buildCaptureButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraArea() {
    if (_capturedImage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(_capturedImage!.path),
            fit: BoxFit.cover,
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 60),
                  SizedBox(height: 10),
                  Text(
                    "Wajah terdeteksi, mengirim data...",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  CircularProgressIndicator(color: Colors.greenAccent),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (!_isCameraReady || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        // FIX: tampilkan loading saat sedang mengambil foto
        if (_isTakingPicture)
          Container(
            color: Colors.black45,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text("Mengambil foto...",
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        // Overlay oval panduan wajah
        if (!_isTakingPicture)
          Center(
            child: Container(
              width: 220,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isFaceDetected ? Colors.greenAccent : Colors.white54,
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(140),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCaptureButton() {
    return Column(
      children: [
        Text(
          _isTakingPicture
              ? "Mengambil foto..."
              : _isFaceDetected
                  ? "Wajah terdeteksi, foto otomatis diambil..."
                  : "Posisikan wajah di dalam lingkaran",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: (_isFaceDetected || _isTakingPicture)
              ? const SizedBox(
                  key: ValueKey('spinner'),
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    color: Colors.greenAccent,
                    strokeWidth: 3,
                  ),
                )
              : Container(
                  key: const ValueKey('idle'),
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white12,
                    border: Border.all(color: Colors.white30, width: 3),
                  ),
                  child: const Icon(Icons.face, color: Colors.white38, size: 32),
                ),
        ),
      ],
    );
  }

  Widget _buildAfterCaptureButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isLoading ? null : _retake,
            icon: const Icon(Icons.refresh),
            label: const Text("Ulangi"),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isLoading ? null : _submitPresensi,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(
              _isLoading ? "Menyimpan..." : "Absen Masuk",
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}