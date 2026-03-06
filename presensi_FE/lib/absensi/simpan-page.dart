import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'facerecognition-page.dart';

class SimpanPage extends StatefulWidget {
  const SimpanPage({Key? key}) : super(key: key);

  @override
  State<SimpanPage> createState() => _SimpanPageState();
}

class _SimpanPageState extends State<SimpanPage> {
  bool isLoading = false;
  String _token = "";
  String _jamMasuk = "--:--";
  String _jamPulang = "--:--";

  late Future<Position?> _locationFuture;  // ← Position, bukan LocationData

  @override
  void initState() {
    super.initState();
    _loadToken();
    _locationFuture = _currentLocation();
    _fetchJamKerja();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _token = prefs.getString("token") ?? "";
      });
    }
  }

  Future<void> _fetchJamKerja() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";

    final response = await http.get(
      Uri.parse("http://192.168.187.131:8000/api/jadwal"), // ← 10.0.2.2 untuk emulator, ganti IP asli untuk device fisik
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List data = json['data'];

      // Ambil nama hari ini dalam Bahasa Indonesia
      const hariList = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
      final hariIni = hariList[DateTime.now().weekday % 7];

      // Cari jadwal yang sesuai hari ini
      final jadwal = data.firstWhere(
        (item) => item['hari'] == hariIni,
        orElse: () => null,
      );

      if (mounted) {
        setState(() {
          if (jadwal != null) {
            // Format "07:30:00" → "07:30"
            _jamMasuk = jadwal['jam_masuk'].toString().substring(0, 5);
            _jamPulang = jadwal['jam_pulang'].toString().substring(0, 5);
          } else {
            _jamMasuk = "Libur";
            _jamPulang = "Libur";
          }
        });
      }
    }
  } catch (e) {
    debugPrint("Gagal fetch jam kerja: $e");
  }
}

  Future<Position?> _currentLocation() async {  // ← Position
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
    } catch (e) {
      debugPrint("Error lokasi: $e");
      return null;
    }
  }

  String _formattedDateTime() {
    final now = DateTime.now();
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final tanggal =
        '${now.day.toString().padLeft(2, '0')} ${months[now.month]} ${now.year}';
    return '$tanggal ($_jamMasuk - $_jamPulang)';
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Position?>(  // ← Position
        future: _locationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Mendapatkan lokasi...",
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off, size: 60, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    "Lokasi tidak tersedia.\nPastikan GPS aktif.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _locationFuture = _currentLocation();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Coba Lagi"),
                  ),
                ],
              ),
            );
          }

          final currentLocation = snapshot.data!;

          return Column(
            children: [
              // HEADER MERAH
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
                    const Text(
                      "Clock In",
                      style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Langkah 1 dari 2",
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 10),
                          Text(
                            _formattedDateTime(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // MAP
              Expanded(
                child: SfMaps(
                  layers: [
                    MapTileLayer(
                      initialFocalLatLng: MapLatLng(
                        currentLocation.latitude,   // ← tanpa ! karena Position bukan nullable
                        currentLocation.longitude,
                      ),
                      initialZoomLevel: 15,
                      initialMarkersCount: 1,
                      urlTemplate:
                          "https://api.maptiler.com/maps/streets-v4/{z}/{x}/{y}.png?key=H706aZMoHXuQnUCZMGBZ",
                      markerBuilder: (context, index) {
                        return MapMarker(
                          latitude: currentLocation.latitude,
                          longitude: currentLocation.longitude,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        );
                      },
                    )
                  ],
                ),
              ),

              // TOMBOL LANJUTKAN
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2962FF), Color(0xFF0039CB)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FaceRecognitionPage(
                                  latitude: currentLocation.latitude,
                                  longitude: currentLocation.longitude,
                                  token: _token,
                                ),
                              ),
                            );
                          },
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Lanjutkan",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}