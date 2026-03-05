import 'package:flutter/material.dart';

class InfoPersonalPage extends StatelessWidget {
  final Map<String, dynamic> pegawai;

  const InfoPersonalPage({super.key, required this.pegawai});

  @override
  Widget build(BuildContext context) {
    // Data sudah flat dari ProfilePage (sudah di-extract json['data'])
    final data = pegawai;

    final name       = data['name']                           ?? '-';
    final jabatan    = data['jabatan']?['nama_jabatan']       ?? '-';
    final departemen = data['departemen']?['nama_departemen'] ?? '-';
    final status     = data['status_pegawai']                 ?? '-';
    final foto       = data['foto'];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Info Personal',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ===== AVATAR & NAMA =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: foto != null
                        ? NetworkImage(foto) as ImageProvider
                        : null,
                    backgroundColor: Colors.blue.shade100,
                    child: foto == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(jabatan,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'aktif'
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: status == 'aktif'
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ===== DATA DIRI =====
            _buildCard(
              title: 'Data Diri',
              items: [
                _InfoItem(
                    icon: Icons.badge_outlined,
                    label: 'NIP',
                    value: data['nip']),
                _InfoItem(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: data['email']),
                _InfoItem(
                    icon: Icons.phone_outlined,
                    label: 'No. HP',
                    value: data['no_hp']),
                _InfoItem(
                    icon: Icons.wc_outlined,
                    label: 'Jenis Kelamin',
                    value: data['jenis_kelamin'] == 'L'
                        ? 'Laki-laki'
                        : data['jenis_kelamin'] == 'P'
                            ? 'Perempuan'
                            : '-'),
                _InfoItem(
                    icon: Icons.cake_outlined,
                    label: 'Tanggal Lahir',
                    value: data['tanggal_lahir']),
                _InfoItem(
                    icon: Icons.home_outlined,
                    label: 'Alamat',
                    value: data['alamat']),
              ],
            ),

            const SizedBox(height: 16),

            // ===== INFO PEKERJAAN =====
            _buildCard(
              title: 'Info Pekerjaan',
              items: [
                _InfoItem(
                    icon: Icons.business_outlined,
                    label: 'Departemen',
                    value: departemen),
                _InfoItem(
                    icon: Icons.work_outline,
                    label: 'Jabatan',
                    value: jabatan),
                _InfoItem(
                    icon: Icons.calendar_today_outlined,
                    label: 'Tanggal Masuk',
                    value: data['tanggal_masuk']),
              ],
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required List<_InfoItem> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...items.map((item) => _buildRow(item)),
        ],
      ),
    );
  }

  Widget _buildRow(_InfoItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 20, color: Colors.blue.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  (item.value != null &&
                          item.value.toString().isNotEmpty)
                      ? item.value.toString()
                      : '-',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final dynamic value;

  const _InfoItem(
      {required this.icon, required this.label, required this.value});
}