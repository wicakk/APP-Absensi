import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CutiPage extends StatelessWidget {
  const CutiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Color(0xFFF4F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            "Pengajuan Izin & Cuti",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        body: _Body(),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        /// SALDO CARD
        Container(
          margin: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2962FF),
                Color(0xFF0039CB),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [

              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.beach_access,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [

                    Text(
                      "Saldo Cuti Tahunan",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),

                    SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SaldoBox(title: "Total", value: "12"),
                        _SaldoBox(title: "Terpakai", value: "9"),
                        _SaldoBox(title: "Sisa", value: "3"),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),

        /// TAB
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(30),
          ),
          child: const TabBar(
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF2962FF),
                  Color(0xFF0039CB),
                ],
              ),
              borderRadius: BorderRadius.all(Radius.circular(30)),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.black54,
            tabs: [
              Tab(text: "Ajukan Baru"),
              Tab(text: "Riwayat"),
            ],
          ),
        ),

        const SizedBox(height: 8),

        const Expanded(
          child: TabBarView(
            children: [
              FormPengajuan(),
              RiwayatPengajuan(),
            ],
          ),
        )
      ],
    );
  }
}

/// ================= SALDO BOX =================

class _SaldoBox extends StatelessWidget {
  final String title;
  final String value;

  const _SaldoBox({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          )
        ],
      ),
    );
  }
}

/// ================= FORM =================

class FormPengajuan extends StatefulWidget {
  const FormPengajuan({super.key});

  @override
  State<FormPengajuan> createState() => _FormPengajuanState();
}

class _FormPengajuanState extends State<FormPengajuan> {

  final TextEditingController tanggalMulai = TextEditingController();
  final TextEditingController tanggalAkhir = TextEditingController();
  final TextEditingController alasan = TextEditingController();

  String? jenisCuti;
  File? file;
  bool loading = false;

  // Data dari SharedPreferences
  String? token;

  // final String url = "http://192.168.187.131:8000/api/ajukan-cuti";
  final String url = "http://3.27.35.240/api/ajukan-cuti";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Load token dari SharedPreferences
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      token = prefs.getString('token');
    });
  }

  /// DATE PICKER
  Future pilihTanggal(TextEditingController controller) async {

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      controller.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  /// FILE PICKER
  Future pilihFile() async {

    FilePickerResult? result =
        await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        file = File(result.files.single.path!);
      });
    }
  }

  /// API — user_id diambil dari token di sisi Laravel (auth()->user())
  Future ajukanCuti() async {

    setState(() {
      loading = true;
    });

    try {

      var uri = Uri.parse(url);
      var request = http.MultipartRequest("POST", uri);

      // Kirim token Bearer — user_id diambil di Laravel via auth()->user()
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['jenis_cuti'] = jenisCuti ?? "";
      request.fields['tanggal_mulai'] = tanggalMulai.text;
      request.fields['tanggal_akhir'] = tanggalAkhir.text;
      request.fields['alasan'] = alasan.text;

      // Hitung total_hari otomatis
      if (tanggalMulai.text.isNotEmpty && tanggalAkhir.text.isNotEmpty) {
        DateTime mulai = DateTime.parse(tanggalMulai.text);
        DateTime akhir = DateTime.parse(tanggalAkhir.text);
        int totalHari = akhir.difference(mulai).inDays + 1;
        request.fields['total_hari'] = totalHari.toString();
      }

      if (file != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', file!.path),
        );
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      // Debug log
      debugPrint("Status: ${response.statusCode}");
      debugPrint("Response: $responseBody");

      if (response.statusCode == 200 || response.statusCode == 201) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pengajuan berhasil"),
            backgroundColor: Colors.green,
          ),
        );

        // Reset form setelah berhasil
        tanggalMulai.clear();
        tanggalAkhir.clear();
        alasan.clear();
        setState(() {
          jenisCuti = null;
          file = null;
        });

      } else {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal: $responseBody"),
            backgroundColor: Colors.red,
          ),
        );

      }

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );

    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text("Jenis Cuti"),

            const SizedBox(height: 6),

            DropdownButtonFormField(
              value: jenisCuti,
              decoration: _inputDecoration(),
              items: const [
                DropdownMenuItem(
                    value: "Cuti Sakit",
                    child: Text("Cuti Sakit")),
                DropdownMenuItem(
                    value: "Izin",
                    child: Text("Izin")),
              ],
              onChanged: (value) {
                setState(() {
                  jenisCuti = value.toString();
                });
              },
            ),

            const SizedBox(height: 14),

            const Text("Tanggal"),

            const SizedBox(height: 6),

            Row(
              children: [

                Expanded(
                  child: TextField(
                    controller: tanggalMulai,
                    readOnly: true,
                    onTap: () => pilihTanggal(tanggalMulai),
                    decoration:
                        _inputDecoration(hint: "Tanggal Mulai"),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: TextField(
                    controller: tanggalAkhir,
                    readOnly: true,
                    onTap: () => pilihTanggal(tanggalAkhir),
                    decoration:
                        _inputDecoration(hint: "Tanggal Akhir"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            const Text("Alasan"),

            const SizedBox(height: 6),

            TextField(
              controller: alasan,
              maxLines: 3,
              decoration:
                  _inputDecoration(hint: "Masukkan alasan"),
            ),

            const SizedBox(height: 14),

            const Text("File Pendukung"),

            const SizedBox(height: 6),

            OutlinedButton.icon(
              onPressed: pilihFile,
              icon: const Icon(Icons.upload_file),
              label: Text(
                file == null
                    ? "Pilih File"
                    : file!.path.split('/').last, // tampilkan nama file
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : ajukanCuti,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text("Ajukan"),
              ),
            )
          ],
        ),
      ),
    );
  }
}

/// ================= RIWAYAT =================

class RiwayatPengajuan extends StatefulWidget {
  const RiwayatPengajuan({super.key});

  @override
  State<RiwayatPengajuan> createState() => _RiwayatPengajuanState();
}

class _RiwayatPengajuanState extends State<RiwayatPengajuan>
    with AutomaticKeepAliveClientMixin {

  //final String url = "http://192.168.187.131:8000/api/riwayat-cuti";
  final String url = "http://3.27.35.240/api/riwayat-cuti";

  List<dynamic> riwayat = [];
  bool loading = true;
  String? error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    fetchRiwayat();
  }

  Future<void> fetchRiwayat() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint("Riwayat status: ${response.statusCode}");
      debugPrint("Riwayat body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // Handle response berbentuk list atau {data: [...]}
          riwayat = data is List ? data : (data['data'] ?? []);
        });
      } else {
        setState(() {
          error = "Gagal memuat riwayat (${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        error = "Error: $e";
      });
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: fetchRiwayat,
              child: const Text("Coba Lagi"),
            ),
          ],
        ),
      );
    }

    if (riwayat.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text("Belum ada riwayat pengajuan",
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchRiwayat,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: riwayat.length,
        itemBuilder: (context, index) {
          final item = riwayat[index];
          return _RiwayatCard(item: item);
        },
      ),
    );
  }
}

/// ================= RIWAYAT CARD =================

class _RiwayatCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _RiwayatCard({required this.item});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
        return Colors.green;
      case 'ditolak':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
        return Icons.check_circle_outline;
      case 'ditolak':
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = item['status'] ?? 'pending';
    final color = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// Header: jenis cuti + badge status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item['jenis_cuti'] ?? '-',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(_statusIcon(status), color: color, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          /// Info tanggal & total hari
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                "${item['tanggal_mulai']} → ${item['tanggal_akhir']}",
                style:
                    const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${item['total_hari']} hari",
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          /// Alasan
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.notes_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item['alasan'] ?? '-',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
            ],
          ),

          /// Catatan penolakan (jika ada)
          if (item['catatan_penolakan'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item['catatan_penolakan'],
                      style: const TextStyle(
                          fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          /// Diajukan pada
          Text(
            "Diajukan: ${item['diajukan_pada'] ?? '-'}",
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// INPUT STYLE

InputDecoration _inputDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF2F4F7),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}