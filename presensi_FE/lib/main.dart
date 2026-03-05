import 'package:flutter/material.dart';
import 'navbutton-page.dart';
import 'pengajuan/cuti-page.dart';
import 'login-page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login', // ← mulai dari login
      routes: {
        '/': (context) => MainPage(),
        '/cuti': (context) => CutiPage(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => MainPage(), // ← Tambahkan ini
      },
    );
  }
}