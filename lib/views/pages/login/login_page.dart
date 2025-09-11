import 'package:firebase_core/firebase_core.dart';
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

  Future<void> _login() async {
    if (loginIdController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email/username & password')),
      );
      return;
    }

    String loginInput = loginIdController.text.trim();
    String password = passwordController.text.trim();
    String emailToUse = loginInput;

    try {
      // Check if input is a username (not email)
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(loginInput)) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: loginInput)
            .get();

        if (querySnapshot.docs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No user found with this username')),
          );
          return;
        }

        emailToUse = querySnapshot.docs.first.get('email');
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful!')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // LOGIN title
              const Text(
                "LOGIN",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 50),

              // Username label
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "USERNAME",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: loginIdController,
                decoration: InputDecoration(
                  hintText: "EMAIL/USERNAME",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Password label
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "PASSWORD",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: passwordController,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  hintText: "PASSWORD",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => showPassword = !showPassword),
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
                      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                    );
                  },
                  child: const Text('Forgot Password?'),
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
                    backgroundColor: Colors.redAccent, 
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Sign Up prompt 
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don’t have an account? "),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    ),
                    child: const Text("Sign Up"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
