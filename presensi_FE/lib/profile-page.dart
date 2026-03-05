import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as myHttp;
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String name = "";
  String jabatan = "";
  String perusahaan = "";
  String token = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name      = prefs.getString("name")      ?? "Nama Tidak Ada";
      jabatan   = prefs.getString("jabatan")   ?? "Engineer Onsite";
      perusahaan = prefs.getString("perusahaan") ?? "PT. Amoro Technology Indonesia";
      token     = prefs.getString("token")     ?? "";
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ========== BOTTOM SHEET UBAH PASSWORD ==========
  void _showUbahPasswordDialog() {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final konfirmCtrl = TextEditingController();
    bool isLoading  = false;
    bool oldVisible = false;
    bool newVisible = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Ubah Kata Sandi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Minimal 6 karakter',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 20),

              // Password lama
              _buildPassField(
                controller: oldPassCtrl,
                label: 'Password Lama',
                visible: oldVisible,
                onToggle: () => setDialog(() => oldVisible = !oldVisible),
              ),
              const SizedBox(height: 12),

              // Password baru
              _buildPassField(
                controller: newPassCtrl,
                label: 'Password Baru',
                visible: newVisible,
                onToggle: () => setDialog(() => newVisible = !newVisible),
              ),
              const SizedBox(height: 12),

              // Konfirmasi
              _buildPassField(
                controller: konfirmCtrl,
                label: 'Konfirmasi Password Baru',
                visible: newVisible,
                onToggle: () => setDialog(() => newVisible = !newVisible),
              ),
              const SizedBox(height: 24),

              // Tombol simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (newPassCtrl.text != konfirmCtrl.text) {
                            showMessage('Konfirmasi password tidak cocok');
                            return;
                          }
                          if (newPassCtrl.text.length < 6) {
                            showMessage('Password minimal 6 karakter');
                            return;
                          }
                          setDialog(() => isLoading = true);
                          try {
                            final res = await myHttp.post(
                              Uri.parse('http://10.0.2.2:8000/api/ubah-password'),
                              headers: {
                                'Authorization': 'Bearer $token',
                                'Content-Type': 'application/json',
                              },
                              body: jsonEncode({
                                'password_lama': oldPassCtrl.text,
                                'password_baru': newPassCtrl.text,
                                'password_baru_confirmation': konfirmCtrl.text,
                              }),
                            );
                            final result = jsonDecode(res.body);
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            showMessage(result['message'] ?? 'Berhasil');
                          } catch (_) {
                            showMessage('Terjadi kesalahan koneksi');
                          } finally {
                            setDialog(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan',
                          style: TextStyle(fontSize: 15, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassField({
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: IconButton(
          icon: Icon(
            visible ? Icons.visibility_off : Icons.visibility,
            size: 18, color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ================= HEADER =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
              decoration: const BoxDecoration(
                color: Color(0xFFEDEAE6),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(jabatan,
                            style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text(perusahaan,
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    radius: 35,
                    backgroundImage: AssetImage("assets/profile.jpg"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ================= INFO SECTION =================
            _buildSectionCard(
              title: "Info saya",
              children: [
                _buildMenuTile(Icons.person_outline, "Info personal"),
                _buildMenuTile(Icons.badge_outlined, "Info pekerjaan"),
                _buildMenuTile(Icons.flag_outlined, "Info kontak darurat"),
                _buildMenuTile(Icons.groups_outlined, "Info keluarga"),
                _buildMenuTile(Icons.school_outlined, "Pendidikan dan Pengalaman"),
                _buildMenuTile(Icons.receipt_long_outlined, "Info payroll"),
                _buildMenuTile(Icons.info_outline, "Info tambahan"),
                _buildMenuTile(Icons.folder_open_outlined, "File saya"),
                _buildMenuTile(Icons.warning_amber_outlined, "Peringatan"),
              ],
            ),

            const SizedBox(height: 16),

            // ================= SETTINGS =================
            _buildSectionCard(
              title: "Pengaturan",
              children: [
                // ← Ubah kata sandi: bisa diklik → muncul bottom sheet
                _buildMenuTile(
                  Icons.lock_outline,
                  "Ubah kata sandi",
                  onTap: _showUbahPasswordDialog,
                ),
                _buildMenuTile(
                  Icons.pin_outlined,
                  "PIN",
                  trailingText: "Tidak aktif",
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ================= LOGOUT =================
            _buildSectionCard(
              title: "Akun",
              children: [
                _buildMenuTile(
                  Icons.logout_outlined,
                  "Keluar",
                  onTap: _logout,
                ),
              ],
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    IconData icon,
    String title, {
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(title),
      trailing: trailingText != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(trailingText,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}