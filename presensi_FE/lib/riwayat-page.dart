import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as myHttp;
import 'models/home-response.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  late Future<String> _token;
  late Future<void> _future;

  List<Datum> allRiwayat = []; // semua data dari API
  List<Datum> filteredRiwayat = []; // data setelah filter bulan

  List<String> bulanList = []; // daftar bulan yang tersedia
  String? selectedBulan; // bulan yang dipilih

  int totalHadir = 0;
  int totalTepat = 0;
  int totalTerlambat = 0;

  // Map bulan angka → nama Indonesia
  static const _namaBulan = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _token = _prefs.then((prefs) => prefs.getString("token") ?? "");
    _future = getData();
  }

  Future<void> getData() async {
    final headers = {
      'Authorization': 'Bearer ${await _token}',
    };

    var response = await myHttp.get(
      Uri.parse('http://${dotenv.env['APP_IP']}/api/get-presensi'),
      headers: headers,
    );

    var result = jsonDecode(response.body);
    HomeResponseModel model = HomeResponseModel.fromJson(result);

    allRiwayat.clear();

    for (var element in model.data) {
      if (!element.isHariIni) {
        allRiwayat.add(element);
      }
    }

    // Generate daftar bulan unik dari data, diurutkan terbaru dulu
    final bulanSet = <String>{};
    for (var item in allRiwayat) {
      final key = _getBulanKey(item.tanggal);
      if (key != null) bulanSet.add(key);
    }

    bulanList = bulanSet.toList()
      ..sort((a, b) {
        // Sort descending: bulan terbaru di atas
        final partsA = a.split('-');
        final partsB = b.split('-');
        final dateA = DateTime(int.parse(partsA[0]), int.parse(partsA[1]));
        final dateB = DateTime(int.parse(partsB[0]), int.parse(partsB[1]));
        return dateB.compareTo(dateA);
      });

    // Default pilih bulan terbaru
    if (bulanList.isNotEmpty) {
      selectedBulan = bulanList.first;
    }

    _filterByBulan();
  }

  // Ambil key "yyyy-MM" dari tanggal "yyyy-MM-dd"
  String? _getBulanKey(String tanggal) {
    try {
      final parts = tanggal.split('-');
      if (parts.length >= 2) return '${parts[0]}-${parts[1]}';
    } catch (_) {}
    return null;
  }

  // Format key "yyyy-MM" → label "Desember 2025"
  String _formatBulanLabel(String key) {
    try {
      final parts = key.split('-');
      final bulan = int.parse(parts[1]);
      final tahun = parts[0];
      return '${_namaBulan[bulan]} $tahun';
    } catch (_) {
      return key;
    }
  }

  // Format tanggal "2025-12-01" → "01 Desember 2025"
  String _formatTanggal(String tanggal) {
    try {
      final parts = tanggal.split('-');
      final hari = parts[2].padLeft(2, '0');
      final bulan = int.parse(parts[1]);
      final tahun = parts[0];
      return '$hari ${_namaBulan[bulan]} $tahun';
    } catch (_) {
      return tanggal;
    }
  }

  void _filterByBulan() {
    if (selectedBulan == null) {
      filteredRiwayat = List.from(allRiwayat);
    } else {
      filteredRiwayat = allRiwayat
          .where((item) => _getBulanKey(item.tanggal) == selectedBulan)
          .toList();

      // Urutkan terbaru di atas
      filteredRiwayat.sort((a, b) => b.tanggal.compareTo(a.tanggal));
    }

    // Hitung summary
    totalHadir = filteredRiwayat.length;
    totalTerlambat = filteredRiwayat.where((e) => e.isTerlambat == true).length;
    totalTepat = totalHadir - totalTerlambat;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: const Text("Riwayat Absensi"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async => await getData(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // Dropdown Bulan — otomatis dari data API
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: bulanList.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text("Tidak ada data", style: TextStyle(color: Colors.grey)),
                        )
                      : DropdownButton<String>(
                          value: selectedBulan,
                          isExpanded: true,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.keyboard_arrow_down),
                          items: bulanList.map((key) {
                            return DropdownMenuItem(
                              value: key,
                              child: Text(_formatBulanLabel(key)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedBulan = value);
                            _filterByBulan();
                          },
                        ),
                ),

                const SizedBox(height: 20),

                // Summary
                Row(
                  children: [
                    _modernSummary("Hadir", totalHadir, Colors.blue),
                    _modernSummary("Tepat", totalTepat, Colors.green),
                    _modernSummary("Terlambat", totalTerlambat, Colors.orange),
                  ],
                ),

                const SizedBox(height: 25),

                // List Riwayat
                if (filteredRiwayat.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("Belum ada riwayat di bulan ini"),
                    ),
                  )
                else
                  ...filteredRiwayat.map((item) {
                    bool terlambat = item.isTerlambat == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Tanggal
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                _formatTanggal(item.tanggal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 15),

                          // Jam & Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _timeColumn("Masuk", item.masuk),
                              _timeColumn("Pulang", item.pulang),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: terlambat
                                      ? Colors.orange.withOpacity(0.15)
                                      : Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  terlambat ? "Terlambat" : "Tepat Waktu",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: terlambat ? Colors.orange : Colors.green,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList()
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _modernSummary(String title, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _timeColumn(String label, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          time,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}