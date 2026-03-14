import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:http/http.dart' as myHttp;
import 'facerecognition-page.dart'; // ← tambahkan ini

class SimpanPage extends StatefulWidget {
  const SimpanPage({Key? key}) : super(key: key);

  @override
  State<SimpanPage> createState() => _SimpanPageState();
}

class _SimpanPageState extends State<SimpanPage> {
  bool isLoading = false;
  String _token = "";

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString("token") ?? "";
    });
  }

  Future<LocationData?> _currentLocation() async {
    Location location = Location();

    bool serviceEnable = await location.serviceEnabled();
    if (!serviceEnable) {
      serviceEnable = await location.requestService();
      if (!serviceEnable) return null;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return null;
    }

    return await location.getLocation();
  }

  // Future<void> savePresensi(double? latitude, double? longitude) async {
  //   if (latitude == null || longitude == null) {
  //     showMessage("Lokasi tidak tersedia");
  //     return;
  //   }

  //   setState(() => isLoading = true);

  //   try {
  //     var response = await myHttp.post(
  //       Uri.parse('http://10.0.2.2:8000/api/save-presensi'),
  //       headers: {
  //         "Authorization": "Bearer $_token",
  //         "Content-Type": "application/json",
  //       },
  //       body: jsonEncode({
  //         "latitude": latitude,
  //         "longitude": longitude,
  //       }),
  //     );

  //     print("STATUS CODE: ${response.statusCode}");
  //     print("BODY: ${response.body}");

  //     if (!mounted) return;

  //     var result = jsonDecode(response.body);
  //     showMessage(result["message"] ?? "Terjadi kesalahan");

  //     if (result["success"] == true) {
  //       Navigator.pop(context);
  //     }
  //   } catch (e) {
  //     print("ERROR SIMPAN: $e");
  //     print("ERROR SIMPAN DETAIL: ${e.toString()}");
  //     print("TOKEN: $_token");
  //     if (mounted) showMessage("Terjadi kesalahan koneksi");
  //   } finally {
  //     if (mounted) setState(() => isLoading = false);
  //   }
  // }

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
      body: FutureBuilder<LocationData?>(
        future: _currentLocation(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text("Lokasi tidak tersedia.\nPastikan GPS aktif.",
                  textAlign: TextAlign.center),
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
                        children: const [
                          Icon(Icons.calendar_today,
                              size: 18, color: Colors.grey),
                          SizedBox(width: 10),
                          Text(
                            "01 Mar 2026 (00:00 - 00:00)",
                            style: TextStyle(fontWeight: FontWeight.bold),
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
                        currentLocation.latitude!,
                        currentLocation.longitude!,
                      ),
                      initialZoomLevel: 15,
                      initialMarkersCount: 1,
                      urlTemplate:
                          "https://api.maptiler.com/maps/streets-v4/{z}/{x}/{y}.png?key=H706aZMoHXuQnUCZMGBZ",
                      markerBuilder: (context, index) {
                        return MapMarker(
                          latitude: currentLocation.latitude!,
                          longitude: currentLocation.longitude!,
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
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  // ✅ SESUDAH
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FaceRecognitionPage(
                                latitude: currentLocation.latitude!,
                                longitude: currentLocation.longitude!,
                                token: _token,
                              ),
                            ),
                          );
                        },
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Lanjutkan",
                          style: TextStyle(fontSize: 16)),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
