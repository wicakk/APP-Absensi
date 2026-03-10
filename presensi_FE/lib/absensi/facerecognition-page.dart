import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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
  bool _isLoading = false;
  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      debugPrint("Cameras found: ${_cameras?.length}");

      final frontCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      debugPrint("Camera initialized OK");

      if (!mounted) return;
      setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint("ERROR INIT CAMERA: $e");
      if (mounted) showMessage("Gagal membuka kamera: $e");
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final XFile file = await _cameraController!.takePicture();
      debugPrint("Photo taken: ${file.path}");
      setState(() => _capturedImage = file);
    } catch (e) {
      debugPrint("ERROR TAKE PICTURE: $e");
      showMessage("Gagal ambil foto: $e");
    }
  }

  Future<void> _submitPresensi() async {
    if (_capturedImage == null) {
      showMessage("Ambil foto selfie terlebih dahulu");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bytes = await File(_capturedImage!.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      debugPrint("Sending to API...");
      debugPrint("Lat: ${widget.latitude}, Lng: ${widget.longitude}");
      debugPrint("Token: ${widget.token.substring(0, 10)}...");

      final response = await myHttp.post(
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
      ).timeout(const Duration(seconds: 30));

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
      if (mounted) showMessage("Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _retake() {
    setState(() => _capturedImage = null);
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
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
            padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
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
                const SizedBox(height: 5),
                const Text(
                  "Langkah 2 dari 2 — Selfie",
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),

          // KAMERA / PREVIEW
          Expanded(child: _buildCameraArea()),

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
          Image.file(File(_capturedImage!.path), fit: BoxFit.cover),
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "✓ Foto siap dikirim",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!_isCameraReady || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text("Membuka kamera...", style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        Center(
          child: Container(
            width: 220,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white54, width: 2.5),
              borderRadius: BorderRadius.circular(140),
            ),
          ),
        ),
        const Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              "Posisikan wajah lalu tekan tombol",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isCameraReady ? _takePicture : null,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isCameraReady ? Colors.white : Colors.white24,
          border: Border.all(color: Colors.white54, width: 3),
        ),
        child: Icon(
          Icons.camera_alt,
          color: _isCameraReady ? Colors.black87 : Colors.white38,
          size: 32,
        ),
      ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isLoading ? null : _submitPresensi,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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