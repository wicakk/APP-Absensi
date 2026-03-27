import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as myHttp;
import 'package:shared_preferences/shared_preferences.dart';

// ===================== MODEL =====================
class Jadwal {
  final String hari;
  final String jamMasuk;
  final String jamPulang;
  final String durasi;

  Jadwal({
    required this.hari,
    required this.jamMasuk,
    required this.jamPulang,
    required this.durasi,
  });

  factory Jadwal.fromJson(Map<String, dynamic> json) {
    return Jadwal(
      hari: json['hari'] ?? '',
      jamMasuk: json['jam_masuk'] ?? '',
      jamPulang: json['jam_pulang'] ?? '',
      durasi: json['durasi'] ?? '',
    );
  }
}

// ===================== PAGE =====================
class JadwalPage extends StatefulWidget {
  const JadwalPage({super.key});

  @override
  State<JadwalPage> createState() => _JadwalPageState();
}

class _JadwalPageState extends State<JadwalPage> {
  List<Jadwal> _jadwalList = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _token = '';

  // Nama hari Indonesia untuk deteksi hari ini
  final List<String> _namaHari = [
    '', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
  ];

  String get _hariIni => _namaHari[DateTime.now().weekday];

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetch();
  }

  Future<void> _loadTokenAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token') ?? '';
    await _fetchJadwal();
  }

  Future<void> _fetchJadwal() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await myHttp.get(
        // Uri.parse('http://10.0.2.2:8000/api/jadwal'),
        // Uri.parse('http://192.168.187.131:8000/api/jadwal'),
        Uri.parse('http://${dotenv.env['APP_IP']}/api/jadwal'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final List data = result['data'];
          setState(() {
            _jadwalList = data.map((e) => Jadwal.fromJson(e)).toList();
          });
        } else {
          setState(() => _errorMessage = 'Gagal memuat jadwal');
        }
      } else {
        setState(() => _errorMessage = 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Tidak dapat terhubung ke server');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cari jadwal hari ini
    Jadwal? jadwalHariIni;
    try {
      jadwalHariIni = _jadwalList.firstWhere(
        (j) => j.hari.toLowerCase() == _hariIni.toLowerCase(),
      );
    } catch (_) {
      jadwalHariIni = null;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchJadwal,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
                  ? _buildError()
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Jadwal Kerja",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ===== CARD HARI INI =====
                          _buildCardHariIni(jadwalHariIni),

                          const SizedBox(height: 16),

                          // ===== LIST SEMUA JADWAL =====
                          ..._jadwalList.asMap().entries.map((entry) {
                            final index = entry.key + 1;
                            final jadwal = entry.value;
                            return _ScheduleCard(
                              day: jadwal.hari,
                              id: 'ID $index',
                              masuk: jadwal.jamMasuk,
                              pulang: jadwal.jamPulang,
                              durasi: jadwal.durasi,
                              isToday: jadwal.hari.toLowerCase() ==
                                  _hariIni.toLowerCase(),
                            );
                          }),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildCardHariIni(Jadwal? jadwal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D6CDF), Color(0xFF1E4FD8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Hari ini",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    _hariIni,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          jadwal == null
              ? const Text(
                  "Tidak ada jadwal hari ini",
                  style: TextStyle(color: Colors.white70),
                )
              : Row(
                  children: [
                    Expanded(child: _TimeBox("Masuk", jadwal.jamMasuk)),
                    const SizedBox(width: 8),
                    Expanded(child: _TimeBox("Pulang", jadwal.jamPulang)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 60, color: Colors.grey),
          const SizedBox(height: 12),
          Text(_errorMessage,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchJadwal,
            icon: const Icon(Icons.refresh),
            label: const Text("Coba Lagi"),
          ),
        ],
      ),
    );
  }
}

// ===================== WIDGETS =====================

class _TimeBox extends StatelessWidget {
  final String title;
  final String time;

  const _TimeBox(this.title, this.time);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final String day;
  final String id;
  final String masuk;
  final String pulang;
  final String durasi;
  final bool isToday;

  const _ScheduleCard({
    required this.day,
    required this.id,
    required this.masuk,
    required this.pulang,
    required this.durasi,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isToday
            ? Border.all(color: Colors.blue, width: 1.5)
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isToday ? Colors.blue : Colors.blue)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.calendar_month,
                    color: isToday ? Colors.blue : Colors.blue, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      day,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Hari ini",
                          style:
                              TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              Text(id,
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Badge("Masuk", masuk, Colors.green.shade100, Colors.green),
              _Badge(
                  "Pulang", pulang, Colors.orange.shade100, Colors.orange),
              _Badge("Durasi", durasi, Colors.grey.shade200, Colors.black54),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String title;
  final String value;
  final Color bgColor;
  final Color textColor;

  const _Badge(this.title, this.value, this.bgColor, this.textColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: textColor)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: textColor)),
        ],
      ),
    );
  }
}