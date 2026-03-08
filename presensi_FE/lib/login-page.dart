import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as myHttp;
import 'package:presensi_FE/models/login-response.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool checkingToken = true;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  void _checkToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    final name = prefs.getString("name") ?? "";

    if (!mounted) return;

    if (token.isNotEmpty && name.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        checkingToken = false;
      });
    }
  }

  Future<void> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      showMessage("Email dan password wajib diisi");
      return;
    }

    setState(() => isLoading = true);

    try {
      var response = await myHttp.post(
        // Uri.parse('http://10.0.2.2:8000/api/login'),
        // Uri.parse('http://192.168.187.131:8000/api/login'),
        Uri.parse('http://3.27.35.240/api/login'),
        body: {"email": email, "password": password},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final loginResponseModel =
            LoginResponseModel.fromJson(json.decode(response.body));

        if (loginResponseModel.success && loginResponseModel.data != null) {
          final userData = loginResponseModel.data!;
          await saveUser(userData.token, userData.name);

          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          showMessage(loginResponseModel.message);
        }
      } else {
        showMessage("Email atau password salah");
      }
    } catch (e) {
      if (mounted) showMessage("Terjadi kesalahan koneksi");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> saveUser(String token, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("name", name);
    await prefs.setString("token", token);
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (checkingToken) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1E3C72),
              Color(0xFF2A5298),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Logo
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    size: 55,
                    color: Color(0xFF2A5298),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  "Aplikasi Presensi",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 40),

                // Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 20),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      // Email
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon:
                              const Icon(Icons.email_outlined),
                          hintText: "Masukkan Email",
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Password
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          prefixIcon:
                              const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                          hintText: "Masukkan Password",
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () => login(
                                  emailController.text.trim(),
                                  passwordController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2A5298),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,)
                              : const Text(
                                  "Masuk",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}