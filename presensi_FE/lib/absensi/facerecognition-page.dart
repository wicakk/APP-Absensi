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
  XFile? _capturedImage;

  // ML Kit face detector
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,
      enableTracking: false,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();

    // Pilih kamera depan (selfie)
    final frontCamera = _cameras!.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras!.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _cameraController!.initialize();

    if (!mounted) return;
    setState(() => _isCameraReady = true);

    // Mulai deteksi wajah secara realtime dari stream kamera
    _cameraController!.startImageStream(_detectFaceFromStream);
  }

  // Deteksi wajah dari stream kamera (realtime)
  Future<void> _detectFaceFromStream(CameraImage image) async {
    if (_isDetecting || _capturedImage != null) return;
    _isDetecting = true;

    try {
      final bytes = image.planes.fold<List<int>>(
        [],
        (buffer, plane) => buffer..addAll(plane.bytes),
      );

      final inputImage = InputImage.fromBytes(
        bytes: Uint8List.fromList(bytes),
        metadata: InputImageMetadata(
          size: Size(
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          rotation: InputImageRotation.rotation270deg, // sesuaikan jika perlu
          format: InputImageFormat.yuv_420_888,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() => _isFaceDetected = faces.isNotEmpty);
      }
    } catch (_) {
      // abaikan error stream
    } finally {
      _isDetecting = false;
    }
  }

  // Ambil foto selfie
  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    // Hentikan stream dulu sebelum foto
    await _cameraController!.stopImageStream();

    try {
      final image = await _cameraController!.takePicture();
      setState(() => _capturedImage = image);
    } catch (e) {
      showMessage("Gagal mengambil foto: $e");
      // Lanjutkan stream lagi jika gagal
      _cameraController!.startImageStream(_detectFaceFromStream);
    }
  }

  // Ulangi — hapus foto dan mulai ulang kamera
  void _retake() {
    setState(() {
      _capturedImage = null;
      _isFaceDetected = false;
    });
    _cameraController!.startImageStream(_detectFaceFromStream);
  }

  // Kirim data ke API
  Future<void> _submitPresensi() async {
    if (_capturedImage == null) {
      showMessage("Ambil foto selfie terlebih dahulu");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Konversi foto ke base64
      final bytes = await File(_capturedImage!.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      var response = await myHttp.post(
        Uri.parse('http://10.0.2.2:8000/api/save-presensi'),
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "latitude": widget.latitude,
          "longitude": widget.longitude,
          "foto": base64Image, // <-- foto selfie dalam base64
        }),
      );

      print("STATUS CODE: ${response.statusCode}");
      print("BODY: ${response.body}");

      if (!mounted) return;

      var result = jsonDecode(response.body);
      showMessage(result["message"] ?? "Terjadi kesalahan");

      if (result["success"] == true) {
        // Kembali ke halaman awal (pop semua route sampai root)
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      print("ERROR SIMPAN: $e");
      if (mounted) showMessage("Terjadi kesalahan koneksi");
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
                  "Langkah 2 dari 2", // <-- step 2: wajah
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 10),
                // Indikator deteksi wajah
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
                      color:
                          _isFaceDetected ? Colors.greenAccent : Colors.white30,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isFaceDetected ? Icons.face : Icons.face_retouching_off,
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
    // Tampilkan preview foto jika sudah diambil
    if (_capturedImage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(_capturedImage!.path),
            fit: BoxFit.cover,
          ),
          // Overlay centang hijau
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
                    "Foto siap dikirim",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Tampilkan kamera
    if (!_isCameraReady || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        // Overlay oval panduan wajah
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

  // Tombol ambil foto (sebelum foto)
  Widget _buildCaptureButton() {
    return Column(
      children: [
        Text(
          _isFaceDetected
              ? "Tekan tombol untuk mengambil foto"
              : "Posisikan wajah di dalam lingkaran",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _isFaceDetected ? _takePicture : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isFaceDetected ? Colors.white : Colors.white24,
              border: Border.all(
                color: _isFaceDetected ? Colors.greenAccent : Colors.white30,
                width: 3,
              ),
            ),
            child: Icon(
              Icons.camera_alt,
              color: _isFaceDetected ? Colors.black : Colors.white38,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }

  // Tombol setelah foto diambil: Ulangi | Absen Masuk
  Widget _buildAfterCaptureButtons() {
    return Row(
      children: [
        // Tombol ulangi
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
        // Tombol absen masuk
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
