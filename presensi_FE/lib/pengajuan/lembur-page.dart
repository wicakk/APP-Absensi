import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LemburPage extends StatelessWidget {
  const LemburPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Pengajuan Lembur",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        body: Column(
          children: [
            /// TAB
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                    colors: [Color(0xFF2962FF), Color(0xFF0039CB)],
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

            const Expanded(
              child: TabBarView(
                children: [
                  FormLembur(),
                  RiwayatLembur(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ================= FORM LEMBUR =================

class FormLembur extends StatefulWidget {
  const FormLembur({super.key});

  @override
  State<FormLembur> createState() => _FormLemburState();
}

class _FormLemburState extends State<FormLembur> {
  final TextEditingController tanggalLembur = TextEditingController();
  final TextEditingController jamMulai = TextEditingController();
  final TextEditingController jamSelesai = TextEditingController();
  final TextEditingController alasan = TextEditingController();

  File? file;
  bool loading = false;
  String? token;

  // final String url = "http://192.168.187.131:8000/api/ajukan-lembur";
  final String url = "http://54.252.215.200/api/ajukan-lembur";

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => token = prefs.getString('token'));
  }

  /// Total jam preview
  String get _totalJamPreview {
    if (jamMulai.text.isEmpty || jamSelesai.text.isEmpty) return "-";
    try {
      final mulai = _parseTime(jamMulai.text);
      var selesai = _parseTime(jamSelesai.text);
      if (selesai.isBefore(mulai)) {
        selesai = selesai.add(const Duration(days: 1));
      }
      final diff = selesai.difference(mulai);
      final jam = diff.inHours;
      final menit = diff.inMinutes % 60;
      return menit > 0 ? "$jam jam $menit menit" : "$jam jam";
    } catch (_) {
      return "-";
    }
  }

  DateTime _parseTime(String time) {
    final parts = time.split(':');
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]));
  }

  Future<void> _pilihTanggal() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      tanggalLembur.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _pilihJam(TextEditingController controller) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      controller.text =
          "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      setState(() {}); // update preview total jam
    }
  }

  Future<void> _pilihFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null) {
      setState(() => file = File(result.files.single.path!));
    }
  }

  Future<void> _ajukanLembur() async {
    if (tanggalLembur.text.isEmpty ||
        jamMulai.text.isEmpty ||
        jamSelesai.text.isEmpty ||
        alasan.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Semua field wajib diisi"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      var uri = Uri.parse(url);
      var request = http.MultipartRequest("POST", uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['tanggal_lembur'] = tanggalLembur.text;
      request.fields['jam_mulai'] = jamMulai.text;
      request.fields['jam_selesai'] = jamSelesai.text;
      request.fields['alasan'] = alasan.text;

      if (file != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', file!.path),
        );
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      debugPrint("Status: ${response.statusCode}");
      debugPrint("Response: $responseBody");

      final decoded = jsonDecode(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded['pesan'] ?? "Pengajuan berhasil"),
            backgroundColor: Colors.green,
          ),
        );

        // Reset form
        tanggalLembur.clear();
        jamMulai.clear();
        jamSelesai.clear();
        alasan.clear();
        setState(() => file = null);
      } else {
        final errors = decoded['errors'];
        String errorMsg = decoded['pesan'] ?? "Pengajuan gagal";
        if (errors != null) {
          errorMsg = (errors as Map).values.first[0];
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => loading = false);
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

            /// TANGGAL LEMBUR
            const Text("Tanggal Lembur", style: _labelStyle),
            const SizedBox(height: 6),
            TextField(
              controller: tanggalLembur,
              readOnly: true,
              onTap: _pilihTanggal,
              decoration: _inputDecoration(hint: "Pilih tanggal"),
            ),

            const SizedBox(height: 14),

            /// JAM MULAI & SELESAI
            const Text("Jam Lembur", style: _labelStyle),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: jamMulai,
                    readOnly: true,
                    onTap: () => _pilihJam(jamMulai),
                    decoration: _inputDecoration(hint: "Jam Mulai"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: jamSelesai,
                    readOnly: true,
                    onTap: () => _pilihJam(jamSelesai),
                    decoration: _inputDecoration(hint: "Jam Selesai"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            /// TOTAL JAM PREVIEW
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      color: Color(0xFF2962FF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Total lembur: $_totalJamPreview",
                    style: const TextStyle(
                      color: Color(0xFF2962FF),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            /// ALASAN
            const Text("Alasan", style: _labelStyle),
            const SizedBox(height: 6),
            TextField(
              controller: alasan,
              maxLines: 3,
              decoration: _inputDecoration(hint: "Masukkan alasan lembur"),
            ),

            const SizedBox(height: 14),

            /// FILE PENDUKUNG
            const Text("File Pendukung (opsional)", style: _labelStyle),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pilihFile,
              icon: const Icon(Icons.upload_file),
              label: Text(
                file == null ? "Pilih File (PDF/JPG/PNG)" : file!.path.split('/').last,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 20),

            /// SUBMIT
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _ajukanLembur,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Ajukan Lembur",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ================= RIWAYAT LEMBUR =================

class RiwayatLembur extends StatefulWidget {
  const RiwayatLembur({super.key});

  @override
  State<RiwayatLembur> createState() => _RiwayatLemburState();
}

class _RiwayatLemburState extends State<RiwayatLembur>
    with AutomaticKeepAliveClientMixin {

  //final String url = "http://192.168.187.131:8000/api/riwayat-lembur";
  final String url = "http://54.252.215.200/api/riwayat-lembur";

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

      debugPrint("Riwayat lembur: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          riwayat = data is List ? data : (data['data'] ?? []);
        });
      } else {
        setState(() => error = "Gagal memuat riwayat (${response.statusCode})");
      }
    } catch (e) {
      setState(() => error = "Error: $e");
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (loading) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: fetchRiwayat, child: const Text("Coba Lagi")),
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
            Text("Belum ada riwayat lembur",
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
        itemBuilder: (context, index) => _RiwayatCard(item: riwayat[index]),
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
      case 'disetujui': return Colors.green;
      case 'ditolak': return Colors.red;
      default: return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui': return Icons.check_circle_outline;
      case 'ditolak': return Icons.cancel_outlined;
      default: return Icons.hourglass_empty;
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

          /// Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item['tanggal_lembur'] ?? '-',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          /// Jam
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                "${item['jam_mulai']} - ${item['jam_selesai']}",
                style: const TextStyle(fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${item['total_jam']} jam",
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2962FF)),
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

          /// Catatan penolakan
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
                  const Icon(Icons.info_outline, size: 14, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(item['catatan_penolakan'],
                        style: const TextStyle(fontSize: 12, color: Colors.red)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          Text(
            "Diajukan: ${item['diajukan_pada'] ?? '-'}",
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// ================= HELPERS =================

const _labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);

InputDecoration _inputDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF2F4F7),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}