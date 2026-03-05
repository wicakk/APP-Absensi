import 'package:flutter/material.dart';

class CutiPage extends StatelessWidget {
  const CutiPage({super.key});

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
          title: const Text(
            "Pengajuan Izin & Cuti",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        body: Column(
          children: [

            /// ================= SALDO CARD =================
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
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
                      size: 24,
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

            /// ================= TAB =================
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2962FF),
                      Color(0xFF0039CB),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black54,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: "Ajukan Baru"),
                  Tab(text: "Riwayat"),
                ],
              ),
            ),

            const SizedBox(height: 8),

            const Expanded(
              child: TabBarView(
                children: [
                  _FormPengajuan(),
                  _RiwayatPengajuan(),
                ],
              ),
            )
          ],
        ),
      ),
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

class _FormPengajuan extends StatelessWidget {
  const _FormPengajuan();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _label("Jenis Surat"),
            const SizedBox(height: 6),

            DropdownButtonFormField(
              decoration: _inputDecoration(),
              items: const [
                DropdownMenuItem(value: "Cuti Sakit", child: Text("Cuti Sakit")),
                DropdownMenuItem(value: "Izin", child: Text("Izin")),
              ],
              onChanged: (value) {},
            ),

            const SizedBox(height: 14),

            _label("Tanggal"),
            const SizedBox(height: 6),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: _inputDecoration(hint: "Tanggal Mulai"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    decoration: _inputDecoration(hint: "Tanggal Akhir"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            _label("Keterangan / Alasan"),
            const SizedBox(height: 6),

            TextField(
              maxLines: 3,
              decoration: _inputDecoration(hint: "Jelaskan alasan..."),
            ),

            const SizedBox(height: 14),

            _label("Berkas Pendukung (Opsional)"),
            const SizedBox(height: 6),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {},
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text("Pilih File"),
            ),

            const SizedBox(height: 18),

            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey, // warna background
                    foregroundColor: Colors.white, // warna teks
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                    ),
                    ),
                    onPressed: () {},
                    child: const Text("Ajukan"),
                ),
            )
          ],
        ),
      ),
    );
  }
}

/// ================= RIWAYAT =================

class _RiwayatPengajuan extends StatelessWidget {
  const _RiwayatPengajuan();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Cuti Sakit",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Disetujui",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 8),
              const Text(
                "4 Desember 2025 - 5 Desember 2025",
                style: TextStyle(color: Colors.black54),
              ),

              const SizedBox(height: 4),
              const Text(
                "Keterangan: Meriang",
                style: TextStyle(color: Colors.black87),
              ),

              const SizedBox(height: 4),
              const Text(
                "Diajukan pada 4 Des 2025",
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        )
      ],
    );
  }
}

/// ================= HELPERS =================

Widget _label(String text) {
  return Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 13,
    ),
  );
}

InputDecoration _inputDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF2F4F7),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}