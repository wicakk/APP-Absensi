import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PerubahanDataPage extends StatelessWidget {
  const PerubahanDataPage({super.key});

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
            "Perubahan Data",
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
                  Tab(text: "Ajukan Perubahan"),
                  Tab(text: "Riwayat"),
                ],
              ),
            ),

            const Expanded(
              child: TabBarView(
                children: [
                  FormPerubahanData(),
                  RiwayatPerubahanData(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ================= FORM PERUBAHAN DATA =================

class FormPerubahanData extends StatefulWidget {
  const FormPerubahanData({super.key});

  @override
  State<FormPerubahanData> createState() => _FormPerubahanDataState();
}

class _FormPerubahanDataState extends State<FormPerubahanData> {
  final TextEditingController noHp = TextEditingController();
  final TextEditingController alamat = TextEditingController();
  final TextEditingController tanggalLahir = TextEditingController();
  final TextEditingController catatan = TextEditingController();

  String? jenisKelamin;
  File? foto;
  bool loading = false;
  String? token;

  //final String url = "http://192.168.187.131:8000/api/perubahan-data/ajukan";
  final String url = "http://${dotenv.env['APP_IP']}/api/perubahan-data/ajukan";

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      token = prefs.getString('token');
    });
  }

  Future<void> _pilihTanggal() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      tanggalLahir.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _pilihFoto() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null) {
      setState(() {
        foto = File(result.files.single.path!);
      });
    }
  }

  Future<void> _ajukanPerubahan() async {
    // Validasi minimal satu field diisi
    if (noHp.text.isEmpty &&
        alamat.text.isEmpty &&
        tanggalLahir.text.isEmpty &&
        jenisKelamin == null &&
        foto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Isi minimal satu data yang ingin diubah"),
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

      if (noHp.text.isNotEmpty) request.fields['no_hp'] = noHp.text;
      if (alamat.text.isNotEmpty) request.fields['alamat'] = alamat.text;
      if (tanggalLahir.text.isNotEmpty)
        request.fields['tanggal_lahir'] = tanggalLahir.text;
      if (jenisKelamin != null)
        request.fields['jenis_kelamin'] = jenisKelamin!;
      if (catatan.text.isNotEmpty) request.fields['catatan'] = catatan.text;

      if (foto != null) {
        request.files.add(
          await http.MultipartFile.fromPath('foto', foto!.path),
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
        noHp.clear();
        alamat.clear();
        tanggalLahir.clear();
        catatan.clear();
        setState(() {
          jenisKelamin = null;
          foto = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded['pesan'] ?? "Pengajuan gagal"),
            backgroundColor: Colors.red,
          ),
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
      child: Column(
        children: [
          /// INFO BANNER
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2962FF).withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF2962FF), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Isi field yang ingin diubah saja. Kosongkan field yang tidak perlu diperbarui.",
                    style: TextStyle(fontSize: 12, color: Color(0xFF2962FF)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          /// FORM CARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// FOTO
                const Text("Foto Profil", style: _labelStyle),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pilihFoto,
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: foto != null
                            ? const Color(0xFF2962FF)
                            : Colors.transparent,
                      ),
                    ),
                    child: foto != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(foto!, fit: BoxFit.cover,
                                width: double.infinity),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  color: Colors.grey, size: 32),
                              SizedBox(height: 6),
                              Text("Pilih Foto",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                /// NO HP
                const Text("No. HP", style: _labelStyle),
                const SizedBox(height: 6),
                TextField(
                  controller: noHp,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration(hint: "Contoh: 08123456789"),
                ),

                const SizedBox(height: 14),

                /// ALAMAT
                const Text("Alamat", style: _labelStyle),
                const SizedBox(height: 6),
                TextField(
                  controller: alamat,
                  maxLines: 3,
                  decoration: _inputDecoration(hint: "Masukkan alamat lengkap"),
                ),

                const SizedBox(height: 14),

                /// JENIS KELAMIN
                const Text("Jenis Kelamin", style: _labelStyle),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: jenisKelamin,
                  decoration: _inputDecoration(),
                  items: const [
                    DropdownMenuItem(value: "L", child: Text("Laki-laki")),
                    DropdownMenuItem(value: "P", child: Text("Perempuan")),
                  ],
                  onChanged: (value) => setState(() => jenisKelamin = value),
                ),

                const SizedBox(height: 14),

                /// TANGGAL LAHIR
                const Text("Tanggal Lahir", style: _labelStyle),
                const SizedBox(height: 6),
                TextField(
                  controller: tanggalLahir,
                  readOnly: true,
                  onTap: _pilihTanggal,
                  decoration: _inputDecoration(hint: "Pilih tanggal lahir"),
                ),

                const SizedBox(height: 14),

                /// CATATAN
                const Text("Catatan (opsional)", style: _labelStyle),
                const SizedBox(height: 6),
                TextField(
                  controller: catatan,
                  maxLines: 2,
                  decoration: _inputDecoration(
                      hint: "Catatan tambahan untuk admin"),
                ),

                const SizedBox(height: 20),

                /// SUBMIT
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : _ajukanPerubahan,
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
                            "Ajukan Perubahan",
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ================= RIWAYAT PERUBAHAN DATA =================

class RiwayatPerubahanData extends StatefulWidget {
  const RiwayatPerubahanData({super.key});

  @override
  State<RiwayatPerubahanData> createState() => _RiwayatPerubahanDataState();
}

class _RiwayatPerubahanDataState extends State<RiwayatPerubahanData>
    with AutomaticKeepAliveClientMixin {

  //final String url = "http://192.168.187.131/api/perubahan-data/riwayat";
  final String url = "http://${dotenv.env['APP_IP']}/api/perubahan-data/riwayat";

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

      debugPrint("Riwayat perubahan status: ${response.statusCode}");
      debugPrint("Riwayat perubahan body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
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

    setState(() => loading = false);
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
            Text("Belum ada riwayat perubahan data",
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
          return _RiwayatCard(item: riwayat[index]);
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

  Widget _infoRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$label: ",
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ),
        ],
      ),
    );
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
          /// Header: judul + badge status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Perubahan Data",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

          /// Data yang diubah
          _infoRow(Icons.phone_outlined, "No. HP", item['no_hp']),
          _infoRow(Icons.home_outlined, "Alamat", item['alamat']),
          _infoRow(Icons.wc_outlined, "Jenis Kelamin",
              item['jenis_kelamin'] == 'L' ? 'Laki-laki' : item['jenis_kelamin'] == 'P' ? 'Perempuan' : null),
          _infoRow(Icons.cake_outlined, "Tanggal Lahir", item['tanggal_lahir']),
          _infoRow(Icons.notes_outlined, "Catatan", item['catatan']),

          /// Catatan penolakan
          if (item['catatan_penolakan'] != null) ...[
            const SizedBox(height: 6),
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
                    child: Text(
                      item['catatan_penolakan'],
                      style:
                          const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          /// Tanggal pengajuan
          if (item['created_at'] != null)
            Text(
              "Diajukan: ${_formatDate(item['created_at'])}",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return "${dt.day.toString().padLeft(2, '0')} "
          "${_bulan(dt.month)} ${dt.year}";
    } catch (_) {
      return raw;
    }
  }

  String _bulan(int m) {
    const list = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return list[m];
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
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}