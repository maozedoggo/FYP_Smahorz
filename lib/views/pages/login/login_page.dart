import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_horizon_home/views/pages/forgot_password/forgot_password.dart';
import 'package:smart_horizon_home/views/pages/home_page.dart';
import 'package:smart_horizon_home/views/pages/signup/signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController loginIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool showPassword = false;

  @override
  void dispose() {
    loginIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _showPopup(String title, String message) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87, // darker dialog to match theme
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (loginIdController.text.isEmpty || passwordController.text.isEmpty) {
      _showPopup("Error", "Please enter email/username & password");
      return;
    }

    String loginInput = loginIdController.text.trim();
    String password = passwordController.text.trim();
    String emailToUse = loginInput;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator(
          color: Colors.blue,
          backgroundColor: Colors.transparent,
        ));
      },
    );

    try {
      // Check if input is a username (not email)
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(loginInput)) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: loginInput)
            .get();

        if (!mounted) return;

        if (querySnapshot.docs.isEmpty) {
          Navigator.pop(context); // close loading dialog
          _showPopup("Error", "No user found with this username");
          return;
        }

        emailToUse = querySnapshot.docs.first.get('email');
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );

      Navigator.pop(context); // close loading dialog
      _showPopup("Success", "Login successful!");

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context); // close loading dialog
      String message = "Login failed. Incorrect email/username or password. Please try again.";
      if (e.code == 'user-not-found') {
        message = "No user found with this email";
      } else if (e.code == 'wrong-password') {
        message = "Wrong password";
      }
      _showPopup("Error", message);
    } catch (e) {
      Navigator.pop(context); // close loading dialog
      _showPopup("Error", "An unexpected error occurred");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [
              Color.fromARGB(255, 0, 110, 179),
              Color.fromARGB(255, 66, 167, 255),
              Color.fromARGB(255, 0, 33, 61),
            ],
            stops: [0.21, 0.41, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    80,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    "LOGIN",
                    style: TextStyle(
                      fontSize: 45,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 4,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username label
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "USERNAME",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: loginIdController,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.person),
                            hintText: "EMAIL/USERNAME",
                            hintStyle: const TextStyle(color: Colors.black54),
                            filled: true,
                            fillColor: Colors.black.withAlpha(10),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Password label
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "PASSWORD",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: passwordController,
                          obscureText: !showPassword,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.key),
                            hintText: "PASSWORD",
                            hintStyle: const TextStyle(color: Colors.black54),
                            filled: true,
                            fillColor: Colors.black.withAlpha(10),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.black54,
                              ),
                              onPressed: () =>
                                  setState(() => showPassword = !showPassword),
                            ),
                          ),
                        ),

                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Colors.black,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Sign Up prompt
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(color: Colors.black54),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignUpPage(),
                                ),
                              ),
                              child: const Text(
                                "Sign Up",
                                style: TextStyle(
                                  color: Colors.black,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
