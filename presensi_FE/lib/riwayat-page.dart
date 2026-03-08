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

  List<Datum> riwayat = [];
  int totalHadir = 0;
  int totalTepat = 0;
  int totalTerlambat = 0;

  String selectedBulan = "Desember 2025";

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
      // Uri.parse('http://10.0.2.2:8000/api/get-presensi'),
      // Uri.parse('http://192.168.187.131:8000/api/get-presensi'),
      Uri.parse('http://3.27.35.240/api/get-presensi'),
      headers: headers,
    );

    var result = jsonDecode(response.body);
    HomeResponseModel model = HomeResponseModel.fromJson(result);

    riwayat.clear();
    totalHadir = 0;
    totalTepat = 0;
    totalTerlambat = 0;

    for (var element in model.data) {
      if (!element.isHariIni) {
        riwayat.add(element);
        totalHadir++;
        if (element.isTerlambat == true) {
          totalTerlambat++;
        } else {
          totalTepat++;
        }
      }
    }

    setState(() {}); // update UI setelah data diambil
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

                // Dropdown Bulan
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
                  child: DropdownButton<String>(
                    value: selectedBulan,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: ["Desember 2025"]
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedBulan = value!;
                      });
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
                if (riwayat.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("Belum ada riwayat"),
                    ),
                  )
                else
                  ...riwayat.map((item) {
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
                                item.tanggal,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 15),

                          // Jam
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
                                  terlambat
                                      ? "Terlambat"
                                      : "Tepat Waktu",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: terlambat
                                        ? Colors.orange
                                        : Colors.green,
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

  // ============================
  // Helper Widget
  // ============================

  Widget _modernSummary(String title, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15), // background sesuai warna
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