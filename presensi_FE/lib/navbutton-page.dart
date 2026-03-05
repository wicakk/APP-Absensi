import 'package:flutter/material.dart';
import 'home-page.dart';
import 'riwayat-page.dart';
import 'profile-page.dart';
import 'jadwal-page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  // Jangan const karena HomePage dll kemungkinan StatefulWidget
  final List<Widget> _pages = [
    HomePage(),
    RiwayatPage(),
    JadwalPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      // ================= FLOATING BUTTON =================
      floatingActionButton: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF2962FF), Color(0xFF0039CB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FloatingActionButton(
          onPressed: _showPengajuanSheet,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, size: 28, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ================= BOTTOM NAV =================
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home, 0),
              _navItem(Icons.history, 1),
              const SizedBox(width: 40), // space untuk FAB
              _navItem(Icons.calendar_month, 2),
              _navItem(Icons.person, 3),
            ],
          ),
        ),
      ),
    );
  }

  // ================= NAV ITEM =================
  Widget _navItem(IconData icon, int index) {
    final isActive = _currentIndex == index;

    return IconButton(
      icon: isActive
          ? ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF2962FF), Color(0xFF0039CB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: Icon(icon, color: Colors.white), // warna putih di ShaderMask akan diwarnai gradient
            )
          : Icon(icon, color: Colors.grey),
      onPressed: () {
        setState(() => _currentIndex = index);
      },
    );
  }

  // ================= BOTTOM SHEET =================
  void _showPengajuanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Ajukan untuk",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 15),

            _sheetItem(icon: Icons.receipt_long, title: "Reimbursement"),
            _sheetItem(icon: Icons.event, title: "Cuti", routeName: '/cuti'),
            _sheetItem(icon: Icons.location_on, title: "Absensi"),
            _sheetItem(icon: Icons.work_outline, title: "Perubahan Shift"),
            _sheetItem(icon: Icons.access_time, title: "Lembur"),
            _sheetItem(icon: Icons.person_outline, title: "Perubahan Data"),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ================= SHEET ITEM =================
  Widget _sheetItem({
    required IconData icon,
    required String title,
    String? routeName,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(context); // tutup sheet

        if (routeName != null) {
          Navigator.pushNamed(context, routeName);
        }
      },
    );
  }
}