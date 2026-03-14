import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:presensi_FE/models/home-response.dart';
import 'package:presensi_FE/absensi/simpan-page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as myHttp;
import 'riwayat-page.dart';
import 'navbutton-page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  String name = "";
  bool isLoading = true;

  HomeResponseModel? homeResponseModel;
  Datum? hariIni;
  List<Datum> riwayat = [];
  List<Map<String, dynamic>> pengumuman = []; // ✅ Tambah ini

  @override
  void initState() {
    super.initState();
    initData();
  }

  Future<void> initData() async {
    await getUser();
    await getData();
    await getPengumuman(); // ✅ Tambah ini
  }

  Future<void> getUser() async {
    final prefs = await _prefs;
    name = prefs.getString("name") ?? "";
  }

  Future<void> getData() async {
    try {
      setState(() => isLoading = true);

      final prefs = await _prefs;
      String token = prefs.getString("token") ?? "";

      var response = await myHttp.get(
        Uri.parse('http://54.252.215.200/api/get-presensi'),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        homeResponseModel = HomeResponseModel.fromJson(result);

        hariIni = null;
        riwayat.clear();

        for (var element in homeResponseModel?.data ?? []) {
          if (element.isHariIni) {
            hariIni = element;
          } else {
            riwayat.add(element);
          }
        }
      }
    } catch (e) {
      debugPrint("ERROR getData: $e");
    }

    setState(() => isLoading = false);
  }

  // ✅ Fetch pengumuman dari API
  Future<void> getPengumuman() async {
    try {
      final prefs = await _prefs;
      String token = prefs.getString("token") ?? "";

      var response = await myHttp.get(
        Uri.parse('http://54.252.215.200/api/pengumuman'),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        setState(() {
          pengumuman = List<Map<String, dynamic>>.from(result['data']);
        });
      }
    } catch (e) {
      debugPrint("ERROR getPengumuman: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  await getData();
                  await getPengumuman();
                },
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ================= HEADER =================
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Halo,", style: TextStyle(fontSize: 16)),
                        Text(
                          name.isEmpty ? "-" : name,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    _buildTimeCard(context),
                    const SizedBox(height: 20),
                    _buildStatusCard(),
                    const SizedBox(height: 15),
                    _buildLocationCard(),
                    const SizedBox(height: 20),
                    _buildAbsenButton(),
                    const SizedBox(height: 30),
                    _buildRiwayatSection(),
                    const SizedBox(height: 30),
                    _buildPengumumanSection(), // ✅ Sekarang dinamis
                  ],
                ),
              ),
            ),
    );
  }

  // ================= TIME CARD =================
  Widget _buildTimeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2962FF), Color(0xFF0039CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.access_time, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Waktu Saat Ini",
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 5),
              Text(
                TimeOfDay.now().format(context),
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= STATUS =================
  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(
            hariIni == null ? Icons.info : Icons.check_circle,
            color: hariIni == null ? Colors.grey : Colors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hariIni == null
                  ? "Belum Absen"
                  : "Masuk: ${hariIni?.masuk ?? '-'} | Pulang: ${hariIni?.pulang ?? '-'}",
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ================= LOCATION =================
  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: const Row(
        children: [
          Icon(Icons.location_on, color: Colors.blue),
          SizedBox(width: 10),
          Text("Kantor Pusat, Jakarta",
              style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ================= ABSEN BUTTON =================
  Widget _buildAbsenButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              hariIni == null ? const Color(0xFF00C853) : const Color(0xFFD50000),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SimpanPage()),
          );
          await getData();
        },
        child: Text(
          hariIni == null ? "Absen Masuk" : "Absen Keluar",
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  // ================= RIWAYAT =================
  Widget _buildRiwayatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Riwayat Presensi",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        if (riwayat.isEmpty)
          const Center(child: Text("Belum ada riwayat"))
        else
          ...riwayat.take(2).map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          flex: 2,
                          child: Text(item.tanggal ?? "-",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(
                          child: Text(item.masuk ?? "-",
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(
                          child: Text(item.pulang ?? "-",
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Expanded(flex: 2, child: SizedBox()),
                      Expanded(
                          child: Text("Masuk",
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey))),
                      Expanded(
                          child: Text("Pulang",
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey))),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  // ================= PENGUMUMAN =================
  Widget _buildPengumumanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Pengumuman",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        if (pengumuman.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Row(
              children: [
                Icon(Icons.campaign, color: Color(0xFF2962FF)),
                SizedBox(width: 12),
                Text("Tidak ada pengumuman", style: TextStyle(fontSize: 14)),
              ],
            ),
          )
        else
          ...pengumuman.map((item) {
            // Badge warna berdasarkan prioritas
            Color badgeColor = Colors.grey;
            if (item['prioritas'] == 'tinggi') badgeColor = Colors.red;
            if (item['prioritas'] == 'sedang') badgeColor = Colors.orange;
            if (item['prioritas'] == 'rendah') badgeColor = Colors.green;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: badgeColor.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.campaign, color: const Color(0xFF2962FF)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Judul + badge prioritas
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['judul'] ?? "-",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            if (item['prioritas'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item['prioritas'],
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: badgeColor,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Isi
                        Text(
                          item['isi'] ?? "-",
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87),
                        ),
                        const SizedBox(height: 6),
                        // Tanggal
                        if (item['tanggal_mulai'] != null)
                          Text(
                            "📅 ${item['tanggal_mulai']}${item['tanggal_berakhir'] != null ? ' – ${item['tanggal_berakhir']}' : ''}",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }
}